import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mobile_app/features/reminders/reminder_model.dart';
import 'package:mobile_app/services/reminder_notifier.dart';

/// In-memory stand-in for the backend's /reminders endpoints.
class FakeReminderBackend implements HttpClientAdapter {
  final List<Map<String, dynamic>> reminders = [];
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
    if (failNext) {
      failNext = false;
      return _json({'detail': 'Server is unhappy'}, 500);
    }

    final segments = options.path.split('/')..removeWhere((s) => s.isEmpty);
    final id = segments.length > 1 ? segments[1] : null;

    switch (options.method) {
      case 'GET':
        return _json(reminders, 200);
      case 'POST':
        final body = Map<String, dynamic>.from(options.data as Map);
        final time = body['remind_time'] as String?;
        final reminder = {
          'id': 'reminder-${_nextId++}',
          'title': body['title'],
          'remind_date': body['remind_date'],
          'remind_time': time == null ? null : '$time:00',
          'is_done': false,
        };
        reminders.add(reminder);
        return _json(reminder, 201);
      case 'PATCH':
        final reminder = reminders.firstWhere((r) => r['id'] == id);
        reminder.addAll(Map<String, dynamic>.from(options.data as Map));
        return _json(reminder, 200);
      case 'DELETE':
        reminders.removeWhere((r) => r['id'] == id);
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

/// Records what the provider asked to be scheduled.
class FakeNotifier implements ReminderNotifier {
  List<String> scheduledTitles = [];
  int syncCount = 0;
  bool cancelled = false;

  @override
  Future<void> sync(List<Reminder> reminders) async {
    syncCount++;
    scheduledTitles = planNotifications(
      reminders,
      DateTime.now(),
    ).map((n) => n.body).toList();
  }

  @override
  Future<void> cancelAll() async {
    cancelled = true;
    scheduledTitles = [];
  }
}
