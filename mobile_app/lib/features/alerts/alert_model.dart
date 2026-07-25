enum AlertType { urgent, deadline, meeting, reminder }

class Alert {
  final String id;
  final String title;
  final String description;
  final AlertType type;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  bool isRead;

  Alert({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    this.scheduledAt,
    this.isRead = false,
  });
}