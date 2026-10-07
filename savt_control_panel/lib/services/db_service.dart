import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DbService {
  static final DbService instance = DbService._init();
  static Database? _database;

  DbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('savt_chat.db');
    return _database!;
  }

  Future<void> clearCabinetCache() async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      await db.delete('cabinets');
    } catch (_) {}
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactoryFfiWeb.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        ),
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT NOT NULL,
        chat_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_messages_chat_id ON messages(chat_id)');

    await db.execute('''
      CREATE TABLE cabinets(
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents(
        id INTEGER PRIMARY KEY,
        cabinet_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_documents_cabinet_id ON documents(cabinet_id)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cabinets(
          id INTEGER PRIMARY KEY,
          data TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS documents(
          id INTEGER PRIMARY KEY,
          cabinet_id INTEGER NOT NULL,
          data TEXT NOT NULL,
          cached_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_cabinet_id ON documents(cabinet_id)');
    }
  }

  Future<void> cacheMessages(int chatId, List<Map<String, dynamic>> messagesRaw) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      final batch = db.batch();
      
      // Удаляем старые, чтобы избежать дубликатов (простой вариант кэша)
      batch.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
      
      for (var msg in messagesRaw) {
        batch.insert('messages', {
          'message_id': msg['id'].toString(),
          'chat_id': chatId,
          'data': jsonEncode(msg),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> getCachedMessages(int chatId) async {
    if (kIsWeb) return null;
    try {
      final db = await instance.database;
      final maps = await db.query(
        'messages',
        where: 'chat_id = ?',
        whereArgs: [chatId],
      );
      if (maps.isEmpty) return null;
      
      return maps.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateMessageTranscription(int chatId, String messageId, String transcription) async {
    final db = await instance.database;
    final results = await db.query(
      'messages',
      where: 'chat_id = ? AND message_id = ?',
      whereArgs: [chatId, messageId],
    );
    if (results.isNotEmpty) {
      final row = results.first;
      final dataMap = Map<String, dynamic>.from(jsonDecode(row['data'] as String));
      dataMap['transcription'] = transcription;
      await db.update(
        'messages',
        {'data': jsonEncode(dataMap)},
        where: 'chat_id = ? AND message_id = ?',
      );
    }
  }

  Future<void> updateMessageReactions(int chatId, String messageId, Map<String, int> reactions) async {
    final db = await instance.database;
    final results = await db.query(
      'messages',
      where: 'chat_id = ? AND message_id = ?',
      whereArgs: [chatId, messageId],
    );
    if (results.isNotEmpty) {
      final row = results.first;
      final dataMap = Map<String, dynamic>.from(jsonDecode(row['data'] as String));
      dataMap['reactions'] = reactions;
      await db.update(
        'messages',
        {'data': jsonEncode(dataMap)},
        where: 'chat_id = ? AND message_id = ?',
        whereArgs: [chatId, messageId],
      );
    }
  }

  Future<void> deleteCachedMessage(int chatId, String messageId) async {
    try {
      final db = await instance.database;
      await db.delete(
        'messages',
        where: 'chat_id = ? AND message_id = ?',
        whereArgs: [chatId, messageId],
      );
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteCachedMessages(int chatId, List<String> messageIds) async {
    try {
      final db = await instance.database;
      final batch = db.batch();
      for (final id in messageIds) {
        batch.delete(
          'messages',
          where: 'chat_id = ? AND message_id = ?',
          whereArgs: [chatId, id],
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      // ignore
    }
  }

  Future<void> cacheCabinets(List<Map<String, dynamic>> cabinets) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      final batch = db.batch();
      
      batch.delete('cabinets');
      
      for (var cab in cabinets) {
        batch.insert('cabinets', {
          'id': cab['id'],
          'data': jsonEncode(cab),
        });
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> getCachedCabinets() async {
    if (kIsWeb) return null;
    try {
      final db = await instance.database;
      final maps = await db.query('cabinets');
      if (maps.isEmpty) return null;

      return maps.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }

  /// Кэшировать список документов для кабинета
  Future<void> cacheDocuments(int cabinetId, List<Map<String, dynamic>> docs) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      final batch = db.batch();

      batch.delete('documents', where: 'cabinet_id = ?', whereArgs: [cabinetId]);

      for (var doc in docs) {
        final docId = doc['id']?.toString() ?? doc['document_id']?.toString() ?? '';
        if (docId.isNotEmpty) {
          final parsedId = int.tryParse(docId) ?? 0;
          batch.insert('documents', {
            'id': parsedId,
            'cabinet_id': cabinetId,
            'data': jsonEncode(doc),
            'cached_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  /// Получить кэшированные документы для кабинета
  Future<List<Map<String, dynamic>>?> getCachedDocuments(int cabinetId) async {
    if (kIsWeb) return null;
    try {
      final db = await instance.database;
      final maps = await db.query(
        'documents',
        where: 'cabinet_id = ?',
        whereArgs: [cabinetId],
      );
      if (maps.isEmpty) return null;

      return maps.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
    } catch (_) {
      return null;
    }
  }

  /// Очистить кэш документов для кабинета
  Future<void> clearDocumentCache(int cabinetId) async {
    if (kIsWeb) return;
    try {
      final db = await instance.database;
      await db.delete('documents', where: 'cabinet_id = ?', whereArgs: [cabinetId]);
    } catch (_) {}
  }
}
