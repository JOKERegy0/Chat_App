import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:socket_io_client/socket_io_client.io' as IO;

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
// 2. نظام الاتصال والسيرفر (Socket Service)
// ==========================================
class SocketService {
  static final SocketService instance = SocketService._internal();
  factory SocketService() => instance;
  SocketService._internal();

  late IO.Socket socket;
  bool isConnected = false;

  void initSocket({
    required String serverUrl,
    required String userId,
    required Function(bool) onConnectionChanged,
    required Function(Map<String, dynamic>) onMessageReceived,
  }) {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'query': {'user_id': userId},
    });

    socket.connect();

    socket.onConnect((_) {
      isConnected = true;
      onConnectionChanged(true);
      print('KIURA: Connected to Server');
    });

    socket.onDisconnect((_) {
      isConnected = false;
      onConnectionChanged(false);
      print('KIURA: Disconnected from Server');
    });

    socket.on('receive_message', (data) async {
      final messageData = {
        'id': data['id'],
        'chat_id': data['chat_id'],
        'sender_id': data['sender_id'],
        'content': data['content'],
        'type': data['type'] ?? 'text',
        'status': 'delivered',
        'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
      };

      await DatabaseHelper.instance.insertMessage(messageData);
      onMessageReceived(messageData);
    });
  }

  void sendMessage({
    required String chatId,
    required String recipientId,
    required String content,
    required String messageId,
    required String timestamp,
  }) {
    if (isConnected) {
      socket.emit('send_message', {
        'id': messageId,
        'chat_id': chatId,
        'recipient_id': recipientId,
        'content': content,
        'timestamp': timestamp,
      });
    }
  }

  void disconnect() {
    socket.disconnect();
  }
}

// ==========================================
// 3. واجهة التطبيق الرئيسية (UI)
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
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadLocalMessages();
    _setupSocket();
  }

  // تحميل الرسائل من قاعدة البيانات المحلية أولاً
  void _loadLocalMessages() async {
    final data = await DatabaseHelper.instance.getMessages('default_chat');
    setState(() {
      _messages = data;
    });
  }

  // إعداد السوكت والاستماع للتغيرات
  void _setupSocket() {
    SocketService.instance.initSocket(
      serverUrl: 'https://your-server-url.com', // ضع رابط السيرفر الخاص بك هنا لاحقاً
      userId: 'user_joker',
      onConnectionChanged: (status) {
        setState(() {
          _isConnected = status;
        });
      },
      onMessageReceived: (data) {
        _loadLocalMessages(); // تحديث الشاشة عند استقبال رسالة حية
      },
    );
  }

  // إرسال الرسالة وحفظها محلياً وعبر السوكت
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now().toIso8601String();
    final messageStatus = SocketService.instance.isConnected ? 'sent' : 'pending';

    final messageData = {
      'id': messageId,
      'chat_id': 'default_chat',
      'sender_id': 'me',
      'content': text,
      'type': 'text',
      'status': messageStatus,
      'timestamp': timestamp,
    };

    // 1. الحفظ محلياً فوراً (Local-First) لضمان عدم ضياعها
    await DatabaseHelper.instance.insertMessage(messageData);

    // 2. تحديث قائمة المحادثات الأخيرة
    await DatabaseHelper.instance.insertOrUpdateChat({
      'id': 'default_chat',
      'name': 'Kiura User',
      'avatar': '',
      'last_message': text,
      'updated_at': timestamp,
    });

    // 3. المحاولة عبر السوكت إذا كان متصلاً
    SocketService.instance.sendMessage(
      chatId: 'default_chat',
      recipientId: 'recipient_id',
      content: text,
      messageId: messageId,
      timestamp: timestamp,
    );

    // 4. تحديث الواجهة
    _loadLocalMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('KIURA Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            // مؤشر حالة الاتصال بالسيرفر
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg['status'] == 'pending' ? '⏳ معلقة' : '✓ مرسلة',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
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
