class Conversation {
  final String id;
  final String title;
  final DateTime lastMessageAt;

  const Conversation({
    required this.id,
    required this.title,
    required this.lastMessageAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      lastMessageAt: DateTime.parse(
        json['last_message_at'] as String,
      ).toLocal(),
    );
  }

  Conversation copyWith({String? title}) => Conversation(
    id: id,
    title: title ?? this.title,
    lastMessageAt: lastMessageAt,
  );
}
