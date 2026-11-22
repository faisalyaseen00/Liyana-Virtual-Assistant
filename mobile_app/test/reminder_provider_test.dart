import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/reminders/reminder_provider.dart';
import 'package:mobile_app/features/reminders/reminder_service.dart';

import 'fake_reminder_backend.dart';

void main() {
  late FakeReminderBackend backend;
  late FakeNotifier notifier;
  late ReminderProvider provider;

  final nextYear = DateTime.now().year + 1;

  setUp(() {
    backend = FakeReminderBackend();
    notifier = FakeNotifier();
    provider = ReminderProvider(
      service: ReminderService(client: backend.dio),
      notifier: notifier,
    );
  });

  test(
    'loads reminders (including chat-created ones) and schedules them',
    () async {
      backend.reminders.add({
        'id': 'from-chat',
        'title': 'Call mom',
        'remind_date': '$nextYear-01-15',
        'remind_time': '17:00:00',
        'is_done': false,
      });

      await provider.loadReminders();

      final r = provider.upcomingReminders.single;
      expect(r.title, 'Call mom');
      expect(r.dueAt, DateTime(nextYear, 1, 15, 17, 0));
      expect(notifier.scheduledTitles, ['Call mom']);
    },
  );

  test('adding sends date and time and schedules a notification', () async {
    await provider.addReminder(
      title: 'Dentist',
      date: DateTime(nextYear, 3, 2),
      time: const TimeOfDay(hour: 8, minute: 5),
    );

    expect(backend.reminders.single['remind_date'], '$nextYear-03-02');
    expect(backend.reminders.single['remind_time'], '08:05:00');
    expect(notifier.scheduledTitles, ['Dentist']);
  });

  test('marking done or deleting removes the notification', () async {
    await provider.addReminder(title: 'A', date: DateTime(nextYear, 1, 1));
    await provider.addReminder(title: 'B', date: DateTime(nextYear, 1, 2));
    expect(notifier.scheduledTitles, ['A', 'B']);

    await provider.toggleDone(provider.upcomingReminders.first.id);
    expect(notifier.scheduledTitles, ['B']);
    expect(provider.doneReminders.single.title, 'A');

    await provider.deleteReminder(provider.upcomingReminders.single.id);
    expect(notifier.scheduledTitles, isEmpty);
    expect(backend.reminders.where((r) => r['title'] == 'B'), isEmpty);
  });

  test('a failed delete is rolled back and the notification kept', () async {
    await provider.addReminder(title: 'Keep', date: DateTime(nextYear, 1, 1));

    backend.failNext = true;
    await provider.deleteReminder(provider.allReminders.single.id);

    expect(provider.allReminders.single.title, 'Keep');
    expect(provider.errorMessage, 'Server is unhappy');
    expect(notifier.scheduledTitles, ['Keep']);
  });

  test('logout clears reminders and cancels notifications', () async {
    await provider.addReminder(
      title: 'Private',
      date: DateTime(nextYear, 1, 1),
    );

    await provider.clear();

    expect(provider.allReminders, isEmpty);
    expect(notifier.cancelled, isTrue);
  });
}
