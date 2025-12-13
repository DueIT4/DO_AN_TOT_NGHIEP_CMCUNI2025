import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_base.dart';
import 'api_client.dart';

class SupportService {
  SupportService._();

  static Map<String, dynamic>? _safeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<(bool, List<dynamic>, String)> fetchMyTickets() async {
    final uri = Uri.parse(ApiBase.api('/support/tickets/my_list'));
    try {
      final resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        if (data is List) return (true, data, '');
        return (false, [], 'Dữ liệu không hợp lệ');
      }
      final d = _safeJson(resp.body);
      return (
        false,
        [],
        (d?['detail'] ?? d?['message'] ?? 'Lỗi lấy danh sách hỗ trợ').toString()
      );
    } catch (e) {
      return (false, [], 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, dynamic, String)> createTicket(
      String title, String description) async {
    final uri = Uri.parse(ApiBase.api('/support/tickets/create_ticket'));
    try {
      final resp = await http
          .post(uri,
              headers: ApiClient.authHeaders(),
              body: jsonEncode({'title': title, 'description': description}))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return (true, data, '');
      }
      final d = _safeJson(resp.body);
      return (
        false,
        null,
        (d?['detail'] ?? d?['message'] ?? 'Lỗi tạo ticket').toString()
      );
    } catch (e) {
      return (false, null, 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, dynamic, String)> fetchTicketDetail(int ticketId) async {
    final uri =
        Uri.parse(ApiBase.api('/support/tickets/$ticketId/read_detail'));
    try {
      final resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return (true, data, '');
      }
      final d = _safeJson(resp.body);
      return (
        false,
        null,
        (d?['detail'] ?? d?['message'] ?? 'Lỗi lấy chi tiết').toString()
      );
    } catch (e) {
      return (false, null, 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, List<dynamic>, String)> fetchMessages(
      int ticketId) async {
    final uri = Uri.parse(
        ApiBase.api('/support/messages/of/$ticketId/getlistall_message'));
    try {
      final resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        if (data is List) return (true, data, '');
        return (false, [], 'Dữ liệu không hợp lệ');
      }
      final d = _safeJson(resp.body);
      return (
        false,
        [],
        (d?['detail'] ?? d?['message'] ?? 'Lỗi lấy tin nhắn').toString()
      );
    } catch (e) {
      return (false, [], 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, dynamic, String)> createMessage(
      int ticketId, String message,
      {dynamic file}) async {
    final uri = Uri.parse(ApiBase.api('/support/messages/create_message'));
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(ApiClient.authHeaders(json: false));
      request.fields['ticket_id'] = ticketId.toString();
      request.fields['message'] = message;
      if (file != null) {
        final bytes = await file.readAsBytes();
        final filename = file.name;
        request.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename));
      }
      final resp = await request.send().timeout(const Duration(seconds: 30));
      final body = await resp.stream.bytesToString();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(body);
        return (true, data, '');
      }
      final d = _safeJson(body);
      return (
        false,
        null,
        (d?['detail'] ?? d?['message'] ?? 'Lỗi gửi tin nhắn').toString()
      );
    } catch (e) {
      return (false, null, 'Lỗi kết nối: $e');
    }
  }
}
