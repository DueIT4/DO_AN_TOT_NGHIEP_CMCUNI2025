// lib/core/admin_ticket_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_base.dart';

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
        .map((e) => AdminSupportMessage.fromJson(e as Map<String, dynamic>))
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

class AdminTicketService {
  /// GET /support/admin/tickets
  static Future<AdminTicketListResult> listTickets({
    String? status,
    String? search,
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'skip': '${(page - 1) * size}',
      'limit': '$size',
    };

    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    final query = Uri(queryParameters: params).query;

    final res = await ApiBase.getJson(
      ApiBase.api('/support/admin/tickets?$query'),
    );

    final map = Map<String, dynamic>.from(res as Map);
    final total = (map['total'] ?? 0) as int;
    final items = (map['items'] as List)
        .map((e) => AdminTicketItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();

    return AdminTicketListResult(total: total, items: items);
  }

  /// GET /support/admin/tickets/{ticket_id}
  static Future<AdminTicketDetail> getTicketDetail(int ticketId) async {
    final res = await ApiBase.getJson(
      ApiBase.api('/support/admin/tickets/$ticketId'),
    );
    return AdminTicketDetail.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// POST /support/admin/tickets/{ticket_id}/messages
  static Future<AdminSupportMessage> sendAdminMessage({
    required int ticketId,
    required String message,
    String? attachmentUrl,
  }) async {
    final body = <String, dynamic>{
      'message': message,
    };
    if (attachmentUrl != null) {
      body['attachment_url'] = attachmentUrl;
    }

    final res = await ApiBase.postJson(
      ApiBase.api('/support/admin/tickets/$ticketId/messages'),
      body,
    );

    return AdminSupportMessage.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// PATCH /support/admin/tickets/{ticket_id}/status
  /// KHÔNG dùng ApiBase.patchJson, dùng http.patch trực tiếp
  static Future<AdminTicketDetail> updateTicketStatus({
    required int ticketId,
    required String status, // 'processing' | 'processed'
  }) async {
    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/support/admin/tickets/$ticketId/status')}',
    );

    final token = ApiBase.bearer;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await http.patch(
      uri,
      headers: headers,
      body: jsonEncode({'status': status}),
    );

    if (resp.statusCode ~/ 100 != 2) {
      throw Exception(
        'Cập nhật trạng thái thất bại (${resp.statusCode}): ${resp.body}',
      );
    }

    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    return AdminTicketDetail.fromJson(map);
  }
}
