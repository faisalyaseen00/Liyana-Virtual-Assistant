import 'package:flutter/material.dart';

import '../../core/storage/secure_storage.dart';
import 'auth_model.dart';
import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;

  bool _isLoading = false;

  String? _errorMessage;

  AuthResponse? _authResponse;
  bool get isAuthenticated => _isAuthenticated;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  AuthResponse? get authResponse => _authResponse;
  Future<bool> login({
  required String email,
  required String password,
  }) async {

  _isLoading = true;
  _errorMessage = null;

  notifyListeners();

  try {

    final response = await AuthService.login(
      LoginRequest(
        email: email,
        password: password,
      ),
    );

    _authResponse = response;
    debugPrint("Access Token:");
    debugPrint(response.accessToken);

    final saved =
        await SecureStorage.getAccessToken();

    debugPrint("Stored Token:");
    debugPrint(saved);

    _isAuthenticated = true;

    return true;

  } catch (e) {

    _errorMessage = e.toString();

    _isAuthenticated = false;

    return false;

  } finally {

    _isLoading = false;

    notifyListeners();

  }

  }
  Future<bool> register({

    required String email,

    required String password,

    String? fullName,

  }) async {

    _isLoading = true;

    _errorMessage = null;

    notifyListeners();

    try {

      await AuthService.register(

        RegisterRequest(

          email: email,

          password: password,

          fullName: fullName,

        ),

      );

      return true;

    } catch (e) {

      _errorMessage = e.toString();

      return false;

    } finally {

      _isLoading = false;

      notifyListeners();

    }

  }
  Future<void> logout() async {

  _isLoading = true;

  notifyListeners();

  await AuthService.logout();

  _authResponse = null;

  _isAuthenticated = false;

  _errorMessage = null;

  _isLoading = false;

  notifyListeners();

  }
  Future<void> checkAuthentication() async {
    debugPrint("========== APP START ==========");

    final access = await SecureStorage.getAccessToken();
    final refresh = await SecureStorage.getRefreshToken();

    debugPrint("Access Token:");
    debugPrint(access);

    debugPrint("Refresh Token:");
    debugPrint(refresh);

    _isAuthenticated = access != null;

    debugPrint("Authenticated: $_isAuthenticated");
    debugPrint("===============================");

    notifyListeners();
}

  void clearError() {

  _errorMessage = null;

  notifyListeners();

  }
}





