import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/core/database/local_database.dart';
import 'package:silvae_app/features/daily_reports/data/daily_report_repository.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();

  test('creating offline persists both report and outbox operation', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
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
        },
      ),
    );
    addTearDown(database.close);
    final repository = DailyReportRepository(
      LocalDatabase(database),
      SilvaeApiClient(Dio()),
      '53ff67bc-58c3-45b8-8d10-3ff4771c38c0',
      const Uuid(),
    );

    await repository.createOffline(
      worksiteId: '664583a8-66f2-443a-9c69-27b45eaabfd8',
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
}
