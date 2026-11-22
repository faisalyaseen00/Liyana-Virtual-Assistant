import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
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
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
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

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messages;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          chat.conversationId == null ? 'LIYANA' : chat.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Chat history',
            icon: const Icon(Icons.history),
            onPressed: _openHistory,
          ),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: chat.isSending ? null : chat.startNewConversation,
          ),
          IconButton(
            icon: Icon(
              _voiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: _voiceEnabled
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _voiceEnabled = !_voiceEnabled),
          ),
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop_circle, color: AppColors.danger),
              onPressed: _toggleSpeaking,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Listening indicator
          if (_isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: const Icon(
                      Icons.mic,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Listening...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

          // Speaking indicator
          if (_isSpeaking)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppColors.accent.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: const Icon(
                      Icons.volume_up,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Liyana is speaking...',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: chat.isLoadingMessages
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 60,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Liyana Ready',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Type or tap the mic to speak',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length + (chat.hasOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (chat.hasOlder) {
                        if (index == 0) return _buildLoadOlder(chat);
                        index -= 1;
                      }
                      final msg = messages[index];
                      return ChatBubble(
                        message: msg.content,
                        isUser: msg.isUser,
                        isError: msg.isError,
                      );
                    },
                  ),
          ),

          if (chat.errorMessage != null && messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                chat.errorMessage!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),

          if (chat.isSending)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(AppConstants.padding),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.outline, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Mic button
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppColors.primary
                          : AppColors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening
                          ? AppColors.background
                          : AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask Liyana...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: AppColors.background,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadOlder(ChatProvider chat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: chat.isLoadingOlder
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : TextButton.icon(
                onPressed: chat.loadOlder,
                icon: const Icon(Icons.expand_less),
                label: const Text('Load earlier messages'),
              ),
      ),
    );
  }
}
