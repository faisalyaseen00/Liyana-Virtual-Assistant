class Task {
  final String id;
  final String title;
  final String description;
  final String priority;
  final DateTime? deadline;
  bool isCompleted;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = 'Medium',
    this.deadline,
    this.isCompleted = false,
    required this.createdAt,
  });
}