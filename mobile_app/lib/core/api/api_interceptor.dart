import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    debugPrint(
      "➡️ ${options.method} ${options.baseUrl}${options.path}",
    );

    if (options.data != null) {
      debugPrint("Request Body: ${options.data}");
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint(
      "✅ ${response.statusCode} ${response.requestOptions.path}",
    );

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    debugPrint(
      "❌ ${err.response?.statusCode} ${err.requestOptions.path}",
    );

    if (err.response?.data != null) {
      debugPrint("Error Body: ${err.response?.data}");
    }

    handler.next(err);
  }
}