import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../services/voice_service.dart';
import 'chat_bubble.dart';

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
  final List<Map<String, String>> _messages = [];

  bool _isLoading = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _voiceEnabled = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _voiceService.init();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _sendMessage([String? voiceText]) async
  {

    final text = voiceText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    final reply = _generateLocalReply(text);

    setState(() {
      _messages.add({'role': 'ai', 'content': reply});
      _isLoading = false;
    });

    _scrollToBottom();

    // Agent speaks the response
   // Agent speaks only if voice is enabled
    if (_voiceEnabled) 
    {
      setState(() => _isSpeaking = true);
      await _voiceService.speak(reply);
      setState(() => _isSpeaking = false);
    }
  }

  String _generateLocalReply(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return 'Hello. I am running in frontend-only mode now.';
    }

    if (lowerMessage.contains('task')) {
      return 'Tasks are managed locally in this app. Open the Tasks tab to continue.';
    }

    if (lowerMessage.contains('alert') || lowerMessage.contains('remind')) {
      return 'Alerts are displayed locally. Use the Alerts tab for updates.';
    }

    return 'Frontend-only mode is active.';
  }

  void _toggleListening() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _voiceService.startListening((text) {
        setState(() => _isListening = false);
        if (text.isNotEmpty) {
          _sendMessage(text);
        }
      });
    }
  }

  void _toggleSpeaking() async {
    if (_isSpeaking) {
      await _voiceService.stopSpeaking();
      setState(() => _isSpeaking = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
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
    _controller.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SENTINEL AI'),
        actions: [
  IconButton(
    icon: Icon(
      _voiceEnabled ? Icons.volume_up : Icons.volume_off,
      color: _voiceEnabled ? Color(0xFF00F5FF) : Colors.white24,
    ),
    onPressed: () => setState(() => _voiceEnabled = !_voiceEnabled),
  ),
  if (_isSpeaking)
    IconButton(
      icon: const Icon(Icons.stop_circle, color: Color(0xFFFF4444)),
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
              color: const Color(0xFF00F5FF).withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: const Icon(Icons.mic,
                        color: Color(0xFF00F5FF), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Listening...',
                    style: TextStyle(
                      color: Color(0xFF00F5FF),
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
              color: const Color(0xFF7B2FFF).withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: const Icon(Icons.volume_up,
                        color: Color(0xFF7B2FFF), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sentinel is speaking...',
                    style: TextStyle(
                      color: Color(0xFF7B2FFF),
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield,
                            size: 60, color: Color(0xFF00F5FF)),
                        const SizedBox(height: 16),
                        const Text(
                          'Sentinel AI Ready',
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
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return ChatBubble(
                        message: msg['content']!,
                        isUser: msg['role'] == 'user',
                      );
                    },
                  ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                color: Color(0xFF00F5FF),
                strokeWidth: 2,
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(AppConstants.padding),
            decoration: const BoxDecoration(
              color: Color(0xFF12121A),
              border: Border(
                top: BorderSide(color: Color(0xFF00F5FF), width: 0.5),
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
                          ? const Color(0xFF00F5FF)
                          : const Color(0xFF0A0A0F),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00F5FF),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening
                          ? Colors.black
                          : const Color(0xFF00F5FF),
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
                      hintText: 'Ask Sentinel...',
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.4)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0A0A0F),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                      color: Color(0xFF00F5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send,
                        color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}