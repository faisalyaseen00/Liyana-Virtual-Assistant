import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/api/api_client.dart';
import 'package:mobile_app/core/storage/secure_storage.dart';

/// Fake backend: /users/me only accepts the "new-access" token, and
/// /auth/refresh returns that token (with no refresh token, like the real API).
class FakeBackend implements HttpClientAdapter {
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');

    if (options.path == '/auth/refresh') {
      return _json('{"access_token":"new-access","token_type":"bearer"}', 200);
    }

    if (options.headers['Authorization'] == 'Bearer new-access') {
      return _json('{"email":"a@b.com"}', 200);
    }

    return _json('{"detail":"Invalid token."}', 401);
  }

  ResponseBody _json(String body, int status) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('expired access token is refreshed and the request retried', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'old-access',
      'refresh_token': 'refresh-1',
    });

    final backend = FakeBackend();
    ApiClient.initialize();
    ApiClient.dio.httpClientAdapter = backend;

    final response = await ApiClient.dio.get('/users/me');

    expect(response.statusCode, 200);
    expect(backend.calls, [
      'GET /users/me',
      'POST /auth/refresh',
      'GET /users/me',
    ]);
    expect(await SecureStorage.getAccessToken(), 'new-access');
    expect(await SecureStorage.getRefreshToken(), 'refresh-1');
  });
}
