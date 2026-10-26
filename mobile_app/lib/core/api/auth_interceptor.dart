import 'package:dio/dio.dart';

import '../../features/auth/auth_service.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  static const String _retriedKey = "auth_retried";

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await SecureStorage.getAccessToken();

    if (accessToken != null) {
      options.headers["Authorization"] = "Bearer $accessToken";
    }

    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;

    // Only handle expired-token errors, never for the auth endpoints
    // themselves, and only retry a request once.
    if (err.response?.statusCode != 401 ||
        request.path.contains("/auth/") ||
        request.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }

    try {
      final accessToken = await AuthService.refreshToken();

      request.headers["Authorization"] = "Bearer $accessToken";
      request.extra[_retriedKey] = true;

      final response = await dio.fetch(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      // Refresh failed: the session is gone, so sign the user out.
      await SecureStorage.clearTokens();
      handler.next(err);
    }
  }
}
