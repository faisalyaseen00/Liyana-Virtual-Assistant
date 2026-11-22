import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
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
      backgroundColor: Colors.transparent,
      builder: (_) => const AddReminderSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REMINDERS'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'UPCOMING'),
            Tab(text: 'DONE'),
          ],
        ),
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(provider.upcomingReminders, provider, done: false),
              _buildList(provider.doneReminders, provider, done: true),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminder,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_alarm, color: AppColors.background),
      ),
    );
  }

  Widget _buildList(
    List<Reminder> reminders,
    ReminderProvider provider, {
    required bool done,
  }) {
    if (reminders.isEmpty && provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.allReminders.isEmpty && provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: provider.loadReminders,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (reminders.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadReminders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.alarm,
                      size: 60,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      done ? 'No finished reminders' : 'No upcoming reminders',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    if (!done) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Tap + or ask Liyana: "remind me to…"',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadReminders,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: reminders.length,
        itemBuilder: (context, index) => _buildCard(reminders[index], provider),
      ),
    );
  }

  Widget _buildCard(Reminder reminder, ReminderProvider provider) {
    final overdue = !reminder.isDone && reminder.dueAt.isBefore(DateTime.now());
    final accent = reminder.isDone
        ? AppColors.success
        : overdue
        ? AppColors.danger
        : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reminder.isDone
              ? AppColors.outline
              : accent.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: () => provider.toggleDone(reminder.id),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
              color: reminder.isDone
                  ? AppColors.success.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            child: reminder.isDone
                ? const Icon(Icons.check, size: 16, color: AppColors.success)
                : null,
          ),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            color: reminder.isDone ? Colors.white38 : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: reminder.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.alarm, size: 13, color: accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  overdue
                      ? 'Overdue · ${formatReminderWhen(reminder, context)}'
                      : formatReminderWhen(reminder, context),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: reminder.isDone ? Colors.white38 : accent,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white24),
          tooltip: 'Delete reminder',
          onPressed: () => provider.deleteReminder(reminder.id),
        ),
      ),
    );
  }
}
