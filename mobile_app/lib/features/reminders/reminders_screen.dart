import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/segmented_tabs.dart';
import '../../core/widgets/ui_kit.dart';
import 'add_reminder_sheet.dart';
import 'reminder_format.dart';
import 'reminder_model.dart';
import 'reminder_provider.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ReminderProvider _provider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _provider = context.read<ReminderProvider>();
    _provider.addListener(_showErrors);
  }

  @override
  void dispose() {
    _provider.removeListener(_showErrors);
    _tabController.dispose();
    super.dispose();
  }

  /// Shows server errors (e.g. a failed delete) as a snackbar while the list
  /// has content; an empty list shows them inline with a retry button.
  void _showErrors() {
    final message = _provider.errorMessage;
    if (message == null || !mounted || _provider.allReminders.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    _provider.clearError();
  }

  void _showAddReminder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddReminderSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReminderProvider>();
    final upcoming = provider.upcomingReminders;
    final done = provider.doneReminders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        bottom: SegmentedTabs(
          controller: _tabController,
          labels: ['Upcoming (${upcoming.length})', 'Done (${done.length})'],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(upcoming, provider, done: false),
          _buildList(done, provider, done: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReminder,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('New reminder'),
      ),
    );
  }

  Widget _buildList(
    List<Reminder> reminders,
    ReminderProvider provider, {
    required bool done,
  }) {
    if (reminders.isEmpty && provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.allReminders.isEmpty && provider.errorMessage != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load your reminders',
        message: provider.errorMessage,
        actionLabel: 'Try again',
        onAction: provider.loadReminders,
        color: AppColors.danger,
        background: AppColors.dangerSoft,
      );
    }

    if (reminders.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadReminders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 440,
              child: done
                  ? const EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'No finished reminders',
                      message: 'Reminders you mark as done will show here.',
                      color: AppColors.success,
                      background: AppColors.successSoft,
                    )
                  : EmptyState(
                      icon: Icons.alarm_rounded,
                      title: 'No upcoming reminders',
                      message:
                          'Tap the button below, or ask Liyana: "remind me to…"',
                      actionLabel: 'Add a reminder',
                      onAction: _showAddReminder,
                      color: AppColors.info,
                      background: AppColors.infoSoft,
                    ),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    if (done) {
      for (final reminder in reminders) {
        children.add(_ReminderCard(reminder: reminder, provider: provider));
      }
    } else {
      // Group upcoming reminders: Overdue, Today, Tomorrow, Later.
      String? currentGroup;
      for (final reminder in reminders) {
        final group = _groupFor(reminder);
        if (group != currentGroup) {
          currentGroup = group;
          children.add(_GroupHeader(group, overdue: group == 'Overdue'));
        }
        children.add(_ReminderCard(reminder: reminder, provider: provider));
      }
    }

    return RefreshIndicator(
      onRefresh: provider.loadReminders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: children,
      ),
    );
  }

  static String _groupFor(Reminder reminder) {
    if (reminder.dueAt.isBefore(DateTime.now())) return 'Overdue';
    final today = DateUtils.dateOnly(DateTime.now());
    final days = DateUtils.dateOnly(reminder.date).difference(today).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'Later';
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title, {this.overdue = false});

  final String title;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: overdue ? AppColors.danger : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, required this.provider});

  final Reminder reminder;
  final ReminderProvider provider;

  @override
  Widget build(BuildContext context) {
    final overdue = !reminder.isDone && reminder.dueAt.isBefore(DateTime.now());
    final (Color color, Color background) = reminder.isDone
        ? (AppColors.textMuted, AppColors.surfaceMuted)
        : overdue
        ? (AppColors.danger, AppColors.dangerSoft)
        : (AppColors.info, AppColors.infoSoft);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(reminder.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => provider.deleteReminder(reminder.id),
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
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              SoftIcon(
                icon: reminder.isDone
                    ? Icons.check_rounded
                    : Icons.alarm_rounded,
                color: color,
                background: background,
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: reminder.isDone
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: reminder.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatReminderWhen(reminder, context),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: overdue ? FontWeight.w600 : null,
                        color: overdue
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: reminder.isDone ? 'Mark as not done' : 'Mark as done',
                icon: Icon(
                  reminder.isDone
                      ? Icons.undo_rounded
                      : Icons.check_circle_outline_rounded,
                ),
                color: reminder.isDone
                    ? AppColors.textMuted
                    : AppColors.success,
                onPressed: () => provider.toggleDone(reminder.id),
              ),
              IconButton(
                tooltip: 'Delete reminder',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.textMuted,
                onPressed: () => provider.deleteReminder(reminder.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
