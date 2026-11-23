import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'alert_model.dart';

class AlertProvider extends ChangeNotifier {
  final List<Alert> _alerts = [];
  final _uuid = const Uuid();

  List<Alert> get allAlerts => _alerts;
  List<Alert> get unreadAlerts => _alerts.where((a) => !a.isRead).toList();
  int get unreadCount => unreadAlerts.length;

  void addAlert({
    required String title,
    required String description,
    required AlertType type,
    DateTime? scheduledAt,
  }) {
    _alerts.insert(
      0,
      Alert(
        id: _uuid.v4(),
        title: title,
        description: description,
        type: type,
        createdAt: DateTime.now(),
        scheduledAt: scheduledAt,
      ),
    );
    notifyListeners();
  }

  void markAsRead(String id) {
    final alert = _alerts.firstWhere((a) => a.id == id);
    alert.isRead = true;
    notifyListeners();
  }

  void markAllAsRead() {
    for (final alert in _alerts) {
      alert.isRead = true;
    }
    notifyListeners();
  }

  void deleteAlert(String id) {
    _alerts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // Simulate local alert generation for the frontend UI
  void simulateAgentAlert() {
    final samples = [
      {
        'title': 'Assignment Due Tomorrow',
        'description':
            'Data Structures assignment deadline is tomorrow at 11:59 PM on Google Classroom.',
        'type': AlertType.deadline,
      },
      {
        'title': 'Urgent: Quiz in 2 Hours',
        'description':
            'Your OOP quiz starts in 2 hours. Review chapter 5 and 6.',
        'type': AlertType.urgent,
      },
      {
        'title': 'New Announcement',
        'description':
            'Prof. Ahmed posted a new announcement in Software Engineering classroom.',
        'type': AlertType.reminder,
      },
      {
        'title': 'Lab Session Today',
        'description':
            'You have a lab session at 2:00 PM. Don\'t forget your lab manual.',
        'type': AlertType.meeting,
      },
    ];

    final sample = samples[_alerts.length % samples.length];
    addAlert(
      title: sample['title'] as String,
      description: sample['description'] as String,
      type: sample['type'] as AlertType,
    );
  }
}
