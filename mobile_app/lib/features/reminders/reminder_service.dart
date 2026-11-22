import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'reminder_model.dart';

/// Talks to the backend's /reminders endpoints.
class ReminderService {
  final Dio _client;

  ReminderService({Dio? client}) : _client = client ?? ApiClient.dio;

  Future<List<Reminder>> fetchReminders() async {
    try {
      final response = await _client.get('/reminders');
      return (response.data as List)
          .map(
            (item) => Reminder.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not load reminders.');
    }
  }

  Future<Reminder> createReminder({
    required String title,
    required DateTime date,
    TimeOfDay? time,
  }) async {
    try {
      final response = await _client.post(
        '/reminders',
        data: {
          'title': title,
          'remind_date': Reminder.formatDate(date),
          'remind_time': time == null ? null : Reminder.formatTime(time),
        },
      );
      return Reminder.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallback: 'Could not add the reminder.',
      );
    }
  }

  Future<Reminder> setDone(String id, bool isDone) async {
    try {
      final response = await _client.patch(
        '/reminders/$id',
        data: {'is_done': isDone},
      );
      return Reminder.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallback: 'Could not update the reminder.',
      );
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await _client.delete('/reminders/$id');
    } on DioException catch (error) {
      throw ApiException.fromDio(
        error,
        fallback: 'Could not delete the reminder.',
      );
    }
  }
}
