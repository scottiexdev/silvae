import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
                  'job_order_id': item.jobOrderId,
                  'job_order_code': item.jobOrderCode,
                  'job_order_name': item.jobOrderName,
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

  Future<DailyReport?> getReport(String reportId) async {
    final row = await _localDatabase.getDailyReport(reportId);
    return row == null ? null : DailyReport.fromRow(row);
  }

  Future<String> createOffline({
    required String worksiteId,
    required DateTime reportDate,
    String? notes,
    ReportContent content = const ReportContent(),
  }) async {
    final now = DateTime.now().toUtc();
    final reportId = _uuid.v4();
    final normalizedDate = _dateOnly(reportDate);
    final trimmedNotes = _trimmed(notes);

    await _localDatabase.createOfflineReport(
      report: {
        'id': reportId,
        'organization_id': _organizationId,
        'worksite_id': worksiteId,
        'report_date': normalizedDate,
        'notes': trimmedNotes,
        'content': content.encode(),
        'status': 'Draft',
        'version': 0,
        'sync_status': 'device',
        'updated_at': now.toIso8601String(),
      },
      operation: _operation(
        entityId: reportId,
        operationType: 'upsert',
        expectedVersion: 0,
        payload: _upsertPayload(
          worksiteId: worksiteId,
          reportDate: normalizedDate,
          notes: trimmedNotes,
          content: content,
        ),
        createdAt: now,
      ),
    );
    return reportId;
  }

  /// Aggiorna un report già presente sul dispositivo. Le modifiche successive
  /// allo stesso report confluiscono nell'operazione già in coda invece di
  /// accodarne una seconda: due upsert consecutivi con la stessa versione
  /// attesa produrrebbero un conflitto garantito.
  Future<void> updateOffline({
    required String reportId,
    required String worksiteId,
    required DateTime reportDate,
    required int expectedVersion,
    String? notes,
    ReportContent content = const ReportContent(),
  }) async {
    final now = DateTime.now().toUtc();
    final normalizedDate = _dateOnly(reportDate);
    final trimmedNotes = _trimmed(notes);

    await _localDatabase.updateOfflineReport(
      reportId: reportId,
      report: {
        'worksite_id': worksiteId,
        'report_date': normalizedDate,
        'notes': trimmedNotes,
        'content': content.encode(),
        'sync_status': 'device',
        'updated_at': now.toIso8601String(),
      },
      operation: _operation(
        entityId: reportId,
        operationType: 'upsert',
        expectedVersion: expectedVersion,
        payload: _upsertPayload(
          worksiteId: worksiteId,
          reportDate: normalizedDate,
          notes: trimmedNotes,
          content: content,
        ),
        createdAt: now,
      ),
    );
  }

  /// Accoda l'invio con la conferma del caposquadra. Passa dalla coda perché
  /// avviene in cantiere, dove la rete spesso non c'è.
  Future<void> submitOffline({
    required String reportId,
    required int expectedVersion,
    required String signature,
  }) async {
    final now = DateTime.now().toUtc();
    await _localDatabase.enqueueOperation(
      reportId: reportId,
      report: {
        'status': 'Submitted',
        'signature': signature.trim(),
        'sync_status': 'device',
        'updated_at': now.toIso8601String(),
      },
      operation: _operation(
        entityId: reportId,
        operationType: 'submit',
        expectedVersion: expectedVersion,
        payload: {'signature': signature.trim()},
        createdAt: now,
      ),
    );
  }

  Future<void> addPhoto({
    required String reportId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _localDatabase.savePhoto(
      localReference: fileName,
      reportId: reportId,
      bytes: bytes,
    );
  }

  Future<Uint8List?> getPhotoBytes(String localReference) =>
      _localDatabase.getPhoto(localReference);

  Future<void> keepLocalVersion(String reportId) =>
      _localDatabase.resolveConflictKeepingLocal(reportId);

  Future<void> keepServerVersion(String reportId) =>
      _localDatabase.resolveConflictKeepingRemote(reportId);

  Future<bool> hasPendingOperations() => _localDatabase.hasPendingOperations();

  Future<void> synchronize() async {
    await _localDatabase.recoverInterruptedOperations();
    final operations = await _localDatabase.getPendingOperations();

    // La coda è stata letta tutta insieme, ma ogni operazione andata a buon
    // fine cambia la versione dell'entità: quella dopo va inviata con la
    // versione appena prodotta, non con quella che aveva la riga letta prima.
    final appliedVersions = <String, int>{};

    for (final row in operations) {
      final operationId = row['operation_id']! as String;
      final entityId = row['entity_id']! as String;
      await _localDatabase.markProcessing(operationId);
      try {
        final response = await _apiClient.pushSync([
          api.SyncOperationDto(
            operationId: operationId,
            organizationId: row['organization_id']! as String,
            entityId: entityId,
            entityType: row['entity_type']! as String,
            operationType: row['operation_type']! as String,
            expectedVersion:
                appliedVersions[entityId] ?? row['expected_version']! as int,
            payload: LocalDatabase.decodePayload(row['payload']),
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        ]);
        final result = response.operations.single;
        appliedVersions[result.entityId] = result.version;
        await _localDatabase.markSynced(
          operationId: result.operationId,
          entityId: result.entityId,
          version: result.version,
        );
      } on DioException catch (error) {
        if (error.response?.statusCode == 409) {
          await _localDatabase.markConflict(
            operationId,
            error.toString(),
            _serverVersionOf(error.response?.data),
          );
        } else {
          await _localDatabase.markFailed(operationId, error.toString());
        }
      } on Object catch (error) {
        await _localDatabase.markFailed(operationId, error.toString());
      }
    }

    try {
      final remote = await _apiClient.pullSync(
        changedSince: await _localDatabase.getLastPull(),
      );
      await _localDatabase.upsertRemoteReports(
        remote.dailyReports.map(_remoteRow).toList(growable: false),
        remote.serverTime,
      );
    } on Object {
      // Il push già confermato resta confermato; il pull sarà ritentato.
    }
  }

  Map<String, Object?> _remoteRow(api.DailyReportSyncDto item) => {
    'id': item.id,
    'organization_id': item.organizationId,
    'worksite_id': item.worksiteId,
    'author_id': item.authorId,
    'report_date': _dateOnly(item.reportDate),
    'notes': item.notes,
    'signature': item.signature,
    'content': jsonEncode({
      'crew': item.crew,
      'activities': item.activities,
      'safetyChecks': item.safetyChecks,
      'photos': item.photos,
    }),
    'status': item.status,
    'version': item.version,
    'sync_status': 'synced',
    'updated_at': item.updatedAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> _operation({
    required String entityId,
    required String operationType,
    required int expectedVersion,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
  }) => {
    'operation_id': _uuid.v4(),
    'organization_id': _organizationId,
    'entity_id': entityId,
    'entity_type': 'dailyReport',
    'operation_type': operationType,
    'expected_version': expectedVersion,
    'payload': jsonEncode(payload),
    'created_at': createdAt.toIso8601String(),
    'attempts': 0,
    'last_error': null,
    'status': 'pending',
  };

  static Map<String, dynamic> _upsertPayload({
    required String worksiteId,
    required String reportDate,
    required String? notes,
    required ReportContent content,
  }) => {
    'worksiteId': worksiteId,
    'reportDate': reportDate,
    'notes': notes,
    ...content.toJson(),
  };

  /// Il 409 porta con sé la versione che il server ha adesso: senza, «tieni la
  /// mia versione» non saprebbe su quale versione riproporsi.
  static int? _serverVersionOf(Object? body) {
    if (body is! Map) {
      return null;
    }
    final context = body['context'];
    return context is Map ? context['currentVersion'] as int? : null;
  }

  static String? _trimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
