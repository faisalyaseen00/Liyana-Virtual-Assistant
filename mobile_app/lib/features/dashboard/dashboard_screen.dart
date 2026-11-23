import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import '../alerts/alert_provider.dart';
import '../alerts/alerts_screen.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import '../chat/chat_screen.dart';
import '../reminders/add_reminder_sheet.dart';
import '../reminders/reminder_format.dart';
import '../reminders/reminder_model.dart';
import '../reminders/reminder_provider.dart';
import '../reminders/reminders_screen.dart';
import '../tasks/add_task_sheet.dart';
import '../tasks/task_model.dart';
import '../tasks/task_provider.dart';
import '../tasks/task_screen.dart';

/// Tab positions in the bottom navigation.
class AppTab {
  static const home = 0;
  static const chat = 1;
  static const tasks = 2;
  static const reminders = 3;
  static const alerts = 4;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = AppTab.home;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tasks, reminders and chats live on the server; fetch them once the
    // user is in, and reopen the most recent chat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
      context.read<ChatProvider>().openLatest();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the foreground: pick up anything changed meanwhile and
  /// reschedule reminder notifications.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    context.read<TaskProvider>().loadTasks();
    context.read<ReminderProvider>().loadReminders();
  }

  void _setIndex(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<AlertProvider>().unreadCount;

    Widget alertsIcon(IconData icon) => Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: Icon(icon),
    );

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(onOpenTab: _setIndex),
          const ChatScreen(),
          const TaskScreen(),
          const RemindersScreen(),
          const AlertsScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _setIndex,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            const NavigationDestination(
              icon: Icon(Icons.check_circle_outline_rounded),
              selectedIcon: Icon(Icons.check_circle_rounded),
              label: 'Tasks',
            ),
            const NavigationDestination(
              icon: Icon(Icons.alarm_outlined),
              selectedIcon: Icon(Icons.alarm_rounded),
              label: 'Reminders',
            ),
            NavigationDestination(
              icon: alertsIcon(Icons.notifications_none_rounded),
              selectedIcon: alertsIcon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final reminders = context.watch<ReminderProvider>();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([tasks.loadTasks(), reminders.loadReminders()]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const _Header(),
            const SizedBox(height: 20),
            _AskCard(onTap: () => onOpenTab(AppTab.chat)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: tasks.pendingTasks.length,
                    label: 'Open tasks',
                    icon: Icons.checklist_rounded,
                    color: AppColors.primary,
                    background: AppColors.primarySoft,
                    onTap: () => onOpenTab(AppTab.tasks),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    value: tasks.completedTasks.length,
                    label: 'Completed',
                    icon: Icons.task_alt_rounded,
                    color: AppColors.success,
                    background: AppColors.successSoft,
                    onTap: () => onOpenTab(AppTab.tasks),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    value: reminders.upcomingReminders.length,
                    label: 'Reminders',
                    icon: Icons.alarm_rounded,
                    color: AppColors.info,
                    background: AppColors.infoSoft,
                    onTap: () => onOpenTab(AppTab.reminders),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Quick actions'),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_task_rounded,
                    label: 'New task',
                    onTap: () => _openSheet(context, const AddTaskSheet()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_alarm_rounded,
                    label: 'New reminder',
                    onTap: () => _openSheet(context, const AddReminderSheet()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_comment_outlined,
                    label: 'New chat',
                    onTap: () {
                      context.read<ChatProvider>().startNewConversation();
                      onOpenTab(AppTab.chat);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Up next',
              actionLabel: 'See all',
              onAction: () => onOpenTab(AppTab.reminders),
            ),
            _UpNext(reminders: reminders.upcomingReminders.take(3).toList()),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Due soon',
              actionLabel: 'See all',
              onAction: () => onOpenTab(AppTab.tasks),
            ),
            _DueSoon(tasks: _soonestFirst(tasks.pendingTasks).take(3).toList()),
          ],
        ),
      ),
    );
  }

  /// Tasks with a deadline first (earliest first), then undated ones.
  static List<Task> _soonestFirst(List<Task> tasks) {
    final sorted = [...tasks];
    sorted.sort((a, b) {
      if (a.deadline == null && b.deadline == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      return a.deadline!.compareTo(b.deadline!);
    });
    return sorted;
  }
}

class _Header extends StatelessWidget {
  const _Header();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    context.read<TaskProvider>().clear();
    context.read<ReminderProvider>().clear();
    context.read<ChatProvider>().clear();

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().displayName;
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                name == null ? 'Welcome 👋' : 'Hi, $name 👋',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (value) {
            if (value == 'logout') _confirmLogout(context);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Log out'),
                ],
              ),
            ),
          ],
          child: InitialAvatar(name: name),
        ),
      ],
    );
  }
}

/// The violet "Ask Liyana anything" card that opens the chat.
class _AskCard extends StatelessWidget {
  const _AskCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Liyana assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ask Liyana anything',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Plan your day, add tasks or set reminders just by chatting.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Type a message…',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftIcon(icon: icon, color: color, background: background, size: 34),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpNext extends StatelessWidget {
  const _UpNext({required this.reminders});

  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return const _EmptyRow(
        icon: Icons.alarm_off_rounded,
        text: 'No upcoming reminders. Ask Liyana to remind you of something.',
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < reminders.length; i++) ...[
            if (i > 0) const Divider(indent: 70),
            _ReminderRow(reminder: reminders[i]),
          ],
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final overdue = reminder.dueAt.isBefore(DateTime.now());
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SoftIcon(
        icon: Icons.alarm_rounded,
        color: overdue ? AppColors.danger : AppColors.info,
        background: overdue ? AppColors.dangerSoft : AppColors.infoSoft,
        size: 38,
      ),
      title: Text(reminder.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        overdue
            ? 'Overdue · ${formatReminderWhen(reminder, context)}'
            : formatReminderWhen(reminder, context),
        style: TextStyle(
          color: overdue ? AppColors.danger : AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _DueSoon extends StatelessWidget {
  const _DueSoon({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _EmptyRow(
        icon: Icons.celebration_outlined,
        text: "You're all caught up. Nothing on your list right now.",
      );
    }
    final provider = context.read<TaskProvider>();
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < tasks.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            _TaskRow(
              task: tasks[i],
              onToggle: () => provider.toggleComplete(tasks[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onToggle});

  final Task task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = priorityColors(task.priority);
    final overdue =
        task.deadline != null &&
        DateUtils.dateOnly(
          task.deadline!,
        ).isBefore(DateUtils.dateOnly(DateTime.now()));

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(8, 2, 16, 2),
      leading: IconButton(
        tooltip: 'Mark as done',
        onPressed: onToggle,
        icon: const Icon(
          Icons.radio_button_unchecked_rounded,
          color: AppColors.textMuted,
        ),
      ),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            StatusPill(
              label: task.priority,
              color: colors.color,
              background: colors.background,
            ),
            if (task.deadline != null)
              StatusPill(
                label: overdue
                    ? 'Overdue · ${friendlyDate(task.deadline!)}'
                    : friendlyDate(task.deadline!),
                icon: Icons.event_rounded,
                color: overdue ? AppColors.danger : AppColors.textSecondary,
                background: overdue
                    ? AppColors.dangerSoft
                    : AppColors.surfaceMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          SoftIcon(
            icon: icon,
            color: AppColors.textMuted,
            background: AppColors.surfaceMuted,
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
