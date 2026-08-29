/// Data senza orario, come la scambia il contratto: `yyyy-MM-dd`.
String formatDateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

final class CurrentUserDto {
  const CurrentUserDto({
    required this.userId,
    required this.memberships,
    this.selectedOrganizationId,
  });

  factory CurrentUserDto.fromJson(Map<String, dynamic> json) => CurrentUserDto(
    userId: json['userId'] as String,
    selectedOrganizationId: json['selectedOrganizationId'] as String?,
    memberships: (json['memberships'] as List<dynamic>)
        .map((item) => MembershipDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String userId;
  final String? selectedOrganizationId;
  final List<MembershipDto> memberships;

  /// Il ruolo nell'organizzazione selezionata, o `Worker` se non risulta:
  /// nel dubbio si concede il meno, non il più.
  String roleIn(String organizationId) {
    for (final membership in memberships) {
      if (membership.organizationId == organizationId) {
        return membership.role;
      }
    }
    return 'Worker';
  }
}

final class MembershipDto {
  const MembershipDto({
    required this.organizationId,
    required this.displayName,
    required this.role,
  });

  factory MembershipDto.fromJson(Map<String, dynamic> json) => MembershipDto(
    organizationId: json['organizationId'] as String,
    displayName: json['displayName'] as String,
    role: json['role'] as String,
  );

  final String organizationId;
  final String displayName;
  final String role;
}

final class OrganizationMemberDto {
  const OrganizationMemberDto({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  factory OrganizationMemberDto.fromJson(Map<String, dynamic> json) =>
      OrganizationMemberDto(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        role: json['role'] as String,
      );

  final String userId;
  final String displayName;
  final String role;
}

final class JobOrderDto {
  const JobOrderDto({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    this.customer,
  });

  factory JobOrderDto.fromJson(Map<String, dynamic> json) => JobOrderDto(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    customer: json['customer'] as String?,
    isActive: json['isActive'] as bool,
  );

  final String id;
  final String code;
  final String name;
  final String? customer;
  final bool isActive;
}

final class WorksiteDto {
  const WorksiteDto({
    required this.id,
    required this.code,
    required this.name,
    required this.version,
    required this.updatedAt,
    this.address,
    this.jobOrderId,
    this.jobOrderCode,
    this.jobOrderName,
    this.isActive = true,
  });

  factory WorksiteDto.fromJson(Map<String, dynamic> json) => WorksiteDto(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    jobOrderId: json['jobOrderId'] as String?,
    jobOrderCode: json['jobOrderCode'] as String?,
    jobOrderName: json['jobOrderName'] as String?,
    isActive: json['isActive'] as bool? ?? true,
    version: json['version'] as int,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final String id;
  final String code;
  final String name;
  final String? address;
  final String? jobOrderId;
  final String? jobOrderCode;
  final String? jobOrderName;
  final bool isActive;
  final int version;
  final DateTime updatedAt;
}

final class WorksiteDetailDto {
  const WorksiteDetailDto({required this.worksite, required this.assignments});

  factory WorksiteDetailDto.fromJson(
    Map<String, dynamic> json,
  ) => WorksiteDetailDto(
    worksite: WorksiteDto.fromJson(json['worksite'] as Map<String, dynamic>),
    assignments: (json['assignments'] as List<dynamic>)
        .map((item) => WorksiteMemberDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  final WorksiteDto worksite;
  final List<WorksiteMemberDto> assignments;
}

final class WorksiteMemberDto {
  const WorksiteMemberDto({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  factory WorksiteMemberDto.fromJson(Map<String, dynamic> json) =>
      WorksiteMemberDto(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        role: json['role'] as String,
      );

  final String userId;
  final String displayName;
  final String role;
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
    required this.crew,
    required this.activities,
    required this.safetyChecks,
    required this.photos,
    this.notes,
    this.signature,
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
        signature: json['signature'] as String?,
        version: json['version'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        crew: _listOf(json['crew']),
        activities: _listOf(json['activities']),
        safetyChecks: _listOf(json['safetyChecks']),
        photos: _listOf(json['photos']),
      );

  final String id;
  final String organizationId;
  final String worksiteId;
  final String authorId;
  final DateTime reportDate;
  final String? notes;
  final String status;
  final String? signature;
  final int version;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> crew;
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> safetyChecks;
  final List<Map<String, dynamic>> photos;

  static List<Map<String, dynamic>> _listOf(Object? value) =>
      (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().toList(
        growable: false,
      );
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

/// La riga di elenco che l'ufficio consulta.
final class DailyReportSummaryDto {
  const DailyReportSummaryDto({
    required this.id,
    required this.worksiteId,
    required this.worksiteCode,
    required this.worksiteName,
    required this.authorId,
    required this.authorName,
    required this.reportDate,
    required this.status,
    required this.totalHours,
    required this.crewCount,
    required this.photoCount,
    required this.hasSafetyFinding,
    required this.version,
    this.jobOrderId,
    this.jobOrderCode,
    this.jobOrderName,
    this.signature,
  });

  factory DailyReportSummaryDto.fromJson(Map<String, dynamic> json) =>
      DailyReportSummaryDto(
        id: json['id'] as String,
        worksiteId: json['worksiteId'] as String,
        worksiteCode: json['worksiteCode'] as String,
        worksiteName: json['worksiteName'] as String,
        jobOrderId: json['jobOrderId'] as String?,
        jobOrderCode: json['jobOrderCode'] as String?,
        jobOrderName: json['jobOrderName'] as String?,
        authorId: json['authorId'] as String,
        authorName: json['authorName'] as String,
        reportDate: DateTime.parse(json['reportDate'] as String),
        status: json['status'] as String,
        totalHours: (json['totalHours'] as num).toDouble(),
        crewCount: json['crewCount'] as int,
        photoCount: json['photoCount'] as int,
        hasSafetyFinding: json['hasSafetyFinding'] as bool,
        signature: json['signature'] as String?,
        version: json['version'] as int,
      );

  final String id;
  final String worksiteId;
  final String worksiteCode;
  final String worksiteName;
  final String? jobOrderId;
  final String? jobOrderCode;
  final String? jobOrderName;
  final String authorId;
  final String authorName;
  final DateTime reportDate;
  final String status;
  final double totalHours;
  final int crewCount;
  final int photoCount;
  final bool hasSafetyFinding;
  final String? signature;
  final int version;
}

final class CertificationDto {
  const CertificationDto({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.kind,
    required this.validFrom,
    required this.isValidToday,
    this.issuer,
    this.expiresOn,
    this.notes,
    this.documentId,
    this.daysToExpiry,
  });

  factory CertificationDto.fromJson(Map<String, dynamic> json) =>
      CertificationDto(
        id: json['id'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        kind: json['kind'] as String,
        issuer: json['issuer'] as String?,
        validFrom: DateTime.parse(json['validFrom'] as String),
        expiresOn: json['expiresOn'] == null
            ? null
            : DateTime.parse(json['expiresOn'] as String),
        notes: json['notes'] as String?,
        documentId: json['documentId'] as String?,
        isValidToday: json['isValidToday'] as bool,
        daysToExpiry: json['daysToExpiry'] as int?,
      );

  final String id;
  final String userId;
  final String displayName;
  final String kind;
  final String? issuer;
  final DateTime validFrom;
  final DateTime? expiresOn;
  final String? notes;
  final String? documentId;
  final bool isValidToday;
  final int? daysToExpiry;
}

final class InspectionDayDto {
  const InspectionDayDto({
    required this.reportId,
    required this.reportDate,
    required this.worksiteId,
    required this.worksiteCode,
    required this.worksiteName,
    required this.status,
    required this.crew,
  });

  factory InspectionDayDto.fromJson(Map<String, dynamic> json) =>
      InspectionDayDto(
        reportId: json['reportId'] as String,
        reportDate: DateTime.parse(json['reportDate'] as String),
        worksiteId: json['worksiteId'] as String,
        worksiteCode: json['worksiteCode'] as String,
        worksiteName: json['worksiteName'] as String,
        status: json['status'] as String,
        crew: (json['crew'] as List<dynamic>)
            .map(
              (item) =>
                  InspectionPersonDto.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );

  final String reportId;
  final DateTime reportDate;
  final String worksiteId;
  final String worksiteCode;
  final String worksiteName;
  final String status;
  final List<InspectionPersonDto> crew;
}

final class InspectionPersonDto {
  const InspectionPersonDto({
    required this.userId,
    required this.displayName,
    required this.hours,
    required this.certifications,
  });

  factory InspectionPersonDto.fromJson(
    Map<String, dynamic> json,
  ) => InspectionPersonDto(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    hours: (json['hours'] as num).toDouble(),
    certifications: (json['certifications'] as List<dynamic>)
        .map(
          (item) =>
              InspectionCertificationDto.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
  );

  final String userId;
  final String displayName;
  final double hours;
  final List<InspectionCertificationDto> certifications;
}

final class InspectionCertificationDto {
  const InspectionCertificationDto({
    required this.kind,
    required this.validFrom,
    this.issuer,
    this.expiresOn,
    this.documentId,
  });

  factory InspectionCertificationDto.fromJson(Map<String, dynamic> json) =>
      InspectionCertificationDto(
        kind: json['kind'] as String,
        issuer: json['issuer'] as String?,
        validFrom: DateTime.parse(json['validFrom'] as String),
        expiresOn: json['expiresOn'] == null
            ? null
            : DateTime.parse(json['expiresOn'] as String),
        documentId: json['documentId'] as String?,
      );

  final String kind;
  final String? issuer;
  final DateTime validFrom;
  final DateTime? expiresOn;
  final String? documentId;
}

final class DocumentDto {
  const DocumentDto({
    required this.id,
    required this.title,
    required this.category,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.isExpired,
    required this.uploadedAt,
    this.worksiteId,
    this.issuedOn,
    this.expiresOn,
  });

  factory DocumentDto.fromJson(Map<String, dynamic> json) => DocumentDto(
    id: json['id'] as String,
    worksiteId: json['worksiteId'] as String?,
    title: json['title'] as String,
    category: json['category'] as String,
    issuedOn: json['issuedOn'] == null
        ? null
        : DateTime.parse(json['issuedOn'] as String),
    expiresOn: json['expiresOn'] == null
        ? null
        : DateTime.parse(json['expiresOn'] as String),
    fileName: json['fileName'] as String,
    contentType: json['contentType'] as String,
    sizeBytes: json['sizeBytes'] as int,
    isExpired: json['isExpired'] as bool,
    uploadedAt: DateTime.parse(json['uploadedAt'] as String),
  );

  final String id;
  final String? worksiteId;
  final String title;
  final String category;
  final DateTime? issuedOn;
  final DateTime? expiresOn;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final bool isExpired;
  final DateTime uploadedAt;
}

/// Un file scaricato dall'API, con il nome con cui va salvato.
final class DownloadedFile {
  const DownloadedFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final List<int> bytes;
  final String fileName;
  final String contentType;
}
