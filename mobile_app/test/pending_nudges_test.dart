import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/reminders/reminder_model.dart';
import 'package:mobile_app/features/tasks/task_model.dart';
import 'package:mobile_app/services/reminder_notifier.dart';

Task task(String title, {DateTime? deadline, bool done = false}) => Task(
  id: title,
  title: title,
  deadline: deadline,
  isCompleted: done,
  createdAt: DateTime(2026, 11, 1),
);

void main() {
  // Tuesday 24 Nov 2026, 15:00.
  final now = DateTime(2026, 11, 24, 15);

  test('nudges each evening while tasks are pending', () {
    final tasks = [
      task('Essay', deadline: DateTime(2026, 11, 24)),
      task('Bill', deadline: DateTime(2026, 11, 22)),
      task('Groceries'),
      task('Done already', done: true),
    ];

    final nudges = planTaskNudges(tasks, now);

    expect(nudges.map((n) => n.at), [
      DateTime(2026, 11, 24, 19),
      DateTime(2026, 11, 25, 19),
      DateTime(2026, 11, 26, 19),
    ]);
    expect(nudges.first.title, 'You have 3 pending tasks');
    expect(
      nudges.first.body,
      '1 due today, 1 overdue. Open Liyana to check them.',
    );
    expect(nudges[1].body, '2 overdue. Open Liyana to check them.');
    expect(
      nudges.every((n) => n.kind == NotificationKind.pendingTasks),
      isTrue,
    );
  });

  test('no nudges when nothing is pending, none in the past', () {
    expect(planTaskNudges([task('x', done: true)], now), isEmpty);

    final late = DateTime(2026, 11, 24, 20);
    expect(
      planTaskNudges([task('x')], late).first.at,
      DateTime(2026, 11, 25, 19),
    );
  });

  test('briefing reads out overdue, due today and the next reminder', () {
    final text = pendingBriefing(
      [
        task('Essay', deadline: DateTime(2026, 11, 24)),
        task('Bill', deadline: DateTime(2026, 11, 22)),
      ],
      [
        Reminder.fromJson({
          'id': 'r1',
          'title': 'Call mom',
          'remind_date': '2026-11-24',
          'remind_time': '20:30:00',
          'is_done': false,
          'created_at': '2026-11-20T10:00:00Z',
        }),
      ],
      now,
    );

    expect(
      text,
      'Welcome back! You have 2 pending tasks. Overdue: Bill. '
      'Due today: Essay. Your next reminder is Call mom at 8:30 PM.',
    );
  });

  test('briefing when all caught up', () {
    expect(
      pendingBriefing([], [], now),
      "Welcome back! You're all caught up, no pending tasks.",
    );
  });
}
