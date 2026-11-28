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
    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _upgradeDB);
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
        timestamp TEXT,
        is_read INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('CREATE TABLE peers (id TEXT PRIMARY KEY, name TEXT NOT NULL)');
  }

  // version 2: unread marker. Messages that already exist count as read.
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE messages ADD COLUMN is_read INTEGER NOT NULL DEFAULT 1');
    }
    // version 3: names of the people we talk to, so the chat list needs no internet
    if (oldVersion < 3) {
      await db.execute('CREATE TABLE IF NOT EXISTS peers (id TEXT PRIMARY KEY, name TEXT NOT NULL)');
    }
  }

  Future<int> insertMessage(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('messages', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List> getPendingMessages() async {
    final db = await instance.database;
    return await db.query('messages', where: 'status = ?', whereArgs: ['pending']);
  }

  Future<List> getMessagesForChat(String chatId, {String? userId}) async {
    final db = await instance.database;
    return await db.query(
      'messages',
      where: userId == null ? 'chat_id = ?' : 'chat_id = ? AND (sender_id = ? OR recipient_id = ?)',
      whereArgs: userId == null ? [chatId] : [chatId, userId, userId],
      orderBy: 'timestamp ASC',
    );
  }

  /// One row per conversation of this user: last message, its time, and the unread count.
  Future<List> getConversations(String userId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT m.chat_id AS chat_id, m.content AS content, m.timestamp AS timestamp,
             m.sender_id AS sender_id, m.status AS status,
             (SELECT COUNT(*) FROM messages u
                WHERE u.chat_id = m.chat_id AND u.recipient_id = ? AND u.is_read = 0) AS unread
      FROM messages m
      WHERE m.id = (
        SELECT x.id FROM messages x
        WHERE x.chat_id = m.chat_id AND (x.sender_id = ? OR x.recipient_id = ?)
        ORDER BY x.timestamp DESC, x.rowid DESC
        LIMIT 1
      )
      ORDER BY m.timestamp DESC
    ''', [userId, userId, userId]);
  }

  /// Names of the people we talk to, remembered on this phone.
  Future<Map<String, String>> getPeerNames() async {
    final db = await instance.database;
    final rows = await db.query('peers');
    return {for (final r in rows) r['id'] as String: r['name'] as String};
  }

  Future<void> savePeerName(String id, String name) async {
    final db = await instance.database;
    await db.insert(
      'peers',
      {'id': id, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The user opened the chat: everything received in it counts as read.
  Future<void> markChatRead(String chatId, String userId) async {
    final db = await instance.database;
    await db.update(
      'messages',
      {'is_read': 1},
      where: 'chat_id = ? AND recipient_id = ? AND is_read = 0',
      whereArgs: [chatId, userId],
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
