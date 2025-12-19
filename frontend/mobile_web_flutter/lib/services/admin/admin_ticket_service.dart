import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/models/admin/admin_ticket_models.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

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
  static Future<String> uploadSupportAttachment({
  required Uint8List bytes,
  required String filename,
}) async {
  final uri = Uri.parse(
    '${ApiBase.baseURL}${ApiBase.api('/support/admin/uploads')}',
  );

  final token = ApiBase.bearer;
  final req = http.MultipartRequest('POST', uri);

  if (token != null && token.isNotEmpty) {
    req.headers['Authorization'] = 'Bearer $token';
  }

  req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

  final streamed = await req.send();
  final resp = await http.Response.fromStream(streamed);

  if (resp.statusCode ~/ 100 != 2) {
    throw Exception('Upload thất bại (${resp.statusCode}): ${resp.body}');
  }

  final map = jsonDecode(resp.body) as Map<String, dynamic>;
  final url = (map['attachment_url'] ?? '').toString();
  if (url.isEmpty) {
    throw Exception('Upload OK nhưng thiếu attachment_url: ${resp.body}');
  }
  return url;
}

}
