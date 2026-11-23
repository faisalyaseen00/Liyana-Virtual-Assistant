import 'package:flutter/material.dart';

import '../../services/reminder_notifier.dart';
import 'task_model.dart';
import 'task_service.dart';

/// The signed-in user's tasks, stored on the backend.
///
/// Changes show in the UI straight away and are rolled back if the server
/// rejects them; [errorMessage] then says what went wrong.
class TaskProvider extends ChangeNotifier {
  TaskProvider({TaskService? service, ReminderNotifier? notifier})
    : _service = service ?? TaskService(),
      _notifier = notifier ?? NoopReminderNotifier();

  final TaskService _service;

  /// Keeps the evening "you have pending tasks" voice nudges up to date.
  final ReminderNotifier _notifier;
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Task> get allTasks => List.unmodifiable(_tasks);
  List<Task> get pendingTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _service.fetchTasks();
      _notifier.syncTasks(_tasks);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns true when the task was saved.
  Future<bool> addTask({
    required String title,
    String description = '',
    String priority = 'Medium',
    DateTime? deadline,
  }) async {
    try {
      final task = await _service.createTask(
        title: title,
        description: description,
        priority: priority,
        deadline: deadline,
      );
      _tasks = [..._tasks, task];
      _errorMessage = null;
      notifyListeners();
      _notifier.syncTasks(_tasks);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleComplete(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final task = _tasks[index];
    final newValue = !task.isCompleted;
    task.isCompleted = newValue;
    notifyListeners();

    try {
      final saved = await _service.setCompleted(id, newValue);
      final current = _tasks.indexWhere((t) => t.id == id);
      if (current != -1) _tasks[current] = saved;
      _errorMessage = null;
    } catch (e) {
      task.isCompleted = !newValue;
      _errorMessage = e.toString();
    }
    notifyListeners();
    _notifier.syncTasks(_tasks);
  }

  Future<void> deleteTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final removed = _tasks.removeAt(index);
    notifyListeners();

    try {
      await _service.deleteTask(id);
      _errorMessage = null;
    } catch (e) {
      _tasks.insert(index.clamp(0, _tasks.length), removed);
      _errorMessage = e.toString();
    }
    notifyListeners();
    _notifier.syncTasks(_tasks);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Forget everything, e.g. on logout, so the next user starts empty.
  void clear() {
    _tasks = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
    _notifier.syncTasks(_tasks);
  }
}
