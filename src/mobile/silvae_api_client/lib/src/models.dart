final class WorksiteDto {
  const WorksiteDto({
    required this.id,
    required this.code,
    required this.name,
    required this.version,
    required this.updatedAt,
    this.address,
  });

  factory WorksiteDto.fromJson(Map<String, dynamic> json) => WorksiteDto(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    version: json['version'] as int,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String id;
  final String code;
  final String name;
  final String? address;
  final int version;
  final DateTime updatedAt;
}

final class SyncOperationDto {
  const SyncOperationDto({
    required this.operationId,
    required this.organizationId,
    required this.entityId,
    required this.entityType,
    required this.operationType,
    required this.expectedVersion,
    required this.payload,
    required this.createdAt,
  });

  final String operationId;
  final String organizationId;
  final String entityId;
  final String entityType;
  final String operationType;
  final int expectedVersion;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'organizationId': organizationId,
    'entityId': entityId,
    'entityType': entityType,
    'operationType': operationType,
    'expectedVersion': expectedVersion,
    'payload': payload,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

final class SyncOperationResultDto {
  const SyncOperationResultDto({
    required this.operationId,
    required this.entityId,
    required this.version,
    required this.wasDuplicate,
  });

  factory SyncOperationResultDto.fromJson(Map<String, dynamic> json) =>
      SyncOperationResultDto(
        operationId: json['operationId'] as String,
        entityId: json['entityId'] as String,
        version: json['version'] as int,
        wasDuplicate: json['wasDuplicate'] as bool,
      );

  final String operationId;
  final String entityId;
  final int version;
  final bool wasDuplicate;
}

final class PushSyncResponse {
  const PushSyncResponse({required this.operations, required this.serverTime});

  factory PushSyncResponse.fromJson(Map<String, dynamic> json) =>
      PushSyncResponse(
        operations: (json['operations'] as List<dynamic>)
            .map(
              (item) =>
                  SyncOperationResultDto.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        serverTime: DateTime.parse(json['serverTime'] as String),
      );

  final List<SyncOperationResultDto> operations;
  final DateTime serverTime;
}

final class DailyReportSyncDto {
  const DailyReportSyncDto({
    required this.id,
    required this.organizationId,
    required this.worksiteId,
    required this.authorId,
    required this.reportDate,
    required this.status,
    required this.version,
    required this.updatedAt,
    this.notes,
  });

  factory DailyReportSyncDto.fromJson(Map<String, dynamic> json) =>
      DailyReportSyncDto(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        worksiteId: json['worksiteId'] as String,
        authorId: json['authorId'] as String,
        reportDate: DateTime.parse(json['reportDate'] as String),
        notes: json['notes'] as String?,
        status: json['status'] as String,
        version: json['version'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  final String id;
  final String organizationId;
  final String worksiteId;
  final String authorId;
  final DateTime reportDate;
  final String? notes;
  final String status;
  final int version;
  final DateTime updatedAt;
}

final class PullSyncResponse {
  const PullSyncResponse({
    required this.dailyReports,
    required this.serverTime,
  });

  factory PullSyncResponse.fromJson(Map<String, dynamic> json) =>
      PullSyncResponse(
        dailyReports: (json['dailyReports'] as List<dynamic>)
            .map(
              (item) =>
                  DailyReportSyncDto.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        serverTime: DateTime.parse(json['serverTime'] as String),
      );

  final List<DailyReportSyncDto> dailyReports;
  final DateTime serverTime;
}
