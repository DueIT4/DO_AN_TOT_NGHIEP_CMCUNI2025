// lib/services/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api_base.dart'; // baseUrl = http://10.2.11.228:8000

class ApiClient {
  static String? authToken;

  static void setAuthToken(String? token) {
    authToken = token;
  }

  static void clearAuth() {
    authToken = null;
  }

  static Map<String, String> authHeaders({
    bool json = true,
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${authToken!}';
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  // =========================
  // ĐĂNG KÝ (FE đang truyền identity)
  // identity ở đây CHỈ chấp nhận SĐT để khớp backend /register/phone
  // =========================
  static Future<(bool, String)> register({
    required String name,
    required String identity, // FE đang dùng tên này
    required String password,
  }) async {
    final phone = identity.trim();
    if (phone.isEmpty || !RegExp(r'^\d{6,}$').hasMatch(phone)) {
      return (false, 'Vui lòng nhập SĐT hợp lệ để đăng ký');
    }

    final uri = Uri.parse(ApiBase.api('/auth/register/phone'));
    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': name.trim(),
              'phone': phone,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        final msg = (data?['message'] ?? 'Đăng ký thành công').toString();
        return (true, msg);
      } else {
        final data = _safeJson(resp.body);
        final err = (data?['detail'] ?? data?['message'] ?? 'Đăng ký thất bại (${resp.statusCode})').toString();
        return (false, err);
      }
    } on TimeoutException {
      return (false, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // ĐĂNG NHẬP (FE đang truyền identity)
  // identity ở đây dùng như SĐT để khớp backend /login/phone
  // =========================
  static Future<(bool, String)> login({
    required String identity, // phone
    required String password,
  }) async {
    final phone = identity.trim();
    final uri = Uri.parse(ApiBase.api('/auth/login/phone'));
    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        final token = (data?['access_token'] ?? data?['token'] ?? '').toString();
        if (token.isEmpty) return (false, 'Đăng nhập thành công nhưng không nhận token');
        setAuthToken(token);
        return (true, token);
      } else {
        final data = _safeJson(resp.body);
        final err = (data?['detail'] ?? data?['message'] ?? 'Đăng nhập thất bại (${resp.statusCode})').toString();
        return (false, err);
      }
    } on TimeoutException {
      return (false, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // GOOGLE LOGIN (id_token)
  static Future<(bool, String)> loginWithGoogle(String idToken) async {
    try {
      final res = await http.post(
        Uri.parse(ApiBase.api('/auth/login/google')),
        headers: {'Content-Type': 'application/json'},
        // ⚠️ BACKEND ĐANG ĐÒI "token" => gửi đúng key này
        body: jsonEncode({'token': idToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = (data['access_token'] ?? data['token'] ?? '').toString();
        setAuthToken(token);
        return (true, token);
      }
      return (false, res.body);
    } catch (e) {
      return (false, 'Network error: $e');
    }
  }


  // =========================
  // FACEBOOK LOGIN (access_token)
  // =========================
  static Future<(bool, String)> loginWithFacebook(String accessToken) async {
    final uri = Uri.parse(ApiBase.api('/auth/login/facebook'));
    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': accessToken}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        final token = (data?['access_token'] ?? data?['token'] ?? '').toString();
        if (token.isEmpty) return (false, 'Facebook login OK nhưng không có token');
        setAuthToken(token);
        return (true, token);
      } else {
        final data = _safeJson(resp.body);
        final err = (data?['detail'] ?? data?['message'] ?? 'Facebook login thất bại (${resp.statusCode})').toString();
        return (false, err);
      }
    } on TimeoutException {
      return (false, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // NOTIFICATIONS
  // =========================
  static Future<(bool, List<dynamic>, String)> getMyNotifications() async {
    final uri = Uri.parse(ApiBase.api('/notifications/my'));
    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          final data = jsonDecode(resp.body);
          if (data is List) {
            return (true, data, '');
          }
          return (false, [], 'Dữ liệu không hợp lệ');
        } catch (e) {
          return (false, [], 'Lỗi phân tích dữ liệu: $e');
        }
      } else {
        final data = _safeJson(resp.body);
        final err = (data?['detail'] ?? data?['message'] ?? 'Lỗi lấy thông báo (${resp.statusCode})').toString();
        return (false, [], err);
      }
    } on TimeoutException {
      return (false, [], 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, [], 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, dynamic, String)> markNotificationAsRead(int notificationId) async {
    final uri = Uri.parse(ApiBase.api('/notifications/$notificationId/read'));
    try {
      final resp = await http
          .patch(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        return (true, data, '');
      } else {
        final data = _safeJson(resp.body);
        final err = (data?['detail'] ?? data?['message'] ?? 'Lỗi đánh dấu đã đọc (${resp.statusCode})').toString();
        return (false, null, err);
      }
    } on TimeoutException {
      return (false, null, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, null, 'Lỗi kết nối: $e');
    }
  }

  // ---- helpers ----
  static Map<String, dynamic>? _safeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
