import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/api/api_exception.dart';
import 'auth_model.dart';
class AuthService {
  AuthService._();
  static Future<AuthResponse> login(
  LoginRequest request,
) async {
  try {
    final response = await ApiClient.dio.post(
      "/auth/login",
      data: request.toJson(),
    );

    final auth = AuthResponse.fromJson(response.data);

    await SecureStorage.saveAccessToken(
      auth.accessToken,
    );

    await SecureStorage.saveRefreshToken(
      auth.refreshToken,
    );

    return auth;
  } on DioException catch (e) {
   throw const ApiException("Login failed.");
  }
}
static Future<RegisterResponse> register(
  RegisterRequest request,
) async {
  try {
    final response = await ApiClient.dio.post(
      "/auth/register",
      data: request.toJson(),
    );

    return RegisterResponse.fromJson(
      response.data,
    );
  } on DioException catch (e) {
    throw Exception(
      e.response?.data["detail"] ??
          "Registration failed.",
    );
  }
}
/// Exchanges the stored refresh token for a new access token.
///
/// The backend's /auth/refresh only returns a new access token, so the
/// existing refresh token is kept as-is.
static Future<String> refreshToken() async {
  final refreshToken =
      await SecureStorage.getRefreshToken();

  if (refreshToken == null) {
    throw Exception("Refresh token not found.");
  }

  try {
    final response = await ApiClient.dio.post(
      "/auth/refresh",
      data: RefreshTokenRequest(
        refreshToken: refreshToken,
      ).toJson(),
    );

    final accessToken =
        (response.data as Map)["access_token"] as String;

    await SecureStorage.saveAccessToken(accessToken);

    return accessToken;
  } on DioException catch (e) {
    final data = e.response?.data;
    throw Exception(
      (data is Map ? data["detail"] : null) ??
          "Session expired.",
    );
  }
}
static Future<void> logout() async {
  final refreshToken =
      await SecureStorage.getRefreshToken();

  if (refreshToken != null) {
    try {
      await ApiClient.dio.post(
        "/auth/logout",
        data: RefreshTokenRequest(
          refreshToken: refreshToken,
        ).toJson(),
      );
    } catch (_) {
      // Ignore backend logout errors
    }
  }

  await SecureStorage.clearTokens();
}
}