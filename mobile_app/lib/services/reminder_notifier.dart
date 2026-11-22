import '../features/reminders/reminder_model.dart';

/// One notification to schedule for a reminder.
class PlannedNotification {
  final int id;
  final String title;
  final String body;
  final DateTime at;

  const PlannedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });
}

/// Schedules phone notifications for reminders. The provider only talks to
/// this interface, so tests can use a fake.
abstract class ReminderNotifier {
  /// Make the phone's scheduled notifications match [reminders]: cancel the
  /// old ones and schedule every open reminder that is still in the future.
  Future<void> sync(List<Reminder> reminders);

  /// Remove every scheduled reminder notification (e.g. on logout).
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

/// Used on platforms without scheduled notifications (web, desktop).
class NoopReminderNotifier implements ReminderNotifier {
  @override
  Future<void> sync(List<Reminder> reminders) async {}

  @override
  Future<void> cancelAll() async {}
}
