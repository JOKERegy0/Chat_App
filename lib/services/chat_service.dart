import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/database/db_helper.dart';
import 'api_config.dart';

/// One connection for the whole app (not one per chat screen).
/// - connects after login and reconnects by itself
/// - saves every incoming message in the local database
/// - keeps outgoing messages "pending" until the server confirms delivery
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  final StreamController<String> _changesController = StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _flushTimer;

  bool _started = false;
  bool _connected = false;
  bool _connecting = false;
  bool _flushing = false;
  bool _forceRefresh = false;
  int _attempt = 0;

  final Map<String, String> _nameCache = {};
  final Random _random = Random();

  /// Chat id of the room that is open right now (to avoid notifying about it).
  String? activeChatId;

  /// Emits a chat id when its messages changed ('*' = any chat).
  Stream<String> get changes => _changesController.stream;

  /// Emits every new message received from another user (already saved).
  Stream<Map<String, dynamic>> get incomingMessages => _incomingController.stream;

  /// Emits true/false when the connection state changes.
  Stream<bool> get connectionState => _connectionController.stream;

  bool get isConnected => _connected;

  SupabaseClient get _supabase => Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  // ---------- lifecycle ----------

  void start() {
    if (_started) return;
    _started = true;
    _flushTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_connected) _flushPending();
    });
    _connect();
  }

  void stop() {
    _started = false;
    _reconnectTimer?.cancel();
    _flushTimer?.cancel();
    _closeChannel();
    _setConnected(false);
    _nameCache.clear();
    activeChatId = null;
  }

  void _setConnected(bool value) {
    _connected = value;
    _connectionController.add(value);
  }

  void _closeChannel() {
    _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    try {
      channel?.sink.close();
    } catch (_) {}
  }

  // ---------- connection ----------

  Future<void> _connect() async {
    if (!_started || _connecting || _connected) return;
    _connecting = true;
    try {
      final current = _supabase.auth.currentSession;
      if (current == null) return;

      var token = current.accessToken;
      if (_forceRefresh || current.isExpired) {
        _forceRefresh = false;
        try {
          final refreshed = await _supabase.auth.refreshSession();
          token = refreshed.session?.accessToken ?? token;
        } catch (_) {}
      }

      // queryParameters encodes the "+" in the version, so the server reads it correctly
      final uri = Uri.parse(AppConfig.webService).replace(
        scheme: 'wss',
        queryParameters: {
          'version': AppConfig.appVersion,
          'token': token,
        },
      );

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready;

      if (!_started || _channel != channel) {
        try {
          channel.sink.close();
        } catch (_) {}
        return;
      }

      _attempt = 0;
      _setConnected(true);
      _subscription = channel.stream.listen(
        _onData,
        onError: (_) => _onClosed(channel),
        onDone: () => _onClosed(channel),
        cancelOnError: true,
      );
      _flushPending();
    } catch (_) {
      _closeChannel();
      _setConnected(false);
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _onClosed(WebSocketChannel channel) {
    if (channel != _channel) return;
    final code = channel.closeCode;
    // 4001 / 4003: the server did not accept the token, so get a fresh one next time
    if (code == 4001 || code == 4003) _forceRefresh = true;
    _closeChannel();
    _setConnected(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_started) return;
    _reconnectTimer?.cancel();
    final seconds = min(30, 2 << min(_attempt, 4)); // 2, 4, 8, 16, 30
    _attempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _connect);
  }

  // ---------- receiving ----------

  Future<void> _onData(dynamic raw) async {
    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic>) return;
      msg = decoded;
    } catch (_) {
      return;
    }

    if (msg['type'] == 'ack') {
      await _handleAck(msg);
    } else if (msg['content'] is String && msg['sender_id'] is String) {
      await _handleIncoming(msg);
    }
  }

  Future<void> _handleAck(Map<String, dynamic> msg) async {
    final id = msg['message_id']?.toString();
    if (id == null) return;

    // "sent" = the other user's phone received it.
    // "pending" = the other user is offline: the message stays pending and is retried.
    if (msg['status'] == 'sent') {
      await DatabaseHelper.instance.updateMessageStatus(id, 'sent');
      final chatId = await DatabaseHelper.instance.getChatIdForMessage(id);
      _changesController.add(chatId ?? '*');
    }
  }

  Future<void> _handleIncoming(Map<String, dynamic> msg) async {
    final id = msg['id']?.toString();
    final senderId = msg['sender_id'] as String;
    if (id == null || id.isEmpty) return;

    final Map<String, dynamic> row = {
      'id': id,
      // the thread id is always built from the other user's id
      'chat_id': 'chat_$senderId',
      'sender_id': senderId,
      'recipient_id': currentUserId,
      'content': msg['content'],
      'type': 'text',
      'status': 'received',
      'timestamp': msg['timestamp']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
    };

    final isNew = await DatabaseHelper.instance.insertIncomingIfNew(row);
    if (!isNew) return; // a resend of a message we already have

    _changesController.add(row['chat_id'] as String);
    _incomingController.add(row);
  }

  // ---------- sending ----------

  String _newMessageId(String userId) {
    final short = userId.length >= 8 ? userId.substring(0, 8) : userId;
    return '$short-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0xFFFF).toRadixString(16)}';
  }

  Future<void> sendMessage({
    required String chatId,
    required String recipientId,
    required String content,
  }) async {
    final myId = currentUserId;
    if (myId.isEmpty) return;

    final Map<String, dynamic> row = {
      'id': _newMessageId(myId),
      'chat_id': chatId,
      'sender_id': myId,
      'recipient_id': recipientId,
      'content': content,
      'type': 'text',
      'status': 'pending',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    await DatabaseHelper.instance.insertMessage(row);
    _changesController.add(chatId);
    _sendRow(row);
  }

  bool _sendRow(Map<dynamic, dynamic> row) {
    final channel = _channel;
    if (!_connected || channel == null) return false;
    try {
      channel.sink.add(jsonEncode({
        'id': row['id'],
        'recipient_id': row['recipient_id'],
        'content': row['content'],
      }));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends the messages that are still waiting (the server limits 30 messages / 10 s).
  Future<void> _flushPending() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final pending = await DatabaseHelper.instance.getPendingMessages();
      var count = 0;
      for (final msg in pending) {
        if (!_connected || count >= 20) break;
        if (msg['sender_id'] != currentUserId) continue;
        _sendRow(msg);
        count++;
      }
    } catch (_) {
    } finally {
      _flushing = false;
    }
  }

  // ---------- helpers ----------

  Future<String> lookupUsername(String userId) async {
    final cached = _nameCache[userId];
    if (cached != null) return cached;
    try {
      final row = await _supabase.from('profiles').select('username').eq('id', userId).maybeSingle();
      final name = (row?['username'] as String?) ?? 'مستخدم KIURA';
      _nameCache[userId] = name;
      return name;
    } catch (_) {
      return 'مستخدم KIURA';
    }
  }
}
