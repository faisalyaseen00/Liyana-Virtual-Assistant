import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'alert_model.dart';
import 'alert_provider.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALERTS'),
        actions: [
          TextButton(
            onPressed: () =>
                Provider.of<AlertProvider>(context, listen: false)
                    .markAllAsRead(),
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Color(0xFF00F5FF), fontSize: 12),
            ),
          ),
        ],
      ),
      body: Consumer<AlertProvider>(
        builder: (context, provider, _) {
          if (provider.allAlerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_off,
                      size: 60, color: Colors.white12),
                  const SizedBox(height: 16),
                  const Text(
                    'No alerts yet',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agent will notify you about\nGoogle Classroom & deadlines',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.allAlerts.length,
            itemBuilder: (context, index) {
              final alert = provider.allAlerts[index];
              return _buildAlertCard(context, alert, provider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Provider.of<AlertProvider>(context, listen: false)
                .simulateAgentAlert(),
        backgroundColor: const Color(0xFF00F5FF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.bolt),
        label: const Text(
          'Simulate Agent',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAlertCard(
      BuildContext context, Alert alert, AlertProvider provider) {
    final color = _alertColor(alert.type);
    final icon = _alertIcon(alert.type);
    final label = _alertLabel(alert.type);

    return GestureDetector(
      onTap: () => provider.markAsRead(alert.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alert.isRead
                ? Colors.white12
                : color.withOpacity(0.6),
            width: alert.isRead ? 1 : 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alert.title,
                      style: TextStyle(
                        color: alert.isRead
                            ? Colors.white54
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.description,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _timeAgo(alert.createdAt),
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 11),
                        ),
                        GestureDetector(
                          onTap: () => provider.deleteAlert(alert.id),
                          child: const Icon(Icons.close,
                              color: Colors.white24, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _alertColor(AlertType type) {
    switch (type) {
      case AlertType.urgent:
        return const Color(0xFFFF4444);
      case AlertType.deadline:
        return const Color(0xFFFFAA00);
      case AlertType.meeting:
        return const Color(0xFF00F5FF);
      case AlertType.reminder:
        return const Color(0xFF7B2FFF);
    }
  }

  IconData _alertIcon(AlertType type) {
    switch (type) {
      case AlertType.urgent:
        return Icons.warning_amber_rounded;
      case AlertType.deadline:
        return Icons.timer;
      case AlertType.meeting:
        return Icons.groups;
      case AlertType.reminder:
        return Icons.notifications_active;
    }
  }

  String _alertLabel(AlertType type) {
    switch (type) {
      case AlertType.urgent:
        return 'URGENT';
      case AlertType.deadline:
        return 'DEADLINE';
      case AlertType.meeting:
        return 'MEETING';
      case AlertType.reminder:
        return 'REMINDER';
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}