import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
    // جدول الرسائل
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT,
        sender_id TEXT,
        recipient_id TEXT,
        content TEXT,
        type TEXT,
        status TEXT,
        timestamp TEXT
      )
    ''');

    // جدول المحادثات
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        name TEXT,
        avatar TEXT,
        last_message TEXT,
        updated_at TEXT
      )
    ''');
  }

  // إدراج رسالة جديدة
  Future<int> insertMessage(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // جلب الرسائل الخاصة بمحادثة معينة
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
    );
  }

  // جلب الرسائل التي لم يتم إرسالها (Pending)
  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
  }

  // تحديث حالة الرسالة (sent, delivered, read)
  Future<int> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    return await db.update(
      'messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // إدراج أو تحديث محادثة في القائمة
  Future<int> insertOrUpdateChat(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(
      'chats',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // إغلاق قاعدة البيانات
  Future close() async {
    final db = await database;
    db.close();
  }
}
