import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/tasks/task_provider.dart';
import 'package:mobile_app/features/tasks/task_service.dart';

import 'fake_task_backend.dart';

void main() {
  late FakeTaskBackend backend;
  late TaskProvider provider;

  setUp(() {
    backend = FakeTaskBackend();
    provider = TaskProvider(service: TaskService(client: backend.dio));
  });

  test(
    'loads tasks from the server, including ones the chat created',
    () async {
      backend.tasks.add({
        'id': 'from-chat',
        'title': 'Buy milk',
        'description': '',
        'priority': 'high',
        'due_date': '2026-11-30',
        'is_completed': false,
        'created_at': '2026-11-23T10:00:00Z',
      });

      await provider.loadTasks();

      final task = provider.pendingTasks.single;
      expect(task.title, 'Buy milk');
      expect(task.priority, 'High');
      expect(task.deadline, DateTime(2026, 11, 30));
    },
  );

  test('adds, completes and deletes through the API', () async {
    await provider.addTask(
      title: 'Write report',
      priority: 'Low',
      deadline: DateTime(2026, 12, 1),
    );
    expect(backend.tasks.single['priority'], 'low');
    expect(backend.tasks.single['due_date'], '2026-12-01');

    final id = provider.allTasks.single.id;

    await provider.toggleComplete(id);
    expect(provider.completedTasks.single.id, id);
    expect(backend.tasks.single['is_completed'], true);

    await provider.deleteTask(id);
    expect(provider.allTasks, isEmpty);
    expect(backend.tasks, isEmpty);
  });

  test('rolls back and reports an error when the server fails', () async {
    await provider.addTask(title: 'Keep me');
    final id = provider.allTasks.single.id;

    backend.failNext = true;
    await provider.deleteTask(id);

    expect(provider.allTasks.single.id, id);
    expect(provider.errorMessage, 'Server is unhappy');

    backend.failNext = true;
    await provider.toggleComplete(id);

    expect(provider.pendingTasks.single.id, id);
  });

  test('clear forgets the previous user\'s tasks', () async {
    await provider.addTask(title: 'Private');
    provider.clear();
    expect(provider.allTasks, isEmpty);
  });
}
