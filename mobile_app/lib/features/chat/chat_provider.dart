import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import 'chat_model.dart';
import 'chat_service.dart';
import 'conversation_model.dart';
import 'conversation_service.dart';

/// Chat state that outlives the chat screen: the open conversation, its
/// messages, and the list of past conversations.
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    ChatService? chatService,
    ConversationService? conversationService,
  }) : _chat = chatService ?? ChatService(),
       _history = conversationService ?? ConversationService();

  static const int pageSize = 50;

  final ChatService _chat;
  final ConversationService _history;

  List<Conversation> _conversations = [];
  String? _conversationId;
  List<ChatMessage> _messages = [];
  bool _hasOlder = false;
  bool _isLoadingMessages = false;
  bool _isLoadingOlder = false;
  bool _isLoadingConversations = false;
  bool _isSending = false;
  String? _errorMessage;

  List<Conversation> get conversations => List.unmodifiable(_conversations);

  /// The open conversation, or null for a new chat that hasn't been sent yet
  /// (it's created on the server with the first message).
  String? get conversationId => _conversationId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get hasOlder => _hasOlder;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingOlder => _isLoadingOlder;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  String get title {
    for (final c in _conversations) {
      if (c.id == _conversationId) return c.title;
    }
    return 'New chat';
  }

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();
    try {
      _conversations = await _history.listConversations();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// On app start: reopen the most recent conversation, if there is one.
  Future<void> openLatest() async {
    await loadConversations();
    if (_conversations.isNotEmpty) {
      await openConversation(_conversations.first.id);
    }
  }

  Future<void> openConversation(String id) async {
    _conversationId = id;
    _messages = [];
    _hasOlder = false;
    _isLoadingMessages = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _history.getMessages(id, limit: pageSize);
      if (_conversationId != id) return; // user switched meanwhile
      _messages = page;
      _hasOlder = page.length == pageSize;
    } catch (e) {
      if (_conversationId == id) _errorMessage = e.toString();
    } finally {
      if (_conversationId == id) {
        _isLoadingMessages = false;
        notifyListeners();
      }
    }
  }

  /// Load the page of messages before the oldest one shown.
  Future<void> loadOlder() async {
    final id = _conversationId;
    final oldest = _messages.where((m) => !m.isLocal).firstOrNull;
    if (id == null || oldest == null || !_hasOlder || _isLoadingOlder) return;

    _isLoadingOlder = true;
    notifyListeners();
    try {
      final page = await _history.getMessages(
        id,
        limit: pageSize,
        beforeId: oldest.id,
      );
      if (_conversationId != id) return;
      _messages = [...page, ..._messages];
      _hasOlder = page.length == pageSize;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingOlder = false;
      notifyListeners();
    }
  }

  /// Start a fresh chat. Nothing is created on the server until the first
  /// message, so empty chats don't pile up in the history.
  void startNewConversation() {
    _conversationId = null;
    _messages = [];
    _hasOlder = false;
    _isLoadingMessages = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Sends [text] and returns the assistant's reply, or null when sending
  /// failed (an error message is then shown in the chat).
  Future<ChatMessage?> sendMessage(String text) async {
    final content = text.trim();
    // Ignore empty input and sends while a reply is on its way, which would
    // otherwise send twice or create two conversations.
    if (content.isEmpty || _isSending) return null;

    final pending = ChatMessage.local(role: 'user', content: content);
    _messages = [..._messages, pending];
    _isSending = true;
    notifyListeners();

    final startedIn = _conversationId;
    try {
      final result = await _chat.sendMessage(
        content: content,
        conversationId: startedIn,
      );

      // Only update the screen if the user is still in this conversation.
      if (_conversationId == startedIn) {
        _conversationId = result.conversationId;
        _messages = [
          for (final m in _messages)
            if (!identical(m, pending)) m,
          result.response.userMessage,
          result.response.assistantMessage,
        ];
      }
      // New title / new order in the history list.
      loadConversations();
      return result.response.assistantMessage;
    } on ApiException catch (error) {
      _addError('Sorry, something went wrong: ${error.message}', startedIn);
      return null;
    } catch (_) {
      _addError('I could not reach Liyana right now.', startedIn);
      return null;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void _addError(String text, String? conversationId) {
    if (_conversationId != conversationId) return;
    _messages = [..._messages, ChatMessage.local(role: 'error', content: text)];
  }

  Future<bool> renameConversation(String id, String title) async {
    final name = title.trim();
    if (name.isEmpty) return false;
    try {
      final updated = await _history.rename(id, name);
      _conversations = [
        for (final c in _conversations) c.id == id ? updated : c,
      ];
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteConversation(String id) async {
    try {
      await _history.delete(id);
      _conversations = _conversations.where((c) => c.id != id).toList();
      if (_conversationId == id) startNewConversation();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Forget everything, e.g. on logout.
  void clear() {
    _conversations = [];
    _conversationId = null;
    _messages = [];
    _hasOlder = false;
    _isSending = false;
    _isLoadingMessages = false;
    _isLoadingOlder = false;
    _errorMessage = null;
    notifyListeners();
  }
}
