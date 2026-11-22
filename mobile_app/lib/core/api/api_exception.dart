import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  /// Turns a Dio error into a message a user can act on: the backend's
  /// `detail` when there is one, otherwise a description of what went wrong.
  factory ApiException.fromDio(
    DioException error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return const ApiException(
          'Cannot reach the server. Check that the backend is running.',
        );
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(
          'The server took too long to respond. Please try again.',
        );
      default:
        break;
    }

    final detail = _detailFrom(error.response?.data);
    return ApiException(detail ?? fallback);
  }

  static String? _detailFrom(Object? data) {
    if (data is! Map) return null;
    final detail = data['detail'];

    if (detail is String && detail.isNotEmpty) return detail;

    // FastAPI validation errors: a list of {loc, msg, ...}.
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) {
        final field = first['loc'] is List && (first['loc'] as List).isNotEmpty
            ? '${(first['loc'] as List).last}: '
            : '';
        return '$field${first['msg']}';
      }
    }
    return null;
  }

  @override
  String toString() => message;
}
