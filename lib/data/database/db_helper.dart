import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kiura_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
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
  }

  Future<int> insertMessage(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List> getPendingMessages() async {
    final db = await instance.database;
    return await db.query('messages', where: 'status = ?', whereArgs: ['pending']);
  }

  Future<List> getMessagesForChat(String chatId) async {
    final db = await instance.database;
    return await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<int> updateMessageStatus(String id, String status) async {
    final db = await instance.database;
    return await db.update(
      'messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
