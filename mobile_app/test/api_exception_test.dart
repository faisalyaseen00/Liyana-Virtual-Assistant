import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/api/api_exception.dart';

DioException _error({Object? data, DioExceptionType? type}) {
  final options = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: options,
    type: type ?? DioExceptionType.badResponse,
    response: data == null
        ? null
        : Response(requestOptions: options, data: data, statusCode: 400),
  );
}

void main() {
  test('uses the backend detail string', () {
    final error = ApiException.fromDio(
      _error(data: {'detail': 'Invalid email or password'}),
    );
    expect(error.message, 'Invalid email or password');
  });

  test('reads FastAPI validation errors', () {
    final error = ApiException.fromDio(
      _error(
        data: {
          'detail': [
            {
              'loc': ['body', 'password'],
              'msg': 'String should have at least 8 characters',
            },
          ],
        },
      ),
    );
    expect(error.message, 'password: String should have at least 8 characters');
  });

  test('explains when the server cannot be reached', () {
    final error = ApiException.fromDio(
      _error(type: DioExceptionType.connectionError),
    );
    expect(error.message, contains('Cannot reach the server'));
  });

  test('falls back when the body has no detail', () {
    final error = ApiException.fromDio(
      _error(data: 'Internal Server Error'),
      fallback: 'Login failed.',
    );
    expect(error.message, 'Login failed.');
  });
}
