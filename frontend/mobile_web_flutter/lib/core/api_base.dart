// lib/core/api_base.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

/// Exception HTTP chuẩn để FE đọc được statusCode + body
class ApiHttpException implements Exception {
  final int statusCode;
  final String method;
  final String path;
  final Object? data; // Map/String/null
  final String rawBody;

  ApiHttpException({
    required this.statusCode,
    required this.method,
    required this.path,
    required this.rawBody,
    this.data,
  });

  @override
  String toString() => '$method $path => $statusCode: $rawBody';
}

class ApiBase {
  // ========================
  // 🔗 URL CƠ SỞ (baseURL)
  // ========================
  static String? _customBaseURL;
  
  /// Cho phép gán URL động (Dùng khi deploy Cloud Run)
  static set setBaseURL(String url) => _customBaseURL = url;

  static String get baseURL {
    if (_customBaseURL != null) return _customBaseURL!;
    
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // Android emulator
    }
    return 'http://127.0.0.1:8000'; // iOS / desktop
  }

  // Prefix API dùng chung
  static const String apiPrefix = '/api/v1';

  /// Gộp prefix + path (vd: ApiBase.api('/devices/'))
  static String api(String path) {
    if (!path.startsWith('/')) path = '/$path';
    return '$apiPrefix$path';
  }

  // ========================
  // 🔐 Bearer token
  // ========================
  static String? _bearer;
  
  /// Cập nhật token xác thực
  static set bearer(String? t) => _bearer = t;
  static String? get bearer => _bearer;
  
  /// ✅ Bí danh (Alias) để khớp với các file UI gọi .bearerToken
  static String? get bearerToken => _bearer;

  static Map<String, String> _headers() {
    final t = _bearer;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (t != null && t.trim().isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  // ========================
  // 🧩 Helpers
  // ========================
  static dynamic _decodeBody(http.Response r) {
    if (r.bodyBytes.isEmpty) return null;
    return json.decode(utf8.decode(r.bodyBytes));
  }

  static void _ensure2xx(http.Response r, String method, String path) {
    if (r.statusCode ~/ 100 != 2) {
      Object? parsed;
      try {
        parsed = _decodeBody(r);
      } catch (_) {
        parsed = null;
      }

      throw ApiHttpException(
        statusCode: r.statusCode,
        method: method,
        path: path,
        rawBody: r.body,
        data: parsed,
      );
    }
  }

  // ========================
  // 📡 CÁC PHƯƠNG THỨC HTTP
  // ========================

  /// GET JSON
  static Future<dynamic> getJson(String path) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.get(url, headers: _headers());
    _ensure2xx(r, 'GET', path);
    return _decodeBody(r);
  }

  /// POST JSON
  static Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.post(
      url,
      headers: _headers(),
      body: json.encode(body),
    );
    _ensure2xx(r, 'POST', path);
    return _decodeBody(r);
  }

  /// PUT JSON
  static Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.put(
      url,
      headers: _headers(),
      body: json.encode(body),
    );
    _ensure2xx(r, 'PUT', path);
    return _decodeBody(r);
  }

  /// PATCH JSON
  static Future<dynamic> patchJson(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.patch(
      url,
      headers: _headers(),
      body: json.encode(body),
    );
    _ensure2xx(r, 'PATCH', path);
    return _decodeBody(r);
  }

  /// DELETE JSON
  static Future<dynamic> deleteJson(String path) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.delete(url, headers: _headers());
    _ensure2xx(r, 'DELETE', path);
    return _decodeBody(r);
  }
}