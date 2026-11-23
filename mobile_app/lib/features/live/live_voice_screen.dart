import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/liyana_logo.dart';
import '../chat/chat_provider.dart';
import '../reminders/reminder_provider.dart';
import '../tasks/task_provider.dart';
import 'live_voice_client.dart';

/// A real-time voice call with Liyana: talk, interrupt, and she can create
/// tasks and reminders while you talk.
class LiveVoiceScreen extends StatefulWidget {
  const LiveVoiceScreen({super.key, this.client});

  /// For tests; a real client is created otherwise.
  final LiveVoiceClient? client;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LiveVoiceScreen(),
      ),
    );
  }

  @override
  State<LiveVoiceScreen> createState() => _LiveVoiceScreenState();
}

class _LiveVoiceScreenState extends State<LiveVoiceScreen>
    with SingleTickerProviderStateMixin {
  late final LiveVoiceClient _client;
  late final AnimationController _pulse;
  final ScrollController _captions = ScrollController();
  bool _typing = false;
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? LiveVoiceClient(onTool: _onTool);
    _client.addListener(_onChange);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _client.start());
  }

  /// Liyana changed something: refresh it so the tabs and phone
  /// notifications match straight away.
  void _onTool(String tool) {
    if (!mounted) return;
    if (tool == 'create_task' || tool == 'get_tasks') {
      context.read<TaskProvider>().loadTasks();
    }
    if (tool == 'create_task' ||
        tool == 'create_reminder' ||
        tool == 'list_reminders') {
      context.read<ReminderProvider>().loadReminders();
    }
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_captions.hasClients) {
        _captions.animateTo(
          _captions.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _hangUp() async {
    await _client.end();
    if (!mounted) return;
    // The call is in chat history; show it there next time chat opens.
    context.read<ChatProvider>().loadConversations();
    Navigator.of(context).maybePop();
  }

  void _sendTyped() {
    _client.sendText(_text.text);
    _text.clear();
    setState(() => _typing = false);
  }

  @override
  void dispose() {
    _client.removeListener(_onChange);
    if (widget.client == null) _client.dispose();
    _pulse.dispose();
    _captions.dispose();
    _text.dispose();
    super.dispose();
  }

  String get _statusText {
    switch (_client.status) {
      case LiveStatus.idle:
      case LiveStatus.connecting:
        return 'Connecting to Liyana…';
      case LiveStatus.listening:
        return _client.muted ? 'Microphone off' : 'Listening… go ahead';
      case LiveStatus.speaking:
        return 'Liyana is speaking';
      case LiveStatus.ended:
        return 'Call ended';
      case LiveStatus.failed:
        return _client.error ?? 'Something went wrong';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _client.status;
    final active =
        status == LiveStatus.listening || status == LiveStatus.speaking;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _client.end();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF14112B),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 30,
                      ),
                      onPressed: _hangUp,
                    ),
                    const Spacer(),
                    const _LiveBadge(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Orb(
                pulse: _pulse,
                speaking: status == LiveStatus.speaking,
                listening: status == LiveStatus.listening && !_client.muted,
              ),
              const SizedBox(height: 24),
              const Text(
                'Liyana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: status == LiveStatus.failed
                        ? const Color(0xFFFF8A8E)
                        : Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: _buildCaptions()),
              if (_typing) _buildTypeBar(),
              _buildControls(active, status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptions() {
    final lines = _client.lines;
    if (lines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Try: "Make a task to submit my report by Friday 5 pm" '
          'or "What do I have today?"',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
        ),
      );
    }
    return ListView.builder(
      controller: _captions,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: line.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                line.isUser ? 'You' : 'Liyana',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                line.text,
                textAlign: line.isUser ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  color: line.isUser ? Colors.white70 : Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTyped(),
              decoration: InputDecoration(
                hintText: 'Type to Liyana…',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: _sendTyped,
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(bool active, LiveStatus status) {
    final ended = status == LiveStatus.ended || status == LiveStatus.failed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            tooltip: 'Type instead',
            icon: Icons.keyboard_rounded,
            onPressed: active ? () => setState(() => _typing = !_typing) : null,
          ),
          if (ended)
            _RoundButton(
              tooltip: 'Call again',
              icon: Icons.call_rounded,
              size: 72,
              color: AppColors.success,
              onPressed: _client.start,
            )
          else
            _RoundButton(
              tooltip: 'End call',
              icon: Icons.call_end_rounded,
              size: 72,
              color: AppColors.danger,
              onPressed: _hangUp,
            ),
          _RoundButton(
            tooltip: _client.muted ? 'Unmute' : 'Mute',
            icon: _client.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: _client.muted ? Colors.white : null,
            iconColor: _client.muted ? const Color(0xFF14112B) : null,
            onPressed: active ? _client.toggleMute : null,
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFFFF5A5F)),
          SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.pulse,
    required this.speaking,
    required this.listening,
  });

  final Animation<double> pulse;
  final bool speaking;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final strength = speaking ? 1.0 : (listening ? 0.45 : 0.15);
        final grow = 1 + 0.12 * strength * pulse.value;
        return Transform.scale(
          scale: grow,
          child: Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(
                    alpha: 0.25 + 0.35 * strength * pulse.value,
                  ),
                  blurRadius: 40 + 30 * strength * pulse.value,
                  spreadRadius: 4 + 10 * strength * pulse.value,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Center(child: LiyanaMark(size: 84)),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.color,
    this.iconColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final base = color ?? Colors.white.withValues(alpha: 0.12);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: base.withValues(alpha: base.a * (enabled ? 1 : 0.4)),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: size * 0.45,
            ),
          ),
        ),
      ),
    );
  }
}
