import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import 'alert_model.dart';
import 'alert_provider.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final alerts = provider.allAlerts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: provider.markAllAsRead,
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: alerts.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: "You're all caught up",
              message:
                  'Alerts about deadlines, meetings and reminders will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: alerts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _AlertCard(alert: alerts[index], provider: provider),
            ),
      // Alerts are sample data until the backend sends real ones.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.simulateAgentAlert,
        icon: const Icon(Icons.bolt_rounded),
        label: const Text('Sample alert'),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.provider});

  final Alert alert;
  final AlertProvider provider;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(alert.type);

    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.deleteAlert(alert.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
        ),
      ),
      child: AppCard(
        onTap: () => provider.markAsRead(alert.id),
        color: alert.isRead ? AppColors.surface : const Color(0xFFFBFAFF),
        borderColor: alert.isRead
            ? AppColors.outline
            : AppColors.primary.withValues(alpha: 0.25),
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIcon(
              icon: style.icon,
              color: style.color,
              background: style.background,
              size: 42,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusPill(
                        label: style.label,
                        color: style.color,
                        background: style.background,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(alert.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: alert.isRead
                          ? FontWeight.w600
                          : FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.description,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textMuted,
              onPressed: () => provider.deleteAlert(alert.id),
            ),
          ],
        ),
      ),
    );
  }

  static ({IconData icon, String label, Color color, Color background})
  _styleFor(AlertType type) {
    switch (type) {
      case AlertType.urgent:
        return (
          icon: Icons.priority_high_rounded,
          label: 'Urgent',
          color: AppColors.danger,
          background: AppColors.dangerSoft,
        );
      case AlertType.deadline:
        return (
          icon: Icons.hourglass_bottom_rounded,
          label: 'Deadline',
          color: AppColors.warning,
          background: AppColors.warningSoft,
        );
      case AlertType.meeting:
        return (
          icon: Icons.groups_rounded,
          label: 'Meeting',
          color: AppColors.info,
          background: AppColors.infoSoft,
        );
      case AlertType.reminder:
        return (
          icon: Icons.notifications_active_rounded,
          label: 'Reminder',
          color: AppColors.primary,
          background: AppColors.primarySoft,
        );
    }
  }

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
