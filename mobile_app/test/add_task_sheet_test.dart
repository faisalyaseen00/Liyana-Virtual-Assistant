import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/tasks/add_task_sheet.dart';
import 'package:mobile_app/features/tasks/task_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('add task sheet opens and adds a task', (tester) async {
    final provider = TaskProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: AddTaskSheet()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('NEW TASK'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Submit assignment');
    await tester.tap(find.text('ADD TASK'));
    await tester.pump();

    expect(provider.pendingTasks.single.title, 'Submit assignment');
  });
}
