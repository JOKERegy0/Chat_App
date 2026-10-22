import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KiuraApp());
}

// ==========================================
// 1. نظام قاعدة البيانات المحلية المتقدم (Database Helper)
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kiura_chat.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS messages');
          await db.execute('DROP TABLE IF EXISTS chats');
          _createDB(db, newVersion);
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar TEXT,
        last_message TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        recipient_id TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertMessage(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateMessageStatus(String messageId, String newStatus) async {
    Database db = await instance.database;
    await db.update(
      'messages',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    Database db = await instance.database;
    return await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    Database db = await instance.database;
    return await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<int> insertOrUpdateChat(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(
      'chats',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

// ==========================================
// 2. واجهة التطبيق الرئيسية (UI)
// ==========================================
class KiuraApp extends StatelessWidget {
  const KiuraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KIURA',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const ChatScreen(
        currentUserId: 'user_joker',
        recipientId: 'user_friend',
        chatId: 'chat_joker_friend',
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String recipientId;
  final String chatId;

  const ChatScreen({
    Key? key,
    required this.currentUserId,
    required this.recipientId,
    required this.chatId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  WebSocket? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _loadLocalMessages();
    _connectWebSocket();
  }

  void _loadLocalMessages() async {
    final data = await DatabaseHelper.instance.getMessages(widget.chatId);
    setState(() {
      _messages = data;
    });
  }

  void _connectWebSocket() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      await _channel?.close();
    } catch (_) {}

    try {
      _channel = await WebSocket.connect(
          'wss://chat-app-4hax.onrender.com?user_id=${widget.currentUserId}');

      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });

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

            // التأكد من أن الرسالة الواردة تخص الطرف الآخر وليست انعكاساً لرسالتك أنت
            final incomingSenderId = data['sender_id'] ?? widget.recipientId;

            final messageData = {
              'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'chat_id': widget.chatId,
              'sender_id': incomingSenderId,
              'recipient_id': widget.currentUserId,
              'content': data['content'],
              'type': 'text',
              'status': 'read',
              'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
            };

            await DatabaseHelper.instance.insertMessage(messageData);
            _loadLocalMessages();

            // الرد بإقرار وصول وقراءة للسيرفر
            _channel?.add(jsonEncode({
              'type': 'ack',
              'message_id': data['id'],
              'sender_id': incomingSenderId
            }));
          } catch (e) {
            print('Incoming message error: $e');
          }
        },
        onDone: () {
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });
          _startReconnectTimer();
        },
        onError: (error) {
          setState(() {
            _isConnected = false;
            _isConnecting = false;
          });
          _startReconnectTimer();
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
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
      'sender_id': widget.currentUserId, // رسالة منك أنت
      'recipient_id': widget.recipientId,
      'content': text,
      'type': 'text',
      'status': messageStatus,
      'timestamp': timestamp,
    };

    await DatabaseHelper.instance.insertMessage(messageData);

    await DatabaseHelper.instance.insertOrUpdateChat({
      'id': widget.chatId,
      'name': 'Kiura Friend',
      'avatar': '',
      'last_message': text,
      'updated_at': timestamp,
    });

    if (_isConnected && _channel != null) {
      final payload = jsonEncode({
        'id': messageId,
        'chat_id': widget.chatId,
        'sender_id': widget.currentUserId,
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

  Widget _buildMessageStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.access_time, size: 12, color: Colors.grey);
      case 'sent':
        return const Icon(Icons.check, size: 12, color: Colors.grey);
      case 'delivered':
        return const Icon(Icons.done_all, size: 12, color: Colors.grey);
      case 'read':
        return const Icon(Icons.done_all, size: 12, color: Colors.blue); // ✓✓ أزرق عند القراءة
      default:
        return const Icon(Icons.check, size: 12, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('KIURA Chat',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                // التحقق الدقيق هل الرسالة مرسلة منك أم من الطرف الآخر لتتوزع يمين ويسار
                final isMe = msg['sender_id'] == widget.currentUserId;

                // تنسيق الوقت 12 ساعة مع (ص / م) بدقة
                String formattedTime = '';
                try {
                  final dt = DateTime.parse(msg['timestamp']);
                  int hour = dt.hour;
                  String period = hour >= 12 ? 'م' : 'ص';

                  if (hour == 0) {
                    hour = 12;
                  } else if (hour > 12) {
                    hour -= 12;
                  }

                  formattedTime = "$hour:${dt.minute.toString().padLeft(2, '0')} $period";
                } catch (_) {}

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.indigo[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(msg['content'] ?? '',
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.right),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.black54),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _buildMessageStatusIcon(msg['status']),
                            ], فقرات
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك في KIURA...',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.indigo),
                    onPressed: _sendMessage,
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
