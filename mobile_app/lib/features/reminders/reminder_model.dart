import 'package:flutter/material.dart';

class Reminder {
  final String id;
  final String title;

  /// The user's local calendar date (no time part).
  final DateTime date;

  /// Optional time of day; reminders without one notify at
  /// [defaultNotifyTime].
  final TimeOfDay? time;
  bool isDone;

  Reminder({
    required this.id,
    required this.title,
    required this.date,
    this.time,
    this.isDone = false,
  });

  static const TimeOfDay defaultNotifyTime = TimeOfDay(hour: 9, minute: 0);

  /// When this reminder should go off, in local time.
  DateTime get dueAt {
    final at = time ?? defaultNotifyTime;
    return DateTime(date.year, date.month, date.day, at.hour, at.minute);
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['remind_date'] as String);
    final time = json['remind_time'] as String?;
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime(date.year, date.month, date.day),
      time: time == null ? null : parseTime(time),
      isDone: (json['is_done'] as bool?) ?? false,
    );
  }

  /// "17:00" or "17:00:00" -> 17:00.
  static TimeOfDay parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// 17:05 -> "17:05", as the API expects.
  static String formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  /// A calendar date as the API expects it: YYYY-MM-DD.
  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
