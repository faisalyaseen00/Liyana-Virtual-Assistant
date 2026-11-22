class ChatMessage {
  final String id;
  final String conversationId;
  final String role;
  final String content;

  /// Name of the tool the assistant ran for this reply (e.g. "create_task"),
  /// or null for a normal answer.
  final String? tool;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.tool,
  });

  /// A message shown only on this device: the user's text while it's being
  /// sent, or an error reply. It has no server id.
  factory ChatMessage.local({required String role, required String content}) {
    return ChatMessage(
      id: '',
      conversationId: '',
      role: role,
      content: content,
    );
  }

  bool get isLocal => id.isEmpty;
  bool get isUser => role == 'user';
  bool get isError => role == 'error';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      tool: json['extra_data'] is Map
          ? (json['extra_data'] as Map)['tool'] as String?
          : null,
    );
  }
}

class ChatResponse {
  final ChatMessage userMessage;
  final ChatMessage assistantMessage;

  const ChatResponse({
    required this.userMessage,
    required this.assistantMessage,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      userMessage: ChatMessage.fromJson(
        Map<String, dynamic>.from(json['user_message'] as Map),
      ),
      assistantMessage: ChatMessage.fromJson(
        Map<String, dynamic>.from(json['assistant_message'] as Map),
      ),
    );
  }
}

class ChatResult {
  final String conversationId;
  final ChatResponse response;

  const ChatResult({required this.conversationId, required this.response});
}
