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
// 1. نظام قاعدة البيانات المحلية (Database Helper)
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
      version: 1,
      onCreate: _createDB,
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
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (chat_id) REFERENCES chats (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> insertMessage(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    Database db = await instance.database;
    return await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
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
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  WebSocket? _channel;
  bool _isConnected = false;
  bool _isConnecting = false; // 🛡️ حماية لمنع تكرار فتح قنوات اتصال متعددة
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _loadLocalMessages();
    _connectWebSocket();
  }

  void _loadLocalMessages() async {
    final data = await DatabaseHelper.instance.getMessages('default_chat');
    setState(() {
      _messages = data;
    });
  }

  // الاتصال بالسيرفر مع حماية صارمة لمنع تكرار القنوات
  void _connectWebSocket() async {
    // لو التطبيق متصل بالفعل، أو في عملية اتصال حالية جارٍ تنفيذها، امنع الطلب فوراً
    if (_isConnected || _isConnecting) return;

    _isConnecting = true; // تعيين حالة أنه جاري الاتصال الآن

    // تنظيف وإغلاق أي قناة قديمة سابقة للتأكد تماماً من عدم وجود قنوات معلقة
    try {
      await _channel?.close();
    } catch (_) {}

    try {
      print('KIURA: Trying to connect to server...');
      _channel = await WebSocket.connect('wss://chat-app-4hax.onrender.com');
      
      setState(() {
        _isConnected = true;
        _isConnecting = false; // تم الاتصال بنجاح، فك حالة الانتظار
      });
      
      print('KIURA: Connected successfully (Single active channel).');
      _reconnectTimer?.cancel(); // إيقاف مؤقت المحاولات

      _channel!.listen(
        (message) async {
          try {
            final data = jsonDecode(message);
            final messageData = {
              'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'chat_id': data['chat_id'] ?? 'default_chat',
              'sender_id': data['sender_id'] ?? 'other',
              'content': data['content'] ?? message,
              'type': 'text',
              'status': 'delivered',
              'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
            };

            await DatabaseHelper.instance.insertMessage(messageData);
            _loadLocalMessages();
          } catch (e) {
            print('Received non-JSON message: $message');
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
        _isConnecting = false; // فشل الاتصال، فك حالة الانتظار للسماح بالمحاولة القادمة
      });
      print('WebSocket Connection Error: $e. Retrying in background...');
      _startReconnectTimer();
    }
  }

  void _startReconnectTimer() {
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected && !_isConnecting) {
        print('KIURA: Background reconnect attempt (Safe & Controlled)...');
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
      'chat_id': 'default_chat',
      'sender_id': 'me',
      'content': text,
      'type': 'text',
      'status': messageStatus,
      'timestamp': timestamp,
    };

    await DatabaseHelper.instance.insertMessage(messageData);

    await DatabaseHelper.instance.insertOrUpdateChat({
      'id': 'default_chat',
      'name': 'Kiura User',
      'avatar': '',
      'last_message': text,
      'updated_at': timestamp,
    });

    if (_isConnected && _channel != null) {
      final payload = jsonEncode({
        'id': messageId,
        'chat_id': 'default_chat',
        'sender_id': 'me',
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
            const Text('KIURA Chat', style: TextStyle(fontWeight: FontWeight.bold)),
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
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.indigo[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['content'] ?? '', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          msg['status'] == 'pending' ? '⏳ معلقة' : '✓ مرسلة',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك في KIURA...',
                      border: OutlineInputBorder(),
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
        ],
      ),
    );
  }
}
