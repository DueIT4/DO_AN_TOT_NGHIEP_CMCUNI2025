// lib/core/api_base.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

class ApiBase {
  // ========================
  // 🔗 URL CƠ SỞ (baseURL)
  // ========================
  static String get baseURL {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // Android emulator -> host
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
  static set bearer(String? t) => _bearer = t;
  static String? get bearer => _bearer;
  static String? get bearerToken => _bearer;

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_bearer != null) 'Authorization': 'Bearer $_bearer',
      };

  // ========================
  // 📡 GET JSON
  // ========================
  static Future<dynamic> getJson(String path) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.get(url, headers: _headers());
    if (r.statusCode ~/ 100 != 2) {
      throw Exception('GET $path => ${r.statusCode}: ${r.body}');
    }
    return json.decode(utf8.decode(r.bodyBytes));
  }

  // ========================
  // 📡 POST JSON
  // ========================
  static Future<dynamic> postJson(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.post(
      url,
      headers: _headers(),
      body: json.encode(body),
    );
    if (r.statusCode ~/ 100 != 2) {
      throw Exception('POST $path => ${r.statusCode}: ${r.body}');
    }
    if (r.body.isEmpty) return null;
    return json.decode(utf8.decode(r.bodyBytes));
  }

  // ========================
  // ✏️ PUT JSON
  // ========================
  static Future<dynamic> putJson(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.put(
      url,
      headers: _headers(),
      body: json.encode(body),
    );
    if (r.statusCode ~/ 100 != 2) {
      throw Exception('PUT $path => ${r.statusCode}: ${r.body}');
    }
    if (r.body.isEmpty) return null;
    return json.decode(utf8.decode(r.bodyBytes));
  }

  // ========================
  // ❌ DELETE JSON
  // ========================
  static Future<dynamic> deleteJson(String path) async {
    final url = Uri.parse('$baseURL$path');
    final r = await http.delete(url, headers: _headers());
    if (r.statusCode ~/ 100 != 2) {
      throw Exception('DELETE $path => ${r.statusCode}: ${r.body}');
    }
    if (r.body.isEmpty) return null;
    return json.decode(utf8.decode(r.bodyBytes));
  }
}
