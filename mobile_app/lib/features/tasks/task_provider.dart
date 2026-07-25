import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'task_model.dart';

class TaskProvider extends ChangeNotifier {
  final List<Task> _tasks = [];
  final _uuid = const Uuid();

  List<Task> get allTasks => _tasks;
  List<Task> get pendingTasks => _tasks.where((t) => !t.isCompleted).toList();
  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted).toList();

  void addTask({
    required String title,
    String description = '',
    String priority = 'Medium',
    DateTime? deadline,
  }) {
    _tasks.add(Task(
      id: _uuid.v4(),
      title: title,
      description: description,
      priority: priority,
      deadline: deadline,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void toggleComplete(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    task.isCompleted = !task.isCompleted;
    notifyListeners();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}