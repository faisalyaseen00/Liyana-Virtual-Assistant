import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/liyana_logo.dart';
import '../../services/voice_service.dart';
import '../reminders/reminder_provider.dart';
import '../tasks/task_provider.dart';
import 'chat_bubble.dart';
import 'chat_provider.dart';
import 'conversations_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceService _voiceService = VoiceService();
  late final ChatProvider _chat;

  // What was shown last frame, to scroll down when it changes.
  String? _shownConversation;
  int _shownCount = 0;

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _voiceEnabled = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatProvider>();
    _chat.addListener(_onChatChanged);
    _initVoice();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initVoice() async {
    try {
      await _voiceService.init();
    } catch (_) {
      // Speech isn't available on every platform (e.g. Linux desktop) or
      // permission was denied; the mic button reports it when tapped.
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Scroll to the newest message when another conversation is opened or a
  /// message is added at the end (not when older ones are loaded on top).
  void _onChatChanged() {
    final id = _chat.conversationId;
    final count = _chat.messages.length;
    final switched = id != _shownConversation && !_chat.isLoadingMessages;
    final grew = count > _shownCount && !_chat.isLoadingOlder;

    if (switched || (grew && id == _shownConversation)) _scrollToBottom();

    if (!_chat.isLoadingMessages) _shownConversation = id;
    if (!_chat.isLoadingOlder) _shownCount = count;
  }

  Future<void> _sendMessage([String? voiceText]) async {
    final text = (voiceText ?? _controller.text).trim();
    if (text.isEmpty || _chat.isSending) return;

    _controller.clear();
    final reply = await _chat.sendMessage(text);
    if (!mounted) return;

    // The assistant changed tasks or reminders: refresh those tabs (and
    // reschedule reminder notifications).
    final tool = reply?.tool;
    if (tool == 'create_task') {
      context.read<TaskProvider>().loadTasks();
    }
    if (tool == 'create_reminder') {
      context.read<ReminderProvider>().loadReminders();
    }

    // Speak the reply (or the error) only if voice is enabled.
    final spoken = reply?.content ?? _chat.messages.lastOrNull?.content;
    if (_voiceEnabled && spoken != null) {
      setState(() => _isSpeaking = true);
      try {
        await _voiceService.speak(spoken);
      } catch (_) {
        _showSnack('Text-to-speech is not available on this device.');
      }
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _voiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    try {
      final started = await _voiceService.startListening((text) {
        if (!mounted) return;
        setState(() => _isListening = false);
        if (text.isNotEmpty) {
          _sendMessage(text);
        }
      });
      if (!started) {
        if (mounted) setState(() => _isListening = false);
        _showSnack(
          'Speech recognition is unavailable. Check microphone permission.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
      _showSnack('Speech recognition is not supported on this device.');
    }
  }

  Future<void> _toggleSpeaking() async {
    if (_isSpeaking) {
      await _voiceService.stopSpeaking();
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chat.removeListener(_onChatChanged);
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _openHistory() async {
    _chat.loadConversations();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ConversationsScreen()));
  }

  static const _suggestions = [
    (Icons.wb_sunny_outlined, 'Plan my day'),
    (Icons.add_task_rounded, 'Add a task to buy groceries'),
    (Icons.alarm_rounded, 'Remind me tomorrow at 9am to call mom'),
    (Icons.checklist_rounded, 'What are my tasks?'),
  ];

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messages;
    final hasConversation = chat.conversationId != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 16,
        shape: const Border(bottom: BorderSide(color: AppColors.outline)),
        title: Row(
          children: [
            const LiyanaMark(size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasConversation ? chat.title : 'Liyana',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    chat.isSending ? 'Typing…' : 'AI assistant · Online',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: chat.isSending
                          ? AppColors.primary
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _voiceEnabled
                ? 'Turn off spoken replies'
                : 'Speak replies',
            icon: Icon(
              _voiceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_outlined,
              color: _voiceEnabled ? AppColors.primary : AppColors.textMuted,
            ),
            onPressed: () => setState(() => _voiceEnabled = !_voiceEnabled),
          ),
          IconButton(
            tooltip: 'Chat history',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openHistory,
          ),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.edit_square),
            onPressed: chat.isSending ? null : chat.startNewConversation,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_isListening)
            _StatusBanner(
              icon: Icons.mic_rounded,
              text: 'Listening… speak now',
              color: AppColors.primary,
              background: AppColors.primarySoft,
              pulse: _pulseAnimation,
              actionLabel: 'Stop',
              onAction: _toggleListening,
            ),
          if (_isSpeaking)
            _StatusBanner(
              icon: Icons.volume_up_rounded,
              text: 'Liyana is speaking',
              color: AppColors.info,
              background: AppColors.infoSoft,
              pulse: _pulseAnimation,
              actionLabel: 'Stop',
              onAction: _toggleSpeaking,
            ),
          Expanded(
            child: chat.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? _buildWelcome(chat)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount:
                        messages.length +
                        (chat.hasOlder ? 1 : 0) +
                        (chat.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (chat.hasOlder) {
                        if (index == 0) return _buildLoadOlder(chat);
                        index -= 1;
                      }
                      if (index == messages.length) {
                        return TypingBubble(animation: _pulseController);
                      }
                      final msg = messages[index];
                      final previous = index > 0 ? messages[index - 1] : null;
                      return ChatBubble(
                        message: msg.content,
                        isUser: msg.isUser,
                        isError: msg.isError,
                        // Group consecutive assistant messages under one avatar.
                        showAvatar:
                            !msg.isUser &&
                            (previous == null || previous.isUser),
                      );
                    },
                  ),
          ),
          if (chat.errorMessage != null && messages.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                chat.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          _buildInputBar(chat),
        ],
      ),
    );
  }

  Widget _buildWelcome(ChatProvider chat) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        const Center(child: LiyanaMark(size: 64)),
        const SizedBox(height: 20),
        const Text(
          'How can I help you today?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ask a question, or tell me to add a task or set a reminder. '
          'You can also tap the mic and talk.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        for (final (icon, text) in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.outline),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: chat.isSending ? null : () => _sendMessage(text),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInputBar(ChatProvider chat) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton.filledTonal(
              tooltip: _isListening ? 'Stop listening' : 'Speak',
              style: IconButton.styleFrom(
                backgroundColor: _isListening
                    ? AppColors.primary
                    : AppColors.surfaceMuted,
                foregroundColor: _isListening
                    ? Colors.white
                    : AppColors.textSecondary,
                minimumSize: const Size(46, 46),
              ),
              onPressed: _toggleListening,
              icon: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Message Liyana…',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final canSend = value.text.trim().isNotEmpty && !chat.isSending;
                return IconButton.filled(
                  tooltip: 'Send',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.35,
                    ),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    minimumSize: const Size(46, 46),
                  ),
                  onPressed: canSend ? () => _sendMessage() : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadOlder(ChatProvider chat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: chat.isLoadingOlder
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: chat.loadOlder,
                icon: const Icon(Icons.expand_less_rounded),
                label: const Text('Load earlier messages'),
              ),
      ),
    );
  }
}

/// A thin banner under the app bar while listening or speaking.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    required this.pulse,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final Animation<double> pulse;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          ScaleTransition(
            scale: pulse,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: color),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
