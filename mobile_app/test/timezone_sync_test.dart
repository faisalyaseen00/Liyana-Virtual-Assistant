import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/api/api_client.dart';
import 'package:mobile_app/features/auth/auth_provider.dart';

/// Fake /users/me that remembers the saved time zone.
class FakeProfileBackend implements HttpClientAdapter {
  String timezone = 'UTC';
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');

    if (options.method == 'PATCH') {
      timezone = (options.data as Map)['timezone'] as String;
    }

    return ResponseBody.fromString(
      jsonEncode({
        'email': 'ada@example.com',
        'full_name': 'Ada Lovelace',
        'timezone': timezone,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeProfileBackend backend;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    backend = FakeProfileBackend();
    ApiClient.initialize();
    ApiClient.dio.httpClientAdapter = backend;
  });

  test('saves the device time zone when the profile has another one', () async {
    final auth = AuthProvider(timezoneLookup: () async => 'Asia/Karachi');

    await auth.loadProfile();

    expect(backend.calls, ['GET /users/me', 'PATCH /users/me']);
    expect(backend.timezone, 'Asia/Karachi');
    expect(auth.timezone, 'Asia/Karachi');
    expect(auth.displayName, 'Ada');
  });

  test('does nothing when the time zone already matches', () async {
    backend.timezone = 'Asia/Karachi';
    final auth = AuthProvider(timezoneLookup: () async => 'Asia/Karachi');

    await auth.loadProfile();

    expect(backend.calls, ['GET /users/me']);
  });

  test('leaves the profile alone when the device zone is unknown', () async {
    final auth = AuthProvider(timezoneLookup: () async => null);

    await auth.loadProfile();

    expect(backend.calls, ['GET /users/me']);
    expect(auth.timezone, 'UTC');
  });
}
