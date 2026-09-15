import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static const int schemaVersion = 2;
  static const String databaseFileName = 'github_manager.db';

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<String> _databasePath() async {
    final root = await getDatabasesPath();
    return p.join(root, databaseFileName);
  }

  Future<Database> _open() async {
    final path = await _databasePath();
    return openDatabase(
      path,
      version: schemaVersion,
      // Há vários serviços curtos que criam e fecham sua própria instância.
      // Com o padrão singleInstance=true, fechar uma dessas instâncias pode
      // encerrar a conexão reutilizada pela tela principal.
      singleInstance: false,
      onCreate: (db, version) => _ensureSchema(db),
      onUpgrade: (db, oldVersion, newVersion) => _ensureSchema(db),
      onOpen: _ensureSchema,
    );
  }

  /// Mantém o esquema local idempotente. Isso protege atualizações vindas de
  /// versões antigas que possuíam o mesmo número de banco, mas ainda não tinham
  /// todas as tabelas adicionadas depois.
  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_entries (
        cache_key TEXT PRIMARY KEY,
        json_value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_repositories (
        repository_id INTEGER PRIMARY KEY,
        full_name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operation_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_operation_logs_created_at '
      'ON operation_logs(created_at)',
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

    final raw = rows.first['json_value']! as String;
    try {
      return jsonDecode(raw);
    } on FormatException {
      // Um valor local quebrado nunca deve inutilizar o aplicativo inteiro.
      await db.delete(
        'cache_entries',
        where: 'cache_key = ?',
        whereArgs: [key],
      );
      return null;
    }
  }

  Future<void> clearLegacyRemoteGitHubData() async {
    final db = await database;
    await db.delete(
      'cache_entries',
      where: 'cache_key IN (?, ?, ?)',
      whereArgs: const [
        'github.repositories',
        'github.profile',
        'followed.repositories.cache',
      ],
    );
  }

  Future<void> clearGitHubCache() async {
    final db = await database;
    await db.delete(
      'cache_entries',
      where: 'cache_key LIKE ?',
      whereArgs: ['github.%'],
    );
  }

  Future<Set<int>> readFavoriteRepositoryIds() async {
    final db = await database;
    final rows = await db.query(
      'favorite_repositories',
      columns: ['repository_id'],
      orderBy: 'created_at ASC',
    );
    return rows
        .map((row) => row['repository_id'])
        .whereType<int>()
        .toSet();
  }

  Future<void> setFavoriteRepository({
    required int repositoryId,
    required String fullName,
    required bool favorite,
  }) async {
    final db = await database;
    if (!favorite) {
      await db.delete(
        'favorite_repositories',
        where: 'repository_id = ?',
        whereArgs: [repositoryId],
      );
      return;
    }
    await db.insert(
      'favorite_repositories',
      {
        'repository_id': repositoryId,
        'full_name': fullName,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFavoriteRepositoryName(
    int repositoryId,
    String fullName,
  ) async {
    final db = await database;
    await db.update(
      'favorite_repositories',
      {'full_name': fullName},
      where: 'repository_id = ?',
      whereArgs: [repositoryId],
    );
  }

  Future<void> removeFavoriteRepositoryByFullName(String fullName) async {
    final db = await database;
    await db.delete(
      'favorite_repositories',
      where: 'LOWER(full_name) = ?',
      whereArgs: [fullName.toLowerCase()],
    );
  }

  Future<void> reconcileFavoriteRepositories(Set<int> existingIds) async {
    final db = await database;
    final rows = await db.query(
      'favorite_repositories',
      columns: ['repository_id'],
    );
    final staleIds = rows
        .map((row) => row['repository_id'])
        .whereType<int>()
        .where((id) => !existingIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      await db.delete(
        'favorite_repositories',
        where: 'repository_id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Verifica o banco e recria qualquer tabela/índice ausente sem apagar
  /// token, preferências seguras ou dados que ainda estejam íntegros.
  Future<bool> repairSchema() async {
    final db = await database;
    await _ensureSchema(db);
    final rows = await db.rawQuery('PRAGMA quick_check');
    if (rows.isEmpty) return false;
    final value = rows.first.values.isEmpty
        ? null
        : rows.first.values.first?.toString().toLowerCase();
    return value == 'ok';
  }

  /// Último recurso para corrupção física do SQLite. Reconstrói somente o
  /// banco local do aplicativo. O token GitHub fica no armazenamento seguro e
  /// não é apagado.
  Future<void> rebuildLocalDatabase() async {
    await close();
    final path = await _databasePath();
    await deleteDatabase(path);
    _database = await _open();
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
