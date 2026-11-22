import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import 'task_model.dart';

/// Talks to the backend's /tasks endpoints.
class TaskService {
  final Dio _client;

  TaskService({Dio? client}) : _client = client ?? ApiClient.dio;

  Future<List<Task>> fetchTasks() async {
    try {
      final response = await _client.get('/tasks');
      return (response.data as List)
          .map((item) => Task.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not load tasks.');
    }
  }

  Future<Task> createTask({
    required String title,
    String description = '',
    String priority = 'Medium',
    DateTime? deadline,
  }) async {
    try {
      final response = await _client.post(
        '/tasks',
        data: {
          'title': title,
          'description': description,
          'priority': priority.toLowerCase(),
          'due_date': deadline == null ? null : Task.formatDate(deadline),
        },
      );
      return Task.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not add the task.');
    }
  }

  Future<Task> setCompleted(String id, bool isCompleted) async {
    try {
      final response = await _client.patch(
        '/tasks/$id',
        data: {'is_completed': isCompleted},
      );
      return Task.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not update the task.');
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _client.delete('/tasks/$id');
    } on DioException catch (error) {
      throw ApiException.fromDio(error, fallback: 'Could not delete the task.');
    }
  }
}
