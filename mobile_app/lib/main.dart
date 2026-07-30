import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/api/api_client.dart';
import 'features/auth/auth_provider.dart';
import 'features/alerts/alert_provider.dart';
import 'features/tasks/task_provider.dart';

void main() {
  ApiClient.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
      ],
      child: const SentinelApp(),
    ),
  );
}