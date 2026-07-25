import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/tasks/task_provider.dart';
import 'features/alerts/alert_provider.dart';
import 'app.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
      ],
      child: const SentinelApp(),
    ),
  );
}