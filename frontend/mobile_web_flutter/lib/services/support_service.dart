import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/api_base_app.dart';
import 'api_client.dart';

/// =========================
/// SupportService (Refactored – Detection-style)
/// =========================
/// - Dùng ApiBase.uri(...) thay vì parse string
/// - Multipart dùng http.Response.fromStream
/// - Chuẩn hoá lỗi bằng Exception (fail fast)
/// - Chuẩn hoá attachment_url (relative -> absolute)
/// =========================
class SupportService {
  SupportService._();

  // =========================
  // Helpers
  // =========================

  static Map<String, dynamic> _decodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Không đọc được dữ liệu phản hồi từ máy chủ.');
    }
  }

  static String? normalizeFileUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http')) return raw;
    return '${ApiBase.host}$raw';
  }

  // =========================
  // TICKETS
  // =========================

  static Future<List<dynamic>> fetchMyTickets() async {
    final uri = ApiBase.uri('/support/tickets/my_list');

    http.Response resp;
    try {
      resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ hỗ trợ.');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Lỗi lấy danh sách ticket (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    if (data is! List) {
      throw Exception('Dữ liệu ticket không hợp lệ.');
    }

    return data;
  }

  static Future<Map<String, dynamic>> createTicket({
    required String title,
    required String description,
  }) async {
    final uri = ApiBase.uri('/support/tickets/create_ticket');

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: ApiClient.authHeaders(),
            body: jsonEncode({
              'title': title,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ hỗ trợ.');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Tạo ticket thất bại (${resp.statusCode}): ${resp.body}');
    }

    return _decodeJson(resp.body);
  }

  static Future<Map<String, dynamic>> fetchTicketDetail(int ticketId) async {
    final uri = ApiBase.uri('/support/tickets/$ticketId/read_detail');

    http.Response resp;
    try {
      resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ hỗ trợ.');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Lỗi lấy chi tiết ticket (${resp.statusCode}): ${resp.body}');
    }

    return _decodeJson(resp.body);
  }

  // =========================
  // MESSAGES
  // =========================

  static Future<List<dynamic>> fetchMessages(int ticketId) async {
    final uri = ApiBase.uri('/support/messages/of/$ticketId/getlistall_message');

    http.Response resp;
    try {
      resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ hỗ trợ.');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Lỗi lấy tin nhắn (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    if (data is! List) {
      throw Exception('Dữ liệu tin nhắn không hợp lệ.');
    }

    // Chuẩn hoá attachment_url
    return data.map((m) {
      if (m is Map<String, dynamic>) {
        final raw = m['attachment_url']?.toString();
        m['attachment_url'] = normalizeFileUrl(raw);
      }
      return m;
    }).toList();
  }

  /// Gửi tin nhắn hỗ trợ (multipart)
  /// BE nhận field:
  /// - ticket_id (Form)
  /// - message   (Form)
  /// - file      (UploadFile)
  static Future<Map<String, dynamic>> createMessage({
    required int ticketId,
    required String message,
    XFile? file,
  }) async {
    final uri = ApiBase.uri('/support/messages/create_message');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(ApiClient.authHeaders(json: false))
      ..fields['ticket_id'] = ticketId.toString()
      ..fields['message'] = message;

    if (file != null) {
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', // ⚠️ BE nhận đúng field tên "file"
          bytes,
          filename: file.name.isNotEmpty ? file.name : 'attachment.jpg',
        ),
      );
    }

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Hết thời gian gửi tin nhắn hỗ trợ.');
    }

    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gửi tin nhắn thất bại (${response.statusCode}): ${response.body}');
    }

    final data = _decodeJson(response.body);

    // Chuẩn hoá attachment_url trả về (nếu có)
    final raw = data['attachment_url']?.toString();
    data['attachment_url'] = normalizeFileUrl(raw);

    return data;
  }
}
