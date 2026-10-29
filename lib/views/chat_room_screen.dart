import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/db_helper.dart'; // استدعاء قاعدة البيانات المحلية المنفصلة[span_3](start_span)[span_3](end_span)

class ChatRoomScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String chatId;

  const ChatRoomScreen({
    Key? key,
    required this.recipientId,
    required this.recipientName,
    required this.chatId,
  }) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  WebSocket? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  String get _currentUserId => Supabase.instance.client.auth.currentUser?.id ?? 'user_joker';

  @override
  void initState() {
    super.initState();
    _loadLocalMessages();
    _connectWebSocket();
  }

  // جلب الرسائل المخزنة محلياً عبر DatabaseHelper المنفصل
  void _loadLocalMessages() async {
    final data = await DatabaseHelper.instance.getMessages(widget.chatId);
    if (mounted) {
      setState(() {
        _messages = data;
      });
    }
  }

  // اتصال الـ WebSocket الحي
  void _connectWebSocket() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      await _channel?.close();
    } catch (_) {}

    try {
      _channel = await WebSocket.connect(
          'wss://chat-app-4hax.onrender.com?user_id=$_currentUserId');

      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
      }

      _reconnectTimer?.cancel();
      _syncPendingMessagesToServer();

      _channel!.listen(
        (message) async {
          try {
            final data = jsonDecode(message);

            if (data['type'] == 'ack') {
              await DatabaseHelper.instance
                  .updateMessageStatus(data['message_id'], 'read');
              _loadLocalMessages();
              return;
            }

            final incomingSenderId = data['sender_id'] ?? widget.recipientId;

            final messageData = {
              'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'chat_id': widget.chatId,
              'sender_id': incomingSenderId,
              'recipient_id': _currentUserId,
              'content': data['content'],
              'type': 'text',
              'status': 'read',
              'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
            };

            await DatabaseHelper.instance.insertMessage(messageData);
            _loadLocalMessages();

            _channel?.add(jsonEncode({
              'type': 'ack',
              'message_id': data['id'],
              'sender_id': incomingSenderId
            }));
          } catch (e) {
            print('خطأ في استقبال الرسالة: $e');
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _isConnecting = false;
            });
          }
          _startReconnectTimer();
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _isConnecting = false;
            });
          }
          _startReconnectTimer();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
        });
      }
      _startReconnectTimer();
    }
  }

  void _syncPendingMessagesToServer() async {
    if (!_isConnected || _channel == null) return;

    final pendingMessages = await DatabaseHelper.instance.getPendingMessages();
    for (var msg in pendingMessages) {
      final payload = jsonEncode({
        'id': msg['id'],
        'chat_id': msg['chat_id'],
        'sender_id': msg['sender_id'],
        'recipient_id': msg['recipient_id'],
        'content': msg['content'],
        'timestamp': msg['timestamp'],
      });

      _channel!.add(payload);
      await DatabaseHelper.instance.updateMessageStatus(msg['id'], 'sent');
    }
    _loadLocalMessages();
  }

  void _startReconnectTimer() {
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected && !_isConnecting) {
        _connectWebSocket();
      } else if (_isConnected) {
        timer.cancel();
      }
    });
  }

  // إرسال الرسالة وحفظها محلياً وعبر الـ WebSocket
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now().toIso8601String();
    final messageStatus = _isConnected ? 'sent' : 'pending';

    final messageData = {
      'id': messageId,
      'chat_id': widget.chatId,
      'sender_id': _currentUserId,
      'recipient_id': widget.recipientId,
      'content': text,
      'type': 'text',
      'status': messageStatus,
      'timestamp': timestamp,
    };

    await DatabaseHelper.instance.insertMessage(messageData);

    await DatabaseHelper.instance.insertOrUpdateChat({
      'id': widget.chatId,
      'name': widget.recipientName,
      'avatar': '',
      'last_message': text,
      'updated_at': timestamp,
    });

    if (_isConnected && _channel != null) {
      final payload = jsonEncode({
        'id': messageId,
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'recipient_id': widget.recipientId,
        'content': text,
        'timestamp': timestamp,
      });
      _channel!.add(payload);
    }

    _loadLocalMessages();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.recipientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 10),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: Column(
        children: [
          // قائمة الرسائل
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == _currentUserId;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF0284C7) : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // شريط إدخال الرسائل (واضح وخالٍ من مشاكل البهتان)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك في KIURA...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
