import 'dart:convert';
import 'dart:typed_data';

import 'package:silvae_app/core/database/database_opener.dart';
import 'package:sqflite/sqflite.dart';

final class LocalDatabase {
  const LocalDatabase(this.database);

  final Database database;

  static Future<LocalDatabase> open() async {
    final database = await localDatabaseFactory().openDatabase(
      await localDatabasePath(),
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    return LocalDatabase(database);
  }

  static Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE worksites ADD COLUMN job_order_id TEXT',
      );
      await database.execute(
        'ALTER TABLE worksites ADD COLUMN job_order_code TEXT',
      );
      await database.execute(
        'ALTER TABLE worksites ADD COLUMN job_order_name TEXT',
      );
    }
    if (oldVersion < 3) {
      await database.execute(
        'ALTER TABLE daily_reports ADD COLUMN content TEXT',
      );
      await database.execute(
        'ALTER TABLE daily_reports ADD COLUMN signature TEXT',
      );
      await database.execute(
        'ALTER TABLE daily_reports ADD COLUMN author_id TEXT',
      );
      await database.execute(
        'ALTER TABLE daily_reports ADD COLUMN remote_snapshot TEXT',
      );
      await database.execute(
        'ALTER TABLE outbox ADD COLUMN server_version INTEGER',
      );
      await database.execute(_photoTable);
    }
  }

  static const String _photoTable = '''
    CREATE TABLE report_photos (
      local_reference TEXT PRIMARY KEY,
      report_id TEXT NOT NULL,
      bytes BLOB NOT NULL
    )
  ''';

  /// Lo schema completo. Pubblico perché i test aprano lo stesso database
  /// dell'app invece di una copia scritta a mano, che si scollega al primo
  /// campo aggiunto.
  static Future<void> createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE worksites (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        job_order_id TEXT,
        job_order_code TEXT,
        job_order_name TEXT,
        version INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE daily_reports (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        worksite_id TEXT NOT NULL,
        author_id TEXT,
        report_date TEXT NOT NULL,
        notes TEXT,
        content TEXT,
        signature TEXT,
        status TEXT NOT NULL,
        version INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        remote_snapshot TEXT,
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
        server_version INTEGER,
        status TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await database.execute(_photoTable);
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

  Future<Map<String, Object?>?> getDailyReport(String reportId) async {
    final rows = await database.query(
      'daily_reports',
      where: 'id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

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

  Future<void> updateOfflineReport({
    required String reportId,
    required Map<String, Object?> report,
    required Map<String, Object?> operation,
  }) async {
    await database.transaction((transaction) async {
      await transaction.update(
        'daily_reports',
        report,
        where: 'id = ?',
        whereArgs: [reportId],
      );

      // Solo un upsert già in coda assorbe la modifica: accodarne un secondo
      // con la stessa versione attesa produrrebbe un conflitto garantito.
      // Un invio in coda invece va lasciato dov'è, perché viene dopo.
      final queued = await transaction.query(
        'outbox',
        columns: ['operation_id'],
        where: 'entity_id = ? AND operation_type = ? AND status IN (?, ?, ?)',
        whereArgs: [reportId, 'upsert', 'pending', 'failed', 'processing'],
        orderBy: 'created_at',
        limit: 1,
      );
      if (queued.isEmpty) {
        await transaction.insert(
          'outbox',
          operation,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        return;
      }
      await transaction.update(
        'outbox',
        {
          'payload': operation['payload'],
          'status': 'pending',
          'last_error': null,
        },
        where: 'operation_id = ?',
        whereArgs: [queued.single['operation_id']],
      );
    });
  }

  /// Accoda l'invio senza toccare quel che è già in coda: l'invio viene dopo
  /// l'ultima modifica e non la sostituisce.
  Future<void> enqueueOperation({
    required String reportId,
    required Map<String, Object?> report,
    required Map<String, Object?> operation,
  }) async {
    await database.transaction((transaction) async {
      await transaction.update(
        'daily_reports',
        report,
        where: 'id = ?',
        whereArgs: [reportId],
      );
      await transaction.insert(
        'outbox',
        operation,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<void> savePhoto({
    required String localReference,
    required String reportId,
    required Uint8List bytes,
  }) => database.insert('report_photos', {
    'local_reference': localReference,
    'report_id': reportId,
    'bytes': bytes,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Uint8List?> getPhoto(String localReference) async {
    final rows = await database.query(
      'report_photos',
      columns: ['bytes'],
      where: 'local_reference = ?',
      whereArgs: [localReference],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['bytes'] as Uint8List?;
  }

  Future<void> deletePhoto(String localReference) => database.delete(
    'report_photos',
    where: 'local_reference = ?',
    whereArgs: [localReference],
  );

  /// Riporta a `pending` le operazioni interrotte a metà invio, per esempio da
  /// una chiusura forzata dell'app. Il push è idempotente lato server, quindi
  /// un rinvio non duplica il report.
  Future<int> recoverInterruptedOperations() => database.update(
    'outbox',
    {'status': 'pending'},
    where: 'status = ?',
    whereArgs: ['processing'],
  );

  /// Include `processing` perché un'operazione interrotta va comunque
  /// riportata in coda dal ciclo successivo.
  Future<bool> hasPendingOperations() async {
    final rows = await database.query(
      'outbox',
      columns: ['operation_id'],
      where: 'status IN (?, ?, ?)',
      whereArgs: ['pending', 'failed', 'processing'],
      limit: 1,
    );
    return rows.isNotEmpty;
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

      // Le operazioni sullo stesso report sono in fila e ciascuna si applica
      // sopra la precedente: quella che segue attende la versione appena
      // prodotta, non quella che il dispositivo conosceva quando l'ha
      // accodata. Senza questo, un invio accodato offline dopo una modifica
      // arriverebbe sempre in conflitto.
      await transaction.update(
        'outbox',
        {'expected_version': version},
        where: 'entity_id = ? AND status IN (?, ?)',
        whereArgs: [entityId, 'pending', 'failed'],
      );
    });
  }

  Future<void> markFailed(String operationId, String error) =>
      _markUnsuccessful(operationId, 'failed', error, null);

  /// Una versione attesa divergente non si risolve ritentando: l'operazione
  /// esce dalla coda e attende una decisione esplicita.
  Future<void> markConflict(
    String operationId,
    String error,
    int? serverVersion,
  ) => _markUnsuccessful(operationId, 'conflict', error, serverVersion);

  Future<void> _markUnsuccessful(
    String operationId,
    String status,
    String error,
    int? serverVersion,
  ) async {
    await database.rawUpdate(
      '''
        UPDATE outbox
        SET status = ?, attempts = attempts + 1, last_error = ?,
            server_version = COALESCE(?, server_version)
        WHERE operation_id = ?
      ''',
      [status, error, serverVersion, operationId],
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
        {'sync_status': status == 'conflict' ? 'conflict' : 'error'},
        where: 'id = ?',
        whereArgs: [rows.single['entity_id']],
      );
    }
  }

  /// Ripropone in coda quel che il dispositivo ha scritto, sulla versione che
  /// il server dichiara adesso: è la scelta «tieni la mia».
  Future<void> resolveConflictKeepingLocal(String reportId) async {
    await database.transaction((transaction) async {
      final conflicting = await transaction.query(
        'outbox',
        where: 'entity_id = ? AND status = ?',
        whereArgs: [reportId, 'conflict'],
      );
      for (final operation in conflicting) {
        await transaction.update(
          'outbox',
          {
            'status': 'pending',
            'last_error': null,
            'expected_version':
                operation['server_version'] ?? operation['expected_version'],
          },
          where: 'operation_id = ?',
          whereArgs: [operation['operation_id']],
        );
      }
      await transaction.update(
        'daily_reports',
        {'sync_status': 'device', 'remote_snapshot': null},
        where: 'id = ?',
        whereArgs: [reportId],
      );
    });
  }

  /// Butta via quel che il dispositivo aveva in coda e tiene la versione del
  /// server, già scaricata durante il pull.
  Future<void> resolveConflictKeepingRemote(String reportId) async {
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'daily_reports',
        columns: ['remote_snapshot'],
        where: 'id = ?',
        whereArgs: [reportId],
        limit: 1,
      );
      final snapshot = rows.isEmpty ? null : rows.single['remote_snapshot'];
      await transaction.delete(
        'outbox',
        where: 'entity_id = ? AND status != ?',
        whereArgs: [reportId, 'synced'],
      );
      if (snapshot == null) {
        // Senza la copia del server non c'è niente da riportare: il report
        // resta com'è e il prossimo pull lo aggiornerà.
        await transaction.update(
          'daily_reports',
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [reportId],
        );
        return;
      }
      final remote = jsonDecode(snapshot as String) as Map<String, dynamic>;
      remote['remote_snapshot'] = null;
      await transaction.insert(
        'daily_reports',
        remote.cast<String, Object?>(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Applica quel che arriva dal server. Un report con operazioni ancora in
  /// coda non viene sovrascritto: la copia remota resta da parte, così la
  /// schermata del conflitto può mostrare le due versioni senza tornare in
  /// rete.
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
          continue;
        }
        await transaction.update(
          'daily_reports',
          {'remote_snapshot': jsonEncode(report)},
          where: 'id = ?',
          whereArgs: [report['id']],
        );
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
