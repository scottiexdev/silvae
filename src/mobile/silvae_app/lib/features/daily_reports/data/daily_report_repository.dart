import 'dart:convert';

import 'package:silvae_api_client/silvae_api_client.dart' as api;
import 'package:silvae_app/core/database/local_database.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:silvae_app/features/worksites/domain/worksite.dart';
import 'package:uuid/uuid.dart';

final class DailyReportRepository {
  DailyReportRepository(
    this._localDatabase,
    this._apiClient,
    this._organizationId, [
    this._uuid = const Uuid(),
  ]);

  final LocalDatabase _localDatabase;
  final api.SilvaeApiClient _apiClient;
  final String _organizationId;
  final Uuid _uuid;

  Future<List<Worksite>> getWorksites({bool refresh = false}) async {
    if (refresh) {
      try {
        final remote = await _apiClient.getAssignedWorksites();
        await _localDatabase.replaceWorksites(
          remote
              .map(
                (item) => {
                  'id': item.id,
                  'code': item.code,
                  'name': item.name,
                  'address': item.address,
                  'version': item.version,
                  'updated_at': item.updatedAt.toUtc().toIso8601String(),
                },
              )
              .toList(growable: false),
        );
      } on Object {
        // La cache locale resta utilizzabile in assenza di rete.
      }
    }
    return (await _localDatabase.getWorksites())
        .map(Worksite.fromRow)
        .toList(growable: false);
  }

  Future<List<DailyReport>> getReports() async {
    return (await _localDatabase.getDailyReports())
        .map(DailyReport.fromRow)
        .toList(growable: false);
  }

  Future<String> createOffline({
    required String worksiteId,
    required DateTime reportDate,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final reportId = _uuid.v4();
    final operationId = _uuid.v4();
    final normalizedDate = DateTime.utc(
      reportDate.year,
      reportDate.month,
      reportDate.day,
    );
    final trimmedNotes = notes?.trim();
    final payload = {
      'worksiteId': worksiteId,
      'reportDate': _dateOnly(normalizedDate),
      'notes': trimmedNotes == null || trimmedNotes.isEmpty
          ? null
          : trimmedNotes,
    };

    await _localDatabase.createOfflineReport(
      report: {
        'id': reportId,
        'organization_id': _organizationId,
        'worksite_id': worksiteId,
        'report_date': _dateOnly(normalizedDate),
        'notes': payload['notes'],
        'status': 'Draft',
        'version': 0,
        'sync_status': 'device',
        'updated_at': now.toIso8601String(),
      },
      operation: {
        'operation_id': operationId,
        'organization_id': _organizationId,
        'entity_id': reportId,
        'entity_type': 'dailyReport',
        'operation_type': 'upsert',
        'expected_version': 0,
        'payload': jsonEncode(payload),
        'created_at': now.toIso8601String(),
        'attempts': 0,
        'last_error': null,
        'status': 'pending',
      },
    );
    return reportId;
  }

  Future<void> synchronize() async {
    final operations = await _localDatabase.getPendingOperations();
    for (final row in operations) {
      final operationId = row['operation_id']! as String;
      await _localDatabase.markProcessing(operationId);
      try {
        final response = await _apiClient.pushSync([
          api.SyncOperationDto(
            operationId: operationId,
            organizationId: row['organization_id']! as String,
            entityId: row['entity_id']! as String,
            entityType: row['entity_type']! as String,
            operationType: row['operation_type']! as String,
            expectedVersion: row['expected_version']! as int,
            payload: LocalDatabase.decodePayload(row['payload']),
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        ]);
        final result = response.operations.single;
        await _localDatabase.markSynced(
          operationId: result.operationId,
          entityId: result.entityId,
          version: result.version,
        );
      } on Object catch (error) {
        await _localDatabase.markFailed(operationId, error.toString());
      }
    }

    try {
      final remote = await _apiClient.pullSync(
        changedSince: await _localDatabase.getLastPull(),
      );
      await _localDatabase.upsertRemoteReports(
        remote.dailyReports
            .map(
              (item) => {
                'id': item.id,
                'organization_id': item.organizationId,
                'worksite_id': item.worksiteId,
                'report_date': _dateOnly(item.reportDate),
                'notes': item.notes,
                'status': item.status,
                'version': item.version,
                'sync_status': 'synced',
                'updated_at': item.updatedAt.toUtc().toIso8601String(),
              },
            )
            .toList(growable: false),
        remote.serverTime,
      );
    } on Object {
      // Il push già confermato resta confermato; il pull sarà ritentato.
    }
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
