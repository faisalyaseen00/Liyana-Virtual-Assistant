class AppConstants {
  AppConstants._();

  // =========================
  // API
  // =========================

  // Android Emulator
  static const String apiBaseUrl =
      "http://127.0.0.1:8000/api/v1";

  // Windows/Desktop
  // static const String apiBaseUrl =
  //     "http://127.0.0.1:8000/api/v1";

  // Physical Android
  // static const String apiBaseUrl =
  //     "http://192.168.1.10:8000/api/v1";

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