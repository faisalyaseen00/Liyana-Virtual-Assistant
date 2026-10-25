class ChatMessage {
  final String id;
  final String conversationId;
  final String role;
  final String content;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
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
