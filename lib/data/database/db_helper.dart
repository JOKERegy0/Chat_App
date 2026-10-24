import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  asyncDatabase() async {
    if (_database != null) return _database!;
    _database = await _initDB('kiura_secure.db');
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
    // جدول الرسائل المحلية المشفرة
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        recipient_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // جدول المستخدمين وجهات الاتصال
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        status_message TEXT
      )
    ''');
  }

  // حفظ رسالة محلياً
  Future<void> insertMessage(Map<String, dynamic> row) async {
    final db = await asyncDatabase();
    await db.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // استرجاع رسائل محادثة معينة
  Future<List<Map<String, dynamic>>> getMessages(String peerId) async {
    final db = await asyncDatabase();
    return await db.query(
      'messages',
      where: 'sender_id = ? OR recipient_id = ?',
      whereArgs: [peerId, peerId],
      orderBy: 'timestamp ASC',
    );
  }

  Future close() async {
    final db = await asyncDatabase();
    db.close();
  }
}