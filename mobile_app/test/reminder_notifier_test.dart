import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/reminders/reminder_model.dart';
import 'package:mobile_app/services/reminder_notifier.dart';

Reminder reminder(
  String id,
  DateTime date, {
  TimeOfDay? time,
  bool done = false,
}) =>
    Reminder(id: id, title: 'Title $id', date: date, time: time, isDone: done);

void main() {
  final now = DateTime(2026, 11, 23, 12, 0);

  test('schedules only open future reminders, soonest first', () {
    final planned = planNotifications([
      reminder(
        'later',
        DateTime(2026, 11, 25),
        time: const TimeOfDay(hour: 8, minute: 0),
      ),
      reminder(
        'past',
        DateTime(2026, 11, 23),
        time: const TimeOfDay(hour: 11, minute: 0),
      ),
      reminder('done', DateTime(2026, 11, 24), done: true),
      reminder(
        'soon',
        DateTime(2026, 11, 23),
        time: const TimeOfDay(hour: 17, minute: 30),
      ),
    ], now);

    expect(planned.map((n) => n.body), ['Title soon', 'Title later']);
    expect(planned.first.at, DateTime(2026, 11, 23, 17, 30));
  });

  test('reminders without a time go off at 9:00', () {
    final planned = planNotifications([
      reminder('x', DateTime(2026, 11, 24)),
    ], now);
    expect(planned.single.at, DateTime(2026, 11, 24, 9, 0));
  });

  test('a time-less reminder for today is skipped once 9:00 has passed', () {
    final planned = planNotifications([
      reminder('x', DateTime(2026, 11, 23)),
    ], now);
    expect(planned, isEmpty);
  });

  test('never schedules more than the iOS-safe limit', () {
    final many = List.generate(
      80,
      (i) => reminder('r$i', DateTime(2026, 12, 1).add(Duration(days: i))),
    );
    final planned = planNotifications(many, now);
    expect(planned, hasLength(maxScheduledNotifications));
    expect(planned.first.body, 'Title r0');
  });

  test('notification ids are stable, positive and differ per reminder', () {
    const id = '3f2a8c1e-0000-4000-8000-000000000001';
    expect(notificationIdFor(id), notificationIdFor(id));
    expect(notificationIdFor(id), greaterThanOrEqualTo(0));
    expect(notificationIdFor(id), lessThan(1 << 31));
    expect(notificationIdFor(id), isNot(notificationIdFor('${id}2')));
  });
}
