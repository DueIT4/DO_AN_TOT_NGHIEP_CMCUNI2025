// app/services/support_service.py
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart'; // ✅ Thêm để xử lý MediaType

import '../core/api_base_app.dart';
import 'api_client.dart';

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

  // ✅ CẬP NHẬT: Ưu tiên link Cloudinary tuyệt đối
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

    try {
      final resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Lỗi lấy danh sách ticket: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body);
      return data is List ? data : [];
    } catch (e) {
      throw Exception('Lỗi kết nối hỗ trợ: $e');
    }
  }

  static Future<Map<String, dynamic>> createTicket({
    required String title,
    required String description,
  }) async {
    final uri = ApiBase.uri('/support/tickets/create_ticket');

    final resp = await http
        .post(
          uri,
          headers: ApiClient.authHeaders(),
          body: jsonEncode({
            'title': title,
            'description': description,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Tạo ticket thất bại: ${resp.body}');
    }

    return _decodeJson(resp.body);
  }

  // =========================
  // MESSAGES
  // =========================

  static Future<List<dynamic>> fetchMessages(int ticketId) async {
    final uri = ApiBase.uri('/support/messages/of/$ticketId/getlistall_message');

    final resp = await http
        .get(uri, headers: ApiClient.authHeaders())
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Lỗi lấy tin nhắn: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body);
    if (data is! List) throw Exception('Dữ liệu không hợp lệ');

    // Chuẩn hoá attachment_url sang Cloudinary URL tuyệt đối
    return data.map((m) {
      if (m is Map<String, dynamic>) {
        m['attachment_url'] = normalizeFileUrl(m['attachment_url']?.toString());
      }
      return m;
    }).toList();
  }

  /// Gửi tin nhắn hỗ trợ kèm ảnh lên Cloudinary (qua Backend)
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
      
      // ✅ Xác định MediaType để Cloudinary xử lý đúng
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = (ext == 'png') ? 'image/png' : 'image/jpeg';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file', // Field name khớp với Backend
          bytes,
          filename: file.name,
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gửi tin nhắn thất bại: ${response.body}');
    }

    final data = _decodeJson(response.body);
    data['attachment_url'] = normalizeFileUrl(data['attachment_url']?.toString());

    return data;
  }
}