import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/storage/secure_storage.dart';
import 'auth_model.dart';

class AuthService {
  AuthService._();

  static Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await ApiClient.dio.post(
        "/auth/login",
        data: request.toJson(),
      );

      final auth = AuthResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      await SecureStorage.saveAccessToken(auth.accessToken);
      await SecureStorage.saveRefreshToken(auth.refreshToken);

      return auth;
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: "Login failed.");
    }
  }

  static Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final response = await ApiClient.dio.post(
        "/auth/register",
        data: request.toJson(),
      );

      return RegisterResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: "Registration failed.");
    }
  }

  /// Loads the signed-in user's profile (`GET /users/me`).
  static Future<Map<String, dynamic>> me() async {
    try {
      final response = await ApiClient.dio.get("/users/me");
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: "Could not load your profile.");
    }
  }

  /// Updates profile fields (`PATCH /users/me`); returns the new profile.
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> changes,
  ) async {
    try {
      final response = await ApiClient.dio.patch("/users/me", data: changes);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: "Could not update your profile.");
    }
  }

  /// Exchanges the stored refresh token for a new access token.
  ///
  /// The backend's /auth/refresh only returns a new access token, so the
  /// existing refresh token is kept as-is.
  static Future<String> refreshToken() async {
    final refreshToken = await SecureStorage.getRefreshToken();

    if (refreshToken == null) {
      throw const ApiException("Refresh token not found.");
    }

    try {
      final response = await ApiClient.dio.post(
        "/auth/refresh",
        data: RefreshTokenRequest(refreshToken: refreshToken).toJson(),
      );

      final accessToken = (response.data as Map)["access_token"] as String;

      await SecureStorage.saveAccessToken(accessToken);

      return accessToken;
    } on DioException catch (e) {
      throw ApiException.fromDio(e, fallback: "Session expired.");
    }
  }

  static Future<void> logout() async {
    final refreshToken = await SecureStorage.getRefreshToken();

    if (refreshToken != null) {
      try {
        await ApiClient.dio.post(
          "/auth/logout",
          data: RefreshTokenRequest(refreshToken: refreshToken).toJson(),
        );
      } catch (_) {
        // Ignore backend logout errors; local tokens are cleared below.
      }
    }

    await SecureStorage.clearTokens();
  }
}
