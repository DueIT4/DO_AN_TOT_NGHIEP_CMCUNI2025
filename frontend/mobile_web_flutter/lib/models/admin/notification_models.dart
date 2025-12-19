class NotificationItem {
  /// UI đang gọi: notificationId, title, description, username, email, createdAt, readAt
  final int notificationId;

  final String? title;
  final String? description;

  /// Người nhận (backend có thể trả)
  final String? username;
  final String? email;

  /// Trạng thái đã đọc
  final String? readAt; // giữ String để UI của bạn dùng _formatDate(String?)

  /// Người gửi (nếu có)
  final String? senderName;

  /// Thời gian tạo (UI có nơi dùng String? created_at, có nơi dùng DateTime)
  /// Ta lưu DateTime? + thêm getter createdAtIso để dùng được cả 2 kiểu
  final DateTime? createdAt;

  NotificationItem({
    required this.notificationId,
    this.title,
    this.description,
    this.username,
    this.email,
    this.readAt,
    this.senderName,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    DateTime? _toDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = '$v';
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    String? _toStr(dynamic v) {
      if (v == null) return null;
      final s = '$v';
      return s.isEmpty ? null : s;
    }

    return NotificationItem(
      // hỗ trợ cả id / notification_id
      notificationId: _toInt(json['notification_id'] ?? json['id']),

      title: _toStr(json['title']),
      description: _toStr(json['description']),

      // hỗ trợ username/email nếu backend trả
      username: _toStr(json['username']),
      email: _toStr(json['email']),

      // UI đang dùng read_at dạng String?
      readAt: _toStr(json['read_at']),

      // sender_name nếu có
      senderName: _toStr(json['sender_name']),

      createdAt: _toDate(json['created_at']),
    );
  }

  /// tiện nếu nơi nào cần string iso
  String? get createdAtIso => createdAt?.toIso8601String();
}
