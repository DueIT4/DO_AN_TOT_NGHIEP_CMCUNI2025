// lib/services/api_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_base_app.dart';

class ApiClient {
  static String? authToken;
  static const _kTokenKey = 'auth_token';

  // ✅ Khôi phục Token khi khởi động App (gọi ở main.dart)
  static Future<void> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString(_kTokenKey);
    if (kDebugMode) {
      debugPrint('RESTORE TOKEN: ${authToken?.isNotEmpty == true}');
    }
  }

  // ✅ Lưu token sau khi đăng nhập thành công
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

  // ===========================================================
  // 🔐 AUTHENTICATION (REGISTER / LOGIN)
  // ===========================================================

  static Future<(bool, String)> register({
    required String name,
    required String identity,
    required String password,
  }) async {
    final username = name.trim();
    final input = identity.trim();
    final isEmail = input.contains('@');

    final uri = ApiBase.uri(isEmail ? '/auth/register/email' : '/auth/register/phone');

    final body = <String, dynamic>{
      'username': username,
      'password': password,
      if (isEmail) 'email': input.toLowerCase() else 'phone': input,
    };

    try {
      final resp = await http
          .post(uri, headers: authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        return (true, (data?['message'] ?? 'Đăng ký thành công').toString());
      }
      return (false, _extractDetail(resp.body));
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, String)> login({
    required String identity,
    required String password,
  }) async {
    final id = identity.trim();
    final isEmail = id.contains('@');

    final uri = isEmail ? ApiBase.uri('/auth/login') : ApiBase.uri('/auth/login/phone');

    final body = <String, dynamic>{
      'password': password,
      if (isEmail) 'email': id.toLowerCase() else 'phone': id,
    };

    try {
      final resp = await http
          .post(uri, headers: authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        final token = (data?['access_token'] ?? data?['token'] ?? '').toString();

        if (token.isEmpty) return (false, 'Đăng nhập lỗi: Không có token');
        await setAuthToken(token);
        return (true, token);
      }
      return (false, _extractDetail(resp.body));
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  static Future<(bool, String)> loginWithGoogle(String idToken) async {
    final uri = ApiBase.uri('/auth/login/google');
    try {
      final res = await http
          .post(uri, headers: authHeaders(), body: jsonEncode({'token': idToken}))
          .timeout(const Duration(seconds: 20));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _safeJson(res.body);
        final token = (data?['access_token'] ?? data?['token'] ?? '').toString();
        await setAuthToken(token);
        return (true, token);
      }
      return (false, _extractDetail(res.body));
    } catch (e) {
      return (false, 'Network error: $e');
    }
  }

  static Future<(bool, String)> loginWithFacebook(String accessToken) async {
    final uri = ApiBase.uri('/auth/login/facebook');
    try {
      final resp = await http
          .post(uri, headers: authHeaders(), body: jsonEncode({'token': accessToken}))
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = _safeJson(resp.body);
        final token = (data?['access_token'] ?? data?['token'] ?? '').toString();
        await setAuthToken(token);
        return (true, token);
      }
      return (false, _extractDetail(resp.body));
    } catch (e) {
      return (false, 'Lỗi kết nối: $e');
    }
  }

  // ===========================================================
  // 🔑 PASSWORD RECOVERY
  // ===========================================================

  static Future<(bool, String)> forgotPasswordOtp({
    String? email,
    String? phone,
  }) async {
    final uri = ApiBase.uri('/auth/forgot-password-otp');
    final body = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    try {
      final res = await http
          .post(uri, headers: authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      return (res.statusCode < 300, _extractDetail(res.body));
    } catch (e) {
      return (false, 'Lỗi: $e');
    }
  }

  static Future<(bool, String)> verifyResetOtp({
    required String contact,
    required String otp,
  }) async {
    final uri = ApiBase.uri('/auth/verify-reset-otp');
    try {
      final res = await http
          .post(uri, headers: authHeaders(), body: jsonEncode({'contact': contact, 'otp': otp}))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode < 300) {
        final data = _safeJson(res.body);
        return (true, (data?['reset_token'] ?? '').toString());
      }
      return (false, _extractDetail(res.body));
    } catch (e) {
      return (false, 'Lỗi: $e');
    }
  }

  static Future<(bool, String)> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final uri = ApiBase.uri('/auth/reset-password');
    try {
      final res = await http
          .post(uri, headers: authHeaders(), body: jsonEncode({'token': token, 'new_password': newPassword}))
          .timeout(const Duration(seconds: 20));
      return (res.statusCode < 300, _extractDetail(res.body));
    } catch (e) {
      return (false, 'Lỗi: $e');
    }
  }

  // ===========================================================
  // 🔔 NOTIFICATIONS
  // ===========================================================

  static Future<(bool, List<dynamic>, String)> getMyNotifications() async {
    final uri = ApiBase.uri('/notifications/my');
    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return (true, data is List ? data : [], '');
      }
      return (false, [], _extractDetail(resp.body));
    } catch (e) {
      return (false, [], 'Lỗi: $e');
    }
  }

  static Future<(bool, dynamic, String)> markNotificationAsRead(int notificationId) async {
    final uri = ApiBase.uri('/notifications/$notificationId/read');
    try {
      final resp = await http
          .patch(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 300) {
        return (true, _safeJson(resp.body), '');
      }
      return (false, null, _extractDetail(resp.body));
    } catch (e) {
      return (false, null, 'Lỗi: $e');
    }
  }

  // ===========================================================
  // 🤖 CHATBOT (AI GEMINI)
  // ===========================================================

  static Future<(bool, List<dynamic>, String)> listChatbotSessions() async {
    final uri = ApiBase.uri('/chatbot/sessions');
    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return (true, data is List ? data : [], '');
      }
      return (false, [], _extractDetail(resp.body));
    } catch (e) {
      return (false, [], 'Lỗi: $e');
    }
  }

  static Future<(bool, dynamic, String)> getChatbotSession(int chatbotId) async {
    final uri = ApiBase.uri('/chatbot/sessions/$chatbotId');
    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 300) {
        return (true, _safeJson(resp.body), '');
      }
      return (false, null, _extractDetail(resp.body));
    } catch (e) {
      return (false, null, 'Lỗi: $e');
    }
  }

  static Future<(bool, dynamic, String)> sendChatbotMessage({
    required String question,
    int? chatbotId,
  }) async {
    final uri = ApiBase.uri('/chatbot/messages');
    try {
      final body = <String, dynamic>{'question': question, if (chatbotId != null) 'chatbot_id': chatbotId};
      final resp = await http
          .post(uri, headers: authHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode < 300) {
        return (true, _safeJson(resp.body), '');
      }
      return (false, null, _extractDetail(resp.body));
    } catch (e) {
      return (false, null, 'Lỗi: $e');
    }
  }

  static Future<(bool, List<dynamic>, String)> getChatbotMessages(int chatbotId) async {
    final uri = ApiBase.uri('/chatbot/sessions/$chatbotId/messages');
    try {
      final resp = await http
          .get(uri, headers: authHeaders())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return (true, data is List ? data : [], '');
      }
      return (false, [], _extractDetail(resp.body));
    } catch (e) {
      return (false, [], 'Lỗi: $e');
    }
  }

  static Future<(bool, dynamic, String)> createChatbotSession() async {
    final uri = ApiBase.uri('/chatbot/sessions');
    try {
      final resp = await http
          .post(uri, headers: authHeaders(json: false))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode < 300) {
        return (true, _safeJson(resp.body), '');
      }
      return (false, null, _extractDetail(resp.body));
    } catch (e) {
      return (false, null, 'Lỗi: $e');
    }
  }

  // ===========================================================
  // 🛠 HELPERS
  // ===========================================================

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
      return 'Lỗi phản hồi từ máy chủ';
    }
  }
}