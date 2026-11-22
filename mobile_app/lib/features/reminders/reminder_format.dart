import 'package:flutter/material.dart';

import 'reminder_model.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Today", "Tomorrow", or e.g. "Fri, 27 Nov".
String formatReminderDate(DateTime date, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(date);
  final diff = day.difference(today).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';

  final text =
      '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';
  return day.year == today.year ? text : '$text ${day.year}';
}

/// "Today at 17:00" / "Tomorrow" etc., for list rows.
String formatReminderWhen(Reminder reminder, BuildContext context) {
  final date = formatReminderDate(reminder.date);
  if (reminder.time == null) return date;
  return '$date at ${reminder.time!.format(context)}';
}
