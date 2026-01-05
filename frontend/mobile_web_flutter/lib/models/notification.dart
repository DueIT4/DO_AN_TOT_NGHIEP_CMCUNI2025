class AppNotification {
  final int notificationId;
  final int userId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? readAt;

  AppNotification({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.description,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      notificationId: json['notification_id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      createdAt: _parseUtcDate(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? _parseUtcDate(json['read_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'user_id': userId,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }
}

DateTime _parseUtcDate(String dateStr) {
  if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
    return DateTime.parse('${dateStr}Z');
  }
  return DateTime.parse(dateStr);
}
