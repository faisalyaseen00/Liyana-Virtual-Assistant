import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/auth_interceptor.dart';
import 'core/routes/app_routes.dart';
import 'features/alerts/alert_provider.dart';
import 'features/auth/auth_provider.dart';
import 'features/chat/chat_provider.dart';
import 'features/reminders/reminder_provider.dart';
import 'features/tasks/task_provider.dart';
import 'services/local_reminder_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.initialize();

  final authProvider = AuthProvider();
  final taskProvider = TaskProvider();
  final chatProvider = ChatProvider();
  final reminderProvider = ReminderProvider(
    notifier: LocalReminderNotifier.create(),
  );

  // When the server session ends (logout elsewhere, expiry), drop back to
  // the login screen instead of leaving the user on a broken screen.
  AuthInterceptor.onSessionExpired = () {
    if (!authProvider.isAuthenticated) return;
    authProvider.markSignedOut();
    taskProvider.clear();
    reminderProvider.clear();
    chatProvider.clear();
    SentinelApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: taskProvider),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider.value(value: reminderProvider),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
      ],
      child: const SentinelApp(),
    ),
  );
}
