import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logs API traffic in debug builds. Auth requests carry passwords and
/// tokens, so their bodies are never printed.
class ApiInterceptor extends Interceptor {
  static bool _isSensitive(RequestOptions options) =>
      options.path.contains("/auth/");

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint("➡️ ${options.method} ${options.baseUrl}${options.path}");

      if (options.data != null && !_isSensitive(options)) {
        debugPrint("Request Body: ${options.data}");
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint("✅ ${response.statusCode} ${response.requestOptions.path}");
    }

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint("❌ ${err.response?.statusCode} ${err.requestOptions.path}");

      if (err.response?.data != null) {
        debugPrint("Error Body: ${err.response?.data}");
      }
    }

    handler.next(err);
  }
}
