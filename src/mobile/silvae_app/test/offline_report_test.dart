import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/core/database/local_database.dart';
import 'package:silvae_app/core/sync/sync_scheduler.dart';
import 'package:silvae_app/features/daily_reports/data/daily_report_repository.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

const _organizationId = '53ff67bc-58c3-45b8-8d10-3ff4771c38c0';
const _worksiteId = '664583a8-66f2-443a-9c69-27b45eaabfd8';

Future<void> _createSchema(Database database, int version) async {
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
}

Future<Database> _openTestDatabase() => databaseFactoryFfi.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(version: 1, onCreate: _createSchema),
);

/// Un Dio che rifiuta ogni richiesta, così la sincronizzazione si può
/// esercitare senza rete e senza dipendenze aggiuntive.
Dio _rejectingDio({int? statusCode}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final response = statusCode == null
            ? null
            : Response<void>(requestOptions: options, statusCode: statusCode);
        handler.reject(
          DioException(requestOptions: options, response: response),
        );
      },
    ),
  );
  return dio;
}

/// Un Dio che conferma il push riecheggiando le operazioni ricevute e
/// restituisce un pull vuoto.
Dio _acceptingDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final now = DateTime.now().toUtc().toIso8601String();
        if (!options.path.endsWith('/push')) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {'dailyReports': <dynamic>[], 'serverTime': now},
            ),
          );
          return;
        }
        final body = options.data! as Map<String, dynamic>;
        final sent = (body['operations'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'operations': sent
                  .map(
                    (item) => {
                      'operationId': item['operationId'],
                      'entityId': item['entityId'],
                      'version': 1,
                      'wasDuplicate': false,
                    },
                  )
                  .toList(),
              'serverTime': now,
            },
          ),
        );
      },
    ),
  );
  return dio;
}

DailyReportRepository _repository(Database database, {Dio? dio}) =>
    DailyReportRepository(
      LocalDatabase(database),
      SilvaeApiClient(dio ?? Dio()),
      _organizationId,
      const Uuid(),
    );

void main() {
  sqfliteFfiInit();

  test('creating offline persists report and outbox operation', () async {
    final database = await _openTestDatabase();
    addTearDown(database.close);
    final repository = _repository(database);

    await repository.createOffline(
      worksiteId: _worksiteId,
      reportDate: DateTime(2026, 7, 25),
      notes: '  Sfalcio completato  ',
    );

    final reports = await repository.getReports();
    final operations = await LocalDatabase(database).getPendingOperations();
    expect(reports, hasLength(1));
    expect(reports.single.notes, 'Sfalcio completato');
    expect(reports.single.syncStatus, ReportSyncStatus.device);
    expect(operations, hasLength(1));
    expect(operations.single['entity_id'], reports.single.id);
  });

  test('editing offline reuses the queued operation', () async {
    final database = await _openTestDatabase();
    addTearDown(database.close);
    final repository = _repository(database);

    final reportId = await repository.createOffline(
      worksiteId: _worksiteId,
      reportDate: DateTime(2026, 7, 25),
      notes: 'Prima stesura',
    );
    await repository.updateOffline(
      reportId: reportId,
      worksiteId: _worksiteId,
      reportDate: DateTime(2026, 7, 25),
      expectedVersion: 0,
      notes: 'Seconda stesura',
    );

    final reports = await repository.getReports();
    final operations = await LocalDatabase(database).getPendingOperations();
    expect(reports.single.notes, 'Seconda stesura');
    expect(operations, hasLength(1), reason: 'le modifiche si accorpano');
    expect(operations.single['payload'], contains('Seconda stesura'));
  });

  test('an interrupted push is retried instead of orphaned', () async {
    final database = await _openTestDatabase();
    addTearDown(database.close);
    final repository = _repository(database, dio: _rejectingDio());

    await repository.createOffline(
      worksiteId: _worksiteId,
      reportDate: DateTime(2026, 7, 25),
      notes: 'Chiusura forzata',
    );
    // Simula l'app uccisa fra l'invio e la risposta.
    await database.update('outbox', {'status': 'processing'});
    expect(await LocalDatabase(database).getPendingOperations(), isEmpty);

    await repository.synchronize();

    final operations = await database.query('outbox');
    expect(operations.single['status'], 'failed');
    expect(operations.single['attempts'], 1);
    expect(await LocalDatabase(database).getPendingOperations(), hasLength(1));
  });

  test('a successful sync empties the queue and stops retrying', () async {
    final database = await _openTestDatabase();
    addTearDown(database.close);
    final repository = _repository(database, dio: _acceptingDio());
    final scheduler = SyncScheduler(repository);
    addTearDown(scheduler.dispose);

    await repository.createOffline(
      worksiteId: _worksiteId,
      reportDate: DateTime(2026, 7, 25),
      notes: 'Rientro in copertura',
    );
    await scheduler.syncNow();

    expect(await repository.hasPendingOperations(), isFalse);
    expect(scheduler.pendingRetry, isNull);
    final reports = await repository.getReports();
    expect(reports.single.syncStatus, ReportSyncStatus.synced);
  });

  test('a failed sync arms a growing retry', () async {
    final database = await _openTestDatabase();
    addTearDown(database.close);
    final repository = _repository(database, dio: _rejectingDio());
    final scheduler = SyncScheduler(
      repository,
      firstRetry: const Duration(seconds: 30),
      maxRetry: const Duration(minutes: 2),
    );
    addTearDown(scheduler.dispose);

    await repository.createOffline(
      worksiteId: _worksiteId,
      reportDate: DateTime(2026, 7, 25),
      notes: 'Fuori campo',
    );
    await scheduler.syncNow();

    expect(await repository.hasPendingOperations(), isTrue);
    expect(scheduler.pendingRetry, const Duration(minutes: 1));
  });

  test('a version conflict leaves the outbox queue', () async {
    final database = await _openTestDatabase();
    addTearDown(database.close);
    final repository = _repository(
      database,
      dio: _rejectingDio(statusCode: 409),
    );

    await repository.createOffline(
      worksiteId: _worksiteId,
      reportDate: DateTime(2026, 7, 25),
      notes: 'Modificato anche in ufficio',
    );
    await repository.synchronize();

    final operations = await database.query('outbox');
    expect(operations.single['status'], 'conflict');
    expect(await LocalDatabase(database).getPendingOperations(), isEmpty);
    final reports = await repository.getReports();
    expect(reports.single.syncStatus, ReportSyncStatus.conflict);
  });
}
