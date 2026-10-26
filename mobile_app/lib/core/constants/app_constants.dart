import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  // =========================
  // API
  // =========================

  // Override for a physical device, e.g.
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
  static const String _apiBaseUrlOverride =
      String.fromEnvironment("API_BASE_URL");

  /// Backend URL. The Android emulator reaches the host machine at
  /// 10.0.2.2; everything else (iOS simulator, desktop, web) uses 127.0.0.1.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8000/api/v1";
    }

    return "http://127.0.0.1:8000/api/v1";
  }

  static const Duration connectTimeout =
      Duration(seconds: 15);

  static const Duration receiveTimeout =
      Duration(seconds: 15);

  static const Duration sendTimeout =
      Duration(seconds: 15);

  // =========================
  // UI
  // =========================

  static const double padding = 20;

  static const double borderRadius = 12;
}