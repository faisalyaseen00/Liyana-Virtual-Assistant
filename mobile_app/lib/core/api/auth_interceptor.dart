import 'package:dio/dio.dart';

import '../../features/auth/auth_service.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken =
        await SecureStorage.getAccessToken();

    if (accessToken != null) {
      options.headers["Authorization"] =
          "Bearer $accessToken";
    }

    handler.next(options);
  }

  @override
void onError(
  DioException err,
  ErrorInterceptorHandler handler,
) async {

  // Ignore errors that are not authentication related.
  if (err.response?.statusCode != 401) {
    handler.next(err);
    return;
  }

  // Never refresh the refresh endpoint.
  if (err.requestOptions.path.contains("/auth/refresh")) {
    handler.next(err);
    return;
  }

  try {

    await AuthService.refreshToken();

    // Continue to retry the request in the next phase.

    handler.next(err);

  } catch (_) {

    await SecureStorage.clearTokens();

    handler.next(err);

  }
  }
}