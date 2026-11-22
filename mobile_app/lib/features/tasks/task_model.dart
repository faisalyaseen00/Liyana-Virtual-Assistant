class Task {
  final String id;
  final String title;
  final String description;

  /// 'Low', 'Medium' or 'High' (the API uses lowercase).
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

  factory Task.fromJson(Map<String, dynamic> json) {
    final dueDate = json['due_date'] as String?;
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      priority: priorityLabel(json['priority'] as String?),
      deadline: dueDate == null ? null : DateTime.parse(dueDate),
      isCompleted: (json['is_completed'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  /// 'high' -> 'High'; anything unknown becomes 'Medium'.
  static String priorityLabel(String? value) {
    switch (value?.toLowerCase()) {
      case 'low':
        return 'Low';
      case 'high':
        return 'High';
      default:
        return 'Medium';
    }
  }

  /// A calendar date as the API expects it: YYYY-MM-DD.
  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
