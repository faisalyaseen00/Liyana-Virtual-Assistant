import 'package:flutter/foundation.dart';

import '../features/reminders/reminder_model.dart';
import '../features/tasks/task_model.dart';

/// What a notification is about; picks its channel and voice clip.
enum NotificationKind { reminder, pendingTasks }

/// Goes up by one each time the user opens the app from one of Liyana's
/// notifications, so the home screen can greet them out loud.
final ValueNotifier<int> notificationOpens = ValueNotifier<int>(0);

/// One notification to schedule for a reminder.
class PlannedNotification {
  final int id;
  final String title;
  final String body;
  final DateTime at;
  final NotificationKind kind;

  const PlannedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.kind = NotificationKind.reminder,
  });
}

/// Schedules phone notifications for reminders. The provider only talks to
/// this interface, so tests can use a fake.
abstract class ReminderNotifier {
  /// Make the phone's scheduled notifications match [reminders]: cancel the
  /// old ones and schedule every open reminder that is still in the future.
  Future<void> sync(List<Reminder> reminders);

  /// Keep the "you have pending tasks" voice nudges in step with [tasks].
  Future<void> syncTasks(List<Task> tasks);

  /// Remove every scheduled notification (e.g. on logout).
  Future<void> cancelAll();
}

/// iOS keeps only 64 pending notifications; stay well below that.
const int maxScheduledNotifications = 50;

/// Decides which notifications to schedule: open reminders due after [now],
/// soonest first, at most [maxScheduledNotifications].
List<PlannedNotification> planNotifications(
  List<Reminder> reminders,
  DateTime now,
) {
  final upcoming =
      reminders.where((r) => !r.isDone && r.dueAt.isAfter(now)).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  return upcoming
      .take(maxScheduledNotifications)
      .map(
        (r) => PlannedNotification(
          id: notificationIdFor(r.id),
          title: 'Reminder',
          body: r.title,
          at: r.dueAt,
        ),
      )
      .toList();
}

/// A stable, positive 31-bit notification id for a reminder id.
/// (`String.hashCode` isn't guaranteed to be the same between app runs.)
int notificationIdFor(String reminderId) {
  var hash = 0x811c9dc5; // FNV-1a
  for (final unit in reminderId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Pending-task nudges: one each evening at this hour for the next few days.
const int nudgeHour = 19;
const int nudgeDays = 3;

/// Nudge ids sit below every reminder id range we'd realistically hit.
const int _nudgeIdBase = 1000;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Open tasks as seen on [day]: how many in total, overdue and due that day.
({int total, int overdue, int dueToday}) pendingCounts(
  List<Task> tasks,
  DateTime day,
) {
  final today = _day(day);
  var overdue = 0;
  var dueToday = 0;
  final open = tasks.where((t) => !t.isCompleted).toList();
  for (final task in open) {
    final deadline = task.deadline;
    if (deadline == null) continue;
    final due = _day(deadline);
    if (due.isBefore(today)) overdue++;
    if (due == today) dueToday++;
  }
  return (total: open.length, overdue: overdue, dueToday: dueToday);
}

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// Evening voice nudges while there are open tasks: tonight (if 7 PM is
/// still ahead) and the next evenings, each with that day's numbers.
List<PlannedNotification> planTaskNudges(List<Task> tasks, DateTime now) {
  final planned = <PlannedNotification>[];
  for (var i = 0; i < nudgeDays; i++) {
    final day = _day(now).add(Duration(days: i));
    final at = DateTime(day.year, day.month, day.day, nudgeHour);
    if (!at.isAfter(now)) continue;

    final counts = pendingCounts(tasks, day);
    if (counts.total == 0) continue;

    final details = [
      if (counts.dueToday > 0) '${counts.dueToday} due today',
      if (counts.overdue > 0) '${counts.overdue} overdue',
    ];
    planned.add(
      PlannedNotification(
        id: _nudgeIdBase + i,
        title: 'You have ${_plural(counts.total, 'pending task')}',
        body: [
          if (details.isNotEmpty) '${details.join(', ')}.',
          'Open Liyana to check them.',
        ].join(' '),
        at: at,
        kind: NotificationKind.pendingTasks,
      ),
    );
  }
  return planned;
}

/// What Liyana says when the user opens the app from a notification.
String pendingBriefing(
  List<Task> tasks,
  List<Reminder> reminders,
  DateTime now,
) {
  final counts = pendingCounts(tasks, now);
  final today = _day(now);
  final parts = <String>[];

  if (counts.total == 0) {
    parts.add("Welcome back! You're all caught up, no pending tasks.");
  } else {
    parts.add(
      'Welcome back! You have ${_plural(counts.total, 'pending task')}.',
    );
    final open = tasks.where((t) => !t.isCompleted && t.deadline != null);
    final overdue = open.where((t) => _day(t.deadline!).isBefore(today));
    final dueToday = open.where((t) => _day(t.deadline!) == today);
    if (overdue.isNotEmpty) {
      parts.add('Overdue: ${overdue.take(3).map((t) => t.title).join(', ')}.');
    }
    if (dueToday.isNotEmpty) {
      parts.add(
        'Due today: ${dueToday.take(3).map((t) => t.title).join(', ')}.',
      );
    }
  }

  final soon =
      reminders
          .where(
            (r) => !r.isDone && r.dueAt.isAfter(now) && _day(r.dueAt) == today,
          )
          .toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  if (soon.isNotEmpty) {
    final next = soon.first;
    final hour = next.dueAt.hour % 12 == 0 ? 12 : next.dueAt.hour % 12;
    final minute = next.dueAt.minute == 0
        ? ''
        : ':${next.dueAt.minute.toString().padLeft(2, '0')}';
    final meridiem = next.dueAt.hour < 12 ? 'AM' : 'PM';
    parts.add('Your next reminder is ${next.title} at $hour$minute $meridiem.');
  }

  return parts.join(' ');
}

/// Used on platforms without scheduled notifications (web, desktop).
class NoopReminderNotifier implements ReminderNotifier {
  @override
  Future<void> sync(List<Reminder> reminders) async {}

  @override
  Future<void> syncTasks(List<Task> tasks) async {}

  @override
  Future<void> cancelAll() async {}
}
