import 'package:flutter/material.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/tasks/task_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String chat = '/chat';
  static const String tasks = '/tasks';
  static const String dashboard = '/dashboard';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        dashboard: (_) => const DashboardScreen(),
        chat: (_) => const ChatScreen(),
        tasks: (_) => const TaskScreen(),
      };
}