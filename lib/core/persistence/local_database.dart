import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      p.join(root, 'github_manager.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache_entries (
            cache_key TEXT PRIMARY KEY,
            json_value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE favorite_repositories (
            repository_id INTEGER PRIMARY KEY,
            full_name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE operation_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            message TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> putJson(String key, Object value) async {
    final db = await database;
    await db.insert(
      'cache_entries',
      {
        'cache_key': key,
        'json_value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> readJson(String key) async {
    final db = await database;
    final rows = await db.query(
      'cache_entries',
      columns: ['json_value'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return jsonDecode(rows.first['json_value']! as String);
  }

  Future<void> clearGitHubCache() async {
    final db = await database;
    await db.delete('cache_entries', where: 'cache_key LIKE ?', whereArgs: ['github.%']);
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
