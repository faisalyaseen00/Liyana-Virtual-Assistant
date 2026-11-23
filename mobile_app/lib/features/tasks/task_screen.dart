import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/segmented_tabs.dart';
import '../../core/widgets/ui_kit.dart';
import 'add_task_sheet.dart';
import 'task_model.dart';
import 'task_provider.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TaskProvider _provider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _provider = context.read<TaskProvider>();
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
    if (message == null || !mounted || _provider.allTasks.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    _provider.clearError();
  }

  void _showAddTask() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddTaskSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final pending = provider.pendingTasks;
    final done = provider.completedTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        bottom: SegmentedTabs(
          controller: _tabController,
          labels: ['To do (${pending.length})', 'Done (${done.length})'],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(pending, provider, done: false),
          _buildList(done, provider, done: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New task'),
      ),
    );
  }

  Widget _buildList(
    List<Task> tasks,
    TaskProvider provider, {
    required bool done,
  }) {
    if (tasks.isEmpty && provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.allTasks.isEmpty && provider.errorMessage != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load your tasks',
        message: provider.errorMessage,
        actionLabel: 'Try again',
        onAction: provider.loadTasks,
        color: AppColors.danger,
        background: AppColors.dangerSoft,
      );
    }

    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.loadTasks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 440,
              child: done
                  ? const EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'No completed tasks yet',
                      message: 'Tasks you finish will show up here.',
                      color: AppColors.success,
                      background: AppColors.successSoft,
                    )
                  : EmptyState(
                      icon: Icons.checklist_rounded,
                      title: 'Nothing to do',
                      message:
                          'Add a task, or just tell Liyana: "add a task to…"',
                      actionLabel: 'Add a task',
                      onAction: _showAddTask,
                    ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadTasks,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _TaskCard(task: tasks[index], provider: provider),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.provider});

  final Task task;
  final TaskProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = priorityColors(task.priority);
    final overdue =
        !task.isCompleted &&
        task.deadline != null &&
        DateUtils.dateOnly(
          task.deadline!,
        ).isBefore(DateUtils.dateOnly(DateTime.now()));

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.deleteTask(task.id),
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
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              tooltip: task.isCompleted ? 'Mark as not done' : 'Mark as done',
              onPressed: () => provider.toggleComplete(task.id),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: task.isCompleted
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('done'),
                        color: AppColors.success,
                        size: 26,
                      )
                    : const Icon(
                        Icons.radio_button_unchecked_rounded,
                        key: ValueKey('todo'),
                        color: AppColors.textMuted,
                        size: 26,
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: task.isCompleted
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          label: task.priority,
                          icon: Icons.flag_rounded,
                          color: task.isCompleted
                              ? AppColors.textMuted
                              : colors.color,
                          background: task.isCompleted
                              ? AppColors.surfaceMuted
                              : colors.background,
                        ),
                        if (task.deadline != null)
                          StatusPill(
                            label: overdue
                                ? 'Overdue · ${friendlyDate(task.deadline!)}'
                                : friendlyDate(task.deadline!),
                            icon: Icons.event_rounded,
                            color: overdue
                                ? AppColors.danger
                                : AppColors.textSecondary,
                            background: overdue
                                ? AppColors.dangerSoft
                                : AppColors.surfaceMuted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Delete task',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppColors.textMuted,
              onPressed: () => provider.deleteTask(task.id),
            ),
          ],
        ),
      ),
    );
  }
}
