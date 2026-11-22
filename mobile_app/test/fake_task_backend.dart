import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// In-memory stand-in for the backend's /tasks endpoints.
class FakeTaskBackend implements HttpClientAdapter {
  final List<Map<String, dynamic>> tasks = [];
  final List<String> calls = [];
  bool failNext = false;
  int _nextId = 1;

  Dio get dio =>
      Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = this;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');

    if (failNext) {
      failNext = false;
      return _json({'detail': 'Server is unhappy'}, 500);
    }

    final segments = options.path.split('/')..removeWhere((s) => s.isEmpty);
    final id = segments.length > 1 ? segments[1] : null;

    switch (options.method) {
      case 'GET':
        return _json(tasks, 200);
      case 'POST':
        final body = Map<String, dynamic>.from(options.data as Map);
        final task = {
          'id': 'task-${_nextId++}',
          'title': body['title'],
          'description': body['description'] ?? '',
          'priority': body['priority'] ?? 'medium',
          'due_date': body['due_date'],
          'is_completed': false,
          'completed_at': null,
          'created_at': '2026-11-23T10:00:00Z',
          'updated_at': '2026-11-23T10:00:00Z',
        };
        tasks.add(task);
        return _json(task, 201);
      case 'PATCH':
        final task = tasks.firstWhere((t) => t['id'] == id);
        task.addAll(Map<String, dynamic>.from(options.data as Map));
        return _json(task, 200);
      case 'DELETE':
        tasks.removeWhere((t) => t['id'] == id);
        return ResponseBody.fromString('', 204);
    }
    return _json({'detail': 'Not found'}, 404);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
