import 'package:flutter/material.dart';

import '../../core/storage/secure_storage.dart';
import '../../core/utils/device_timezone.dart';
import 'auth_model.dart';
import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({Future<String?> Function()? timezoneLookup})
      : _timezoneLookup = timezoneLookup ?? deviceTimezone;

  final Future<String?> Function() _timezoneLookup;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  AuthResponse? _authResponse;
  String? _fullName;
  String? _email;
  String? _timezone;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthResponse? get authResponse => _authResponse;

  /// The user's time zone as saved on the server (IANA name).
  String? get timezone => _timezone;

  /// Name to greet the user with: full name, else the part of the email
  /// before the @, else nothing.
  String? get displayName {
    if (_fullName != null && _fullName!.trim().isNotEmpty) {
      return _fullName!.trim().split(' ').first;
    }
    if (_email != null) return _email!.split('@').first;
    return null;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _authResponse = await AuthService.login(
        LoginRequest(email: email, password: password),
      );
      _isAuthenticated = true;
      await loadProfile();
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

  /// Fetches the user's profile for the dashboard and keeps the saved time
  /// zone in step with the device, so the assistant's "today" and
  /// "tomorrow" match the user's clock. Failures are ignored: the app still
  /// works without it.
  Future<void> loadProfile() async {
    try {
      final profile = await AuthService.me();
      _applyProfile(profile);
      notifyListeners();
    } catch (_) {
      return;
    }

    await _syncTimezone();
  }

  void _applyProfile(Map<String, dynamic> profile) {
    _fullName = profile['full_name'] as String?;
    _email = profile['email'] as String?;
    _timezone = profile['timezone'] as String?;
  }

  Future<void> _syncTimezone() async {
    final device = await _timezoneLookup();
    if (device == null || device == _timezone) return;

    try {
      final profile = await AuthService.updateProfile({'timezone': device});
      _applyProfile(profile);
      notifyListeners();
    } catch (_) {
      // e.g. the server doesn't know this zone name; try again next start.
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await AuthService.logout();
    markSignedOut();
  }

  /// Clears local auth state, e.g. after the session expired on the server.
  void markSignedOut() {
    _authResponse = null;
    _isAuthenticated = false;
    _fullName = null;
    _email = null;
    _timezone = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkAuthentication() async {
    final access = await SecureStorage.getAccessToken();
    _isAuthenticated = access != null;
    notifyListeners();

    if (_isAuthenticated) {
      // Also confirms the session is still valid; an expired session
      // triggers the sign-out flow through the auth interceptor.
      await loadProfile();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
