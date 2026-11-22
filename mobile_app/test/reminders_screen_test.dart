import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/reminders/reminder_provider.dart';
import 'package:mobile_app/features/reminders/reminder_service.dart';
import 'package:mobile_app/features/reminders/reminders_screen.dart';
import 'package:provider/provider.dart';

import 'fake_reminder_backend.dart';

void main() {
  testWidgets('shows upcoming reminders and adds one from the sheet', (
    tester,
  ) async {
    final nextYear = DateTime.now().year + 1;
    final backend = FakeReminderBackend()
      ..reminders.add({
        'id': 'r1',
        'title': 'Call mom',
        'remind_date': '$nextYear-01-15',
        'remind_time': '17:00:00',
        'is_done': false,
      });
    final provider = ReminderProvider(
      service: ReminderService(client: backend.dio),
      notifier: FakeNotifier(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: RemindersScreen()),
      ),
    );
    // Start the load and let frames run; awaiting it directly would block
    // on the widget test's fake clock.
    provider.loadReminders();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Call mom'), findsOneWidget);
    expect(find.textContaining('15 Jan'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('NEW REMINDER'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Water plants');
    await tester.tap(find.text('ADD REMINDER'));
    await tester.pumpAndSettle();

    expect(find.text('NEW REMINDER'), findsNothing);
    expect(find.text('Water plants'), findsOneWidget);
    expect(backend.reminders.last['title'], 'Water plants');
  });
}
