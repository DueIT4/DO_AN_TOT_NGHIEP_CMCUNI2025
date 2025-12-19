class AdminTicketItem {
  final int ticketId;
  final int userId;
  final String? username;
  final String title;
  final String status;
  final DateTime createdAt;

  AdminTicketItem({
    required this.ticketId,
    required this.userId,
    required this.username,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  factory AdminTicketItem.fromJson(Map<String, dynamic> json) {
    return AdminTicketItem(
      ticketId: json['ticket_id'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String?,
      title: json['title'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AdminTicketListResult {
  final int total;
  final List<AdminTicketItem> items;

  AdminTicketListResult({required this.total, required this.items});
}

class AdminSupportMessage {
  final int messageId;
  final int ticketId;
  final int? senderId;
  final String? senderName;
  final String message;
  final String? attachmentUrl;
  final DateTime createdAt;

  AdminSupportMessage({
    required this.messageId,
    required this.ticketId,
    this.senderId,
    this.senderName,
    required this.message,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory AdminSupportMessage.fromJson(Map<String, dynamic> json) {
    return AdminSupportMessage(
      messageId: json['message_id'] as int,
      ticketId: json['ticket_id'] as int,
      senderId: json['sender_id'] as int?,
      senderName: json['sender_name'] as String?,
      message: json['message'] as String,
      attachmentUrl: json['attachment_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AdminTicketDetail {
  final int ticketId;
  final int userId;
  final String? username;
  final String title;
  final String? description;
  final String status;
  final DateTime createdAt;
  final List<AdminSupportMessage> messages;

  AdminTicketDetail({
    required this.ticketId,
    required this.userId,
    required this.username,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.messages,
  });

  factory AdminTicketDetail.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List<dynamic>)
        .map((e) => AdminSupportMessage.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();

    return AdminTicketDetail(
      ticketId: json['ticket_id'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      messages: msgs,
    );
  }
}
