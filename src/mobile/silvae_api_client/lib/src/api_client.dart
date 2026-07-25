import 'package:dio/dio.dart';
import 'package:silvae_api_client/src/models.dart';

final class SilvaeApiClient {
  const SilvaeApiClient(this._dio);

  final Dio _dio;

  Future<void> getCurrentUser() async {
    await _dio.get<void>('/api/me');
  }

  Future<List<WorksiteDto>> getAssignedWorksites() async {
    final response = await _dio.get<List<dynamic>>('/api/worksites');
    return response.data!
        .map((item) => WorksiteDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
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
}
