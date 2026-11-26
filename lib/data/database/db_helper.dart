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

  /// Saves a received message only if we do not have it yet. Returns true when it was new.
  Future<bool> insertIncomingIfNew(Map<String, dynamic> row) async {
    final db = await instance.database;
    final existing = await db.query(
      'messages',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [row['id']],
      limit: 1,
    );
    if (existing.isNotEmpty) return false;
    await db.insert('messages', row);
    return true;
  }

  Future<String?> getChatIdForMessage(String id) async {
    final db = await instance.database;
    final rows = await db.query(
      'messages',
      columns: ['chat_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['chat_id'] as String?;
  }

  /// Moves a message status forward only: pending -> queued -> sent (or failed).
  /// A late "queued" confirmation can never undo a "sent" one.
  Future<void> advanceMessageStatus(String id, String status) async {
    final db = await instance.database;
    final allowedFrom = {
      'queued': ['pending'],
      'sent': ['pending', 'queued'],
      'failed': ['pending', 'queued'],
    }[status];
    if (allowedFrom == null) return;
    final marks = List.filled(allowedFrom.length, '?').join(',');
    await db.update(
      'messages',
      {'status': status},
      where: 'id = ? AND status IN ($marks)',
      whereArgs: [id, ...allowedFrom],
    );
  }
}
