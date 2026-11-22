import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../alerts/alerts_screen.dart';
import '../alerts/alert_provider.dart';
import '../auth/auth_provider.dart';
import '../reminders/reminder_provider.dart';
import '../reminders/reminders_screen.dart';
import '../tasks/task_provider.dart';
import '../chat/chat_provider.dart';
import '../chat/chat_screen.dart';
import '../tasks/task_screen.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/liyana_logo.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

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

  void _setIndex(int index) {
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = [
    const _HomeTab(),
    const ChatScreen(),
    const TaskScreen(),
    const RemindersScreen(),
    const AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline, width: 0.5)),
        ),
        child: Consumer<AlertProvider>(
          builder: (context, alertProvider, _) {
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _setIndex,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.smart_toy),
                  label: 'AI Chat',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.task_alt),
                  label: 'Tasks',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.alarm),
                  label: 'Reminders',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      const Icon(Icons.notifications_active),
                      if (alertProvider.unreadCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Alerts',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildStatsRow(context),
            const SizedBox(height: 24),
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            _buildActionCards(context),
            const SizedBox(height: 24),
            const Text(
              'AI AGENT STATUS',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            _buildAgentStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final name = context.watch<AuthProvider>().displayName;
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              Text(
                name == null ? 'Welcome 👋' : '$name 👋',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: const SizedBox(
            width: 28,
            height: 28,
            child: LiyanaLogo(size: 28, showWordmark: false),
          ),
        ),
        IconButton(
          tooltip: 'Log out',
          icon: const Icon(Icons.logout, color: AppColors.textSecondary),
          onPressed: () => _confirmLogout(context),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
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
    if (!context.mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Widget _buildStatsRow(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, _) {
        return Row(
          children: [
            _buildStatCard(
              label: 'Pending',
              value: '${provider.pendingTasks.length}',
              icon: Icons.pending_actions,
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              label: 'Completed',
              value: '${provider.completedTasks.length}',
              icon: Icons.check_circle,
              color: AppColors.success,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              label: 'AI Agent',
              value: 'ON',
              icon: Icons.bolt,
              color: AppColors.primary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    final actions = [
      {
        'label': 'AI Chat',
        'icon': Icons.smart_toy,
        'color': const Color(0xFF00F5FF),
        'desc': 'Talk to Sentinel',
        'index': 1,
      },
      {
        'label': 'Tasks',
        'icon': Icons.task_alt,
        'color': const Color(0xFF7B2FFF),
        'desc': 'Manage your tasks',
        'index': 2,
      },
      {
        'label': 'Reminders',
        'icon': Icons.notifications_active,
        'color': const Color(0xFFFFAA00),
        'desc': 'Get notified on time',
        'index': 3,
      },
      {
        'label': 'Workflows',
        'icon': Icons.account_tree,
        'color': const Color(0xFF44FF88),
        'desc': 'Local automations',
        'index': 0,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final color = action['color'] as Color;
        return GestureDetector(
          onTap: () {
            final parent = context
                .findAncestorStateOfType<_DashboardScreenState>();
            parent?._setIndex(action['index'] as int);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(action['icon'] as IconData, color: color, size: 28),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      action['desc'] as String,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgentStatus() {
    final agents = [
      {
        'name': 'Gemini AI',
        'status': 'Ready',
        'color': const Color(0xFF44FF88),
      },
      {
        'name': 'Workflow Engine',
        'status': 'Connected',
        'color': const Color(0xFF44FF88),
      },
      {
        'name': 'Task Agent',
        'status': 'Active',
        'color': const Color(0xFF00F5FF),
      },
      {
        'name': 'RAG Engine',
        'status': 'Pending',
        'color': const Color(0xFFFFAA00),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00F5FF).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: agents.map((agent) {
          final color = agent['color'] as Color;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      agent['name'] as String,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  agent['status'] as String,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
