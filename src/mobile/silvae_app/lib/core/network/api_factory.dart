import 'package:dio/dio.dart';
import 'package:silvae_api_client/silvae_api_client.dart';

SilvaeApiClient createApiClient({
  required String baseUrl,
  required String Function() accessToken,
  required String organizationId,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'X-Organization-Id': organizationId},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = accessToken();
        if (token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );
  return SilvaeApiClient(dio);
}
