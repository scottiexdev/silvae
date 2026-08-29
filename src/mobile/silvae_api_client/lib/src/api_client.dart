import 'package:dio/dio.dart';
import 'package:silvae_api_client/src/models.dart';

final class SilvaeApiClient {
  const SilvaeApiClient(this._dio);

  final Dio _dio;

  Future<CurrentUserDto> getCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/me');
    return CurrentUserDto.fromJson(response.data!);
  }

  Future<List<WorksiteDto>> getAssignedWorksites({
    bool includeInactive = false,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/worksites',
      queryParameters: {if (includeInactive) 'includeInactive': true},
    );
    return response.data!
        .map((item) => WorksiteDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<WorksiteDetailDto> getWorksite(String worksiteId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/worksites/$worksiteId',
    );
    return WorksiteDetailDto.fromJson(response.data!);
  }

  Future<WorksiteDetailDto> createWorksite({
    required String code,
    required String name,
    String? address,
    String? jobOrderId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/worksites',
      data: {
        'code': code,
        'name': name,
        'address': address,
        'jobOrderId': jobOrderId,
      },
    );
    return WorksiteDetailDto.fromJson(response.data!);
  }

  /// Un campo assente lascia il valore com'è. Per staccare il cantiere dalla
  /// commessa si invia l'identificativo vuoto, come vuole il contratto.
  Future<WorksiteDetailDto> updateWorksite(
    String worksiteId, {
    String? name,
    String? address,
    String? jobOrderId,
    bool? isActive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/worksites/$worksiteId',
      data: {
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (jobOrderId != null) 'jobOrderId': jobOrderId,
        if (isActive != null) 'isActive': isActive,
      },
    );
    return WorksiteDetailDto.fromJson(response.data!);
  }

  Future<void> assignWorksiteMember(String worksiteId, String userId) async {
    await _dio.put<void>('/api/worksites/$worksiteId/assignments/$userId');
  }

  Future<void> unassignWorksiteMember(String worksiteId, String userId) async {
    await _dio.delete<void>('/api/worksites/$worksiteId/assignments/$userId');
  }

  Future<List<JobOrderDto>> getJobOrders() async {
    final response = await _dio.get<List<dynamic>>('/api/job-orders');
    return response.data!
        .map((item) => JobOrderDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<JobOrderDto> createJobOrder({
    required String code,
    required String name,
    String? customer,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/job-orders',
      data: {'code': code, 'name': name, 'customer': customer},
    );
    return JobOrderDto.fromJson(response.data!);
  }

  Future<JobOrderDto> updateJobOrder(
    String jobOrderId, {
    String? name,
    String? customer,
    bool? isActive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/job-orders/$jobOrderId',
      data: {
        if (name != null) 'name': name,
        if (customer != null) 'customer': customer,
        if (isActive != null) 'isActive': isActive,
      },
    );
    return JobOrderDto.fromJson(response.data!);
  }

  Future<List<OrganizationMemberDto>> getOrganizationMembers() async {
    final response = await _dio.get<List<dynamic>>('/api/organization/members');
    return response.data!
        .map(
          (item) =>
              OrganizationMemberDto.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<OrganizationMemberDto> upsertOrganizationMember({
    required String userId,
    required String displayName,
    required String role,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/organization/members/$userId',
      data: {'displayName': displayName, 'role': role},
    );
    return OrganizationMemberDto.fromJson(response.data!);
  }

  Future<void> removeOrganizationMember(String userId) async {
    await _dio.delete<void>('/api/organization/members/$userId');
  }

  Future<List<DailyReportSummaryDto>> searchDailyReports({
    String? jobOrderId,
    String? worksiteId,
    String? crewUserId,
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/daily-reports',
      queryParameters: _reportQuery(
        jobOrderId: jobOrderId,
        worksiteId: worksiteId,
        crewUserId: crewUserId,
        from: from,
        to: to,
        status: status,
      ),
    );
    return response.data!
        .map(
          (item) =>
              DailyReportSummaryDto.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> approveDailyReport(String reportId) async {
    await _dio.post<void>('/api/daily-reports/$reportId/approve');
  }

  Future<void> reopenDailyReport(String reportId) async {
    await _dio.post<void>('/api/daily-reports/$reportId/reopen');
  }

  Future<DownloadedFile> exportDailyReports({
    required bool asPdf,
    String? jobOrderId,
    String? worksiteId,
    String? crewUserId,
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final path = asPdf
        ? '/api/daily-reports/export.pdf'
        : '/api/daily-reports/export.csv';
    final response = await _dio.get<List<int>>(
      path,
      queryParameters: _reportQuery(
        jobOrderId: jobOrderId,
        worksiteId: worksiteId,
        crewUserId: crewUserId,
        from: from,
        to: to,
        status: status,
      ),
      options: Options(responseType: ResponseType.bytes),
    );
    return DownloadedFile(
      bytes: response.data!,
      fileName: asPdf ? 'rendicontazione.pdf' : 'rendicontazione.csv',
      contentType: asPdf ? 'application/pdf' : 'text/csv',
    );
  }

  Future<List<CertificationDto>> getCertifications({String? userId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/certifications',
      queryParameters: {if (userId != null) 'userId': userId},
    );
    return response.data!
        .map((item) => CertificationDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<CertificationDto>> getExpiringCertifications({
    int withinDays = 60,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/certifications/expiring',
      queryParameters: {'withinDays': withinDays},
    );
    return response.data!
        .map((item) => CertificationDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<InspectionDayDto>> getCertificationInspection({
    required DateTime from,
    required DateTime to,
    String? worksiteId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/certifications/inspection',
      queryParameters: {
        'from': formatDateOnly(from),
        'to': formatDateOnly(to),
        if (worksiteId != null) 'worksiteId': worksiteId,
      },
    );
    return response.data!
        .map((item) => InspectionDayDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<CertificationDto> createCertification({
    required String userId,
    required String kind,
    required DateTime validFrom,
    DateTime? expiresOn,
    String? issuer,
    String? notes,
    String? documentId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/certifications',
      data: _certificationBody(
        userId: userId,
        kind: kind,
        validFrom: validFrom,
        expiresOn: expiresOn,
        issuer: issuer,
        notes: notes,
        documentId: documentId,
      ),
    );
    return CertificationDto.fromJson(response.data!);
  }

  Future<CertificationDto> updateCertification(
    String certificationId, {
    required String userId,
    required String kind,
    required DateTime validFrom,
    DateTime? expiresOn,
    String? issuer,
    String? notes,
    String? documentId,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/certifications/$certificationId',
      data: _certificationBody(
        userId: userId,
        kind: kind,
        validFrom: validFrom,
        expiresOn: expiresOn,
        issuer: issuer,
        notes: notes,
        documentId: documentId,
      ),
    );
    return CertificationDto.fromJson(response.data!);
  }

  Future<void> deleteCertification(String certificationId) async {
    await _dio.delete<void>('/api/certifications/$certificationId');
  }

  Future<List<DocumentDto>> getDocuments({String? worksiteId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/documents',
      queryParameters: {if (worksiteId != null) 'worksiteId': worksiteId},
    );
    return response.data!
        .map((item) => DocumentDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<DocumentDto> uploadDocument({
    required String title,
    required String category,
    required String fileName,
    required List<int> bytes,
    String? worksiteId,
    DateTime? issuedOn,
    DateTime? expiresOn,
  }) async {
    final form = FormData.fromMap({
      'title': title,
      'category': category,
      if (worksiteId != null) 'worksiteId': worksiteId,
      if (issuedOn != null) 'issuedOn': formatDateOnly(issuedOn),
      if (expiresOn != null) 'expiresOn': formatDateOnly(expiresOn),
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/documents',
      data: form,
    );
    return DocumentDto.fromJson(response.data!);
  }

  Future<DownloadedFile> downloadDocument(DocumentDto document) async {
    final response = await _dio.get<List<int>>(
      '/api/documents/${document.id}/content',
      options: Options(responseType: ResponseType.bytes),
    );
    return DownloadedFile(
      bytes: response.data!,
      fileName: document.fileName,
      contentType: document.contentType,
    );
  }

  Future<void> deleteDocument(String documentId) async {
    await _dio.delete<void>('/api/documents/$documentId');
  }

  Future<PushSyncResponse> pushSync(List<SyncOperationDto> operations) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/sync/push',
      data: {'operations': operations.map((item) => item.toJson()).toList()},
    );
    return PushSyncResponse.fromJson(response.data!);
  }

  Future<PullSyncResponse> pullSync({DateTime? changedSince}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/sync/pull',
      queryParameters: {
        if (changedSince != null)
          'changedSince': changedSince.toUtc().toIso8601String(),
      },
    );
    return PullSyncResponse.fromJson(response.data!);
  }

  static Map<String, dynamic> _certificationBody({
    required String userId,
    required String kind,
    required DateTime validFrom,
    required DateTime? expiresOn,
    required String? issuer,
    required String? notes,
    required String? documentId,
  }) => {
    'userId': userId,
    'kind': kind,
    'validFrom': formatDateOnly(validFrom),
    'expiresOn': expiresOn == null ? null : formatDateOnly(expiresOn),
    'issuer': issuer,
    'notes': notes,
    'documentId': documentId,
  };

  static Map<String, dynamic> _reportQuery({
    required String? jobOrderId,
    required String? worksiteId,
    required String? crewUserId,
    required DateTime? from,
    required DateTime? to,
    required String? status,
  }) => {
    if (jobOrderId != null) 'jobOrderId': jobOrderId,
    if (worksiteId != null) 'worksiteId': worksiteId,
    if (crewUserId != null) 'crewUserId': crewUserId,
    if (from != null) 'from': formatDateOnly(from),
    if (to != null) 'to': formatDateOnly(to),
    if (status != null) 'status': status,
  };
}
