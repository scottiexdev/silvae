enum ReportSyncStatus { device, syncing, synced, conflict, error }

final class DailyReport {
  const DailyReport({
    required this.id,
    required this.organizationId,
    required this.worksiteId,
    required this.reportDate,
    required this.status,
    required this.version,
    required this.syncStatus,
    required this.updatedAt,
    this.notes,
  });

  factory DailyReport.fromRow(Map<String, Object?> row) => DailyReport(
    id: row['id']! as String,
    organizationId: row['organization_id']! as String,
    worksiteId: row['worksite_id']! as String,
    reportDate: DateTime.parse(row['report_date']! as String),
    notes: row['notes'] as String?,
    status: row['status']! as String,
    version: row['version']! as int,
    syncStatus: switch (row['sync_status']) {
      'synced' => ReportSyncStatus.synced,
      'processing' => ReportSyncStatus.syncing,
      'conflict' => ReportSyncStatus.conflict,
      'error' => ReportSyncStatus.error,
      _ => ReportSyncStatus.device,
    },
    updatedAt: DateTime.parse(row['updated_at']! as String),
  );

  final String id;
  final String organizationId;
  final String worksiteId;
  final DateTime reportDate;
  final String? notes;
  final String status;
  final int version;
  final ReportSyncStatus syncStatus;
  final DateTime updatedAt;
}
