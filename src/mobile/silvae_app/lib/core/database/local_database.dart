import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final class LocalDatabase {
  const LocalDatabase(this.database);

  final Database database;

  static Future<LocalDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'silvae.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
    );
    return LocalDatabase(database);
  }

  static Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE worksites (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        version INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE daily_reports (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        worksite_id TEXT NOT NULL,
        report_date TEXT NOT NULL,
        notes TEXT,
        status TEXT NOT NULL,
        version INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE outbox (
        operation_id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        expected_version INTEGER NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        status TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX ix_outbox_status_created '
      'ON outbox(status, created_at)',
    );
  }

  Future<void> replaceWorksites(List<Map<String, Object?>> worksites) async {
    await database.transaction((transaction) async {
      for (final worksite in worksites) {
        await transaction.insert(
          'worksites',
          worksite,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> getWorksites() =>
      database.query('worksites', orderBy: 'code');

  Future<List<Map<String, Object?>>> getDailyReports() => database.query(
    'daily_reports',
    orderBy: 'report_date DESC, updated_at DESC',
  );

  Future<void> createOfflineReport({
    required Map<String, Object?> report,
    required Map<String, Object?> operation,
  }) async {
    await database.transaction((transaction) async {
      await transaction.insert(
        'daily_reports',
        report,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await transaction.insert(
        'outbox',
        operation,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<List<Map<String, Object?>>> getPendingOperations() => database.query(
    'outbox',
    where: 'status IN (?, ?)',
    whereArgs: ['pending', 'failed'],
    orderBy: 'created_at',
    limit: 100,
  );

  Future<void> markProcessing(String operationId) => database.update(
    'outbox',
    {'status': 'processing', 'last_error': null},
    where: 'operation_id = ?',
    whereArgs: [operationId],
  );

  Future<void> markSynced({
    required String operationId,
    required String entityId,
    required int version,
  }) async {
    await database.transaction((transaction) async {
      await transaction.update(
        'outbox',
        {'status': 'synced', 'last_error': null},
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
      await transaction.update(
        'daily_reports',
        {'sync_status': 'synced', 'version': version},
        where: 'id = ?',
        whereArgs: [entityId],
      );
    });
  }

  Future<void> markFailed(String operationId, String error) async {
    await database.rawUpdate(
      '''
        UPDATE outbox
        SET status = ?, attempts = attempts + 1, last_error = ?
        WHERE operation_id = ?
      ''',
      ['failed', error, operationId],
    );
    final rows = await database.query(
      'outbox',
      columns: ['entity_id'],
      where: 'operation_id = ?',
      whereArgs: [operationId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await database.update(
        'daily_reports',
        {'sync_status': 'error'},
        where: 'id = ?',
        whereArgs: [rows.single['entity_id']],
      );
    }
  }

  Future<void> upsertRemoteReports(
    List<Map<String, Object?>> reports,
    DateTime serverTime,
  ) async {
    await database.transaction((transaction) async {
      for (final report in reports) {
        final pending = await transaction.rawQuery(
          '''
            SELECT 1
            FROM outbox
            WHERE entity_id = ? AND status != ?
            LIMIT 1
          ''',
          [report['id'], 'synced'],
        );
        if (pending.isEmpty) {
          await transaction.insert(
            'daily_reports',
            report,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await transaction.insert('sync_state', {
        'key': 'last_pull',
        'value': serverTime.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<DateTime?> getLastPull() async {
    final rows = await database.query(
      'sync_state',
      where: 'key = ?',
      whereArgs: ['last_pull'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rows.single['value']! as String);
  }

  static Map<String, dynamic> decodePayload(Object? value) =>
      jsonDecode(value! as String) as Map<String, dynamic>;
}
