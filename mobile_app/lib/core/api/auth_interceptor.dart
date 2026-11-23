import 'package:dio/dio.dart';

import '../../features/auth/auth_service.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  static const String _retriedKey = "auth_retried";

  /// Called when the session can no longer be refreshed (logged out or
  /// expired on the server). The app uses it to return to the login screen.
  static void Function()? onSessionExpired;

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
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;

    // Only handle expired-token errors, never for the auth endpoints
    // themselves, and only retry a request once.
    if (err.response?.statusCode != 401 ||
        request.path.contains("/auth/") ||
        request.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }

    final String accessToken;
    try {
      accessToken = await AuthService.refreshToken();
    } catch (_) {
      // Refresh failed: the session is gone, so sign the user out.
      await SecureStorage.clearTokens();
      onSessionExpired?.call();
      handler.next(err);
      return;
    }

    request.headers["Authorization"] = "Bearer $accessToken";
    request.extra[_retriedKey] = true;

    try {
      final response = await dio.fetch(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
