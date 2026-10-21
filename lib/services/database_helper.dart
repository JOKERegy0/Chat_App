import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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

  // إنشاء الجداول الأساسية لتطبيق KIURA
  Future _createDB(Database db, int version) async {
    // جدول المحادثات
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar TEXT,
        last_message TEXT,
        updated_at TEXT
      )
    ''');

    // جدول الرسائل
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
    // ==================== دوال الرسائل (Messages) ====================

  // 1. حفظ رسالة جديدة
  Future<int> insertMessage(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('messages', row);
  }

  // 2. جلب كل الرسائل الخاصة بمحادثات معينة مرقبة بالوقت
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    Database db = await instance.database;
    return await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
  }

  // ==================== دوال المحادثات (Chats) ====================

  // 3. إضافة أو تحديث محادثة
  Future<int> insertOrUpdateChat(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(
      'chats',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 4. جلب قائمة كل المحادثات
  Future<List<Map<String, dynamic>>> getChats() async {
    Database db = await instance.database;
    return await db.query('chats', orderBy: 'updated_at DESC');
  }

}
