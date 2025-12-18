import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_base_app.dart';

class ApiClient {
  static String? authToken;
  static const _kTokenKey = 'auth_token';

  // ✅ gọi ở main() để tự login lại
  static Future<void> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString(_kTokenKey);
    if (kDebugMode) {
      debugPrint('RESTORE TOKEN: ${authToken?.isNotEmpty == true}');
    }
  }

  // ✅ lưu token sau login
  static Future<void> setAuthToken(String? token) async {
    authToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_kTokenKey, token);
    } else {
      await prefs.remove(_kTokenKey);
    }
  }

  static Future<void> clearAuth() async {
    authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
  }

  static Future<void> logout() async => clearAuth();

  static Map<String, String> authHeaders({
    bool json = true,
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';

    final token = authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extra != null) headers.addAll(extra);
    return headers;
  }

  // =========================
  // REGISTER (BE: POST /auth/register/phone)
  // body: {username, phone, password}
  // =========================
  static Future<(bool, String)> register({
    required String name, // username
    required String identity, // phone
    required String password,
  }) async {
    final phone = identity.trim();
    if (phone.isEmpty || !RegExp(r'^\d{6,}$').hasMatch(phone)) {
      return (false, 'Vui lòng nhập SĐT hợp lệ để đăng ký');
    }

    final uri = ApiBase.uri('/auth/register/phone');

    try {
      final resp = await http
          .post(
            uri,
            headers: authHeaders(),
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
        return (false, _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // LOGIN PHONE (BE: POST /auth/login/phone)
  // body: {phone, password}
  // =========================
  static Future<(bool, String)> login({
    required String identity, // phone
    required String password,
  }) async {
    final phone = identity.trim();
    final uri = ApiBase.uri('/auth/login/phone');
    if (kDebugMode) debugPrint('LOGIN URI = $uri');

    try {
      final resp = await http
          .post(
            uri,
            headers: authHeaders(),
            body: jsonEncode({'phone': phone, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        final token =
            (data?['access_token'] ?? data?['token'] ?? '').toString();
        if (token.isEmpty) {
          return (false, 'Đăng nhập thành công nhưng không nhận token');
        }
        await setAuthToken(token);
        return (true, token);
      } else {
        return (false, _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // GOOGLE LOGIN (BE: POST /auth/login/google)
  // body: {token: idToken}
  // =========================
  static Future<(bool, String)> loginWithGoogle(String idToken) async {
    final uri = ApiBase.uri('/auth/login/google');

    try {
      final res = await http
          .post(
            uri,
            headers: authHeaders(),
            body: jsonEncode({'token': idToken}),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _safeJson(res.body);
        final token =
            (data?['access_token'] ?? data?['token'] ?? '').toString();
        if (token.isEmpty) {
          return (false, 'Google login OK nhưng không có token');
        }
        await setAuthToken(token);
        return (true, token);
      }
      return (false, _extractDetail(res.body));
    } catch (e) {
      return (false, 'Network error: $e');
    }
  }

  // =========================
  // FACEBOOK LOGIN (BE: POST /auth/login/facebook)
  // body: {token: accessToken}
  // =========================
  static Future<(bool, String)> loginWithFacebook(String accessToken) async {
    final uri = ApiBase.uri('/auth/login/facebook');

    try {
      final resp = await http
          .post(
            uri,
            headers: authHeaders(),
            body: jsonEncode({'token': accessToken}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        final token =
            (data?['access_token'] ?? data?['token'] ?? '').toString();
        if (token.isEmpty) {
          return (false, 'Facebook login OK nhưng không có token');
        }
        await setAuthToken(token);
        return (true, token);
      } else {
        return (false, _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // FORGOT PASSWORD OTP (BE: POST /auth/forgot-password-otp)
  // body: {email? , phone?}
  // =========================
  static Future<(bool, String)> forgotPasswordOtp({
    String? email,
    String? phone,
  }) async {
    final uri = ApiBase.uri('/auth/forgot-password-otp');

    final body = <String, dynamic>{
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    };

    try {
      final res = await http
          .post(
            uri,
            headers: authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _safeJson(res.body);
        return (true, (data?['message'] ?? 'OTP đã được gửi').toString());
      }
      return (false, _extractDetail(res.body));
    } on TimeoutException {
      return (false, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // VERIFY RESET OTP (BE: POST /auth/verify-reset-otp)
  // body: {contact, otp}
  // =========================
  static Future<(bool, String)> verifyResetOtp({
    required String contact,
    required String otp,
  }) async {
    final uri = ApiBase.uri('/auth/verify-reset-otp');

    try {
      final res = await http
          .post(
            uri,
            headers: authHeaders(),
            body: jsonEncode({'contact': contact.trim(), 'otp': otp.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _safeJson(res.body);
        final resetToken = (data?['reset_token'] ?? '').toString();
        if (resetToken.isEmpty) return (false, 'Thiếu reset_token từ máy chủ');
        return (true, resetToken);
      }
      return (false, _extractDetail(res.body));
    } on TimeoutException {
      return (false, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // RESET PASSWORD (BE: POST /auth/reset-password)
  // body: {token, new_password}
  // =========================
  static Future<(bool, String)> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final uri = ApiBase.uri('/auth/reset-password');

    try {
      final res = await http
          .post(
            uri,
            headers: authHeaders(),
            body: jsonEncode({'token': token, 'new_password': newPassword}),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _safeJson(res.body);
        return (true, (data?['message'] ?? 'OK').toString());
      }
      return (false, _extractDetail(res.body));
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
    final uri = ApiBase.uri('/notifications/my');

    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        if (data is List) return (true, data, '');
        return (false, [], 'Dữ liệu không hợp lệ');
      } else {
        return (false, [], _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, [], 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, [], 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, dynamic, String)> markNotificationAsRead(
      int notificationId) async {
    final uri = ApiBase.uri('/notifications/$notificationId/read');

    try {
      final resp = await http
          .patch(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return (true, _safeJson(resp.body), '');
      } else {
        return (false, null, _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, null, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, null, 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // CHATBOT
  // =========================
  static Future<(bool, List<dynamic>, String)> listChatbotSessions() async {
    final uri = ApiBase.uri('/chatbot/sessions');
    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        if (data is List) return (true, data, '');
        return (false, [], 'Dữ liệu không hợp lệ');
      } else {
        return (false, [], _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, [], 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, [], 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, dynamic, String)> getChatbotSession(int chatbotId) async {
    final uri = ApiBase.uri('/chatbot/sessions/$chatbotId');
    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return (true, _safeJson(resp.body), '');
      } else {
        return (false, null, _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, null, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, null, 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, dynamic, String)> createChatbotSession() async {
    final uri = ApiBase.uri('/chatbot/sessions');
    try {
      final resp = await http
          .post(uri, headers: authHeaders(json: false))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return (true, _safeJson(resp.body), '');
      } else {
        return (false, null, _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, null, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, null, 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, dynamic, String)> sendChatbotMessage({
    required String question,
    int? chatbotId,
  }) async {
    final uri = ApiBase.uri('/chatbot/messages');
    try {
      final body = <String, dynamic>{'question': question};
      if (chatbotId != null) body['chatbot_id'] = chatbotId;

      final resp = await http
          .post(uri, headers: authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return (true, _safeJson(resp.body), '');
      } else {
        return (false, null, _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, null, 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, null, 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, List<dynamic>, String)> getChatbotMessages(
      int chatbotId) async {
    final uri = ApiBase.uri('/chatbot/sessions/$chatbotId/messages');
    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        if (data is List) return (true, data, '');
        return (false, [], 'Dữ liệu không hợp lệ');
      } else {
        return (false, [], _extractDetail(resp.body));
      }
    } on TimeoutException {
      return (false, [], 'Hết thời gian kết nối máy chủ');
    } catch (e) {
      return (false, [], 'Lỗi kết nối: $e');
    }
  }

  // =========================
  // Helpers
  // =========================
  static Map<String, dynamic>? _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _extractDetail(String body) {
    try {
      final data = jsonDecode(body);
      return (data['detail'] ?? data['message'] ?? 'Có lỗi xảy ra').toString();
    } catch (_) {
      return 'Có lỗi xảy ra';
    }
  }
}
