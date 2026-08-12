import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'api_interceptor.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient._();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: {
        "Accept": "application/json",
      },
    ),
  );

  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;

    dio.interceptors.add(ApiInterceptor());
    dio.interceptors.add(AuthInterceptor(dio));

    _initialized = true;
  }
}