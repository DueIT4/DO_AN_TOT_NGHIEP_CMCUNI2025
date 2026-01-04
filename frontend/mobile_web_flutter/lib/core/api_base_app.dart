// lib/core/api_base_app.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Exception HTTP chuẩn để FE đọc được statusCode + body (Copy from api_base.dart)
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
  // 1. Android emulator dùng IP đặc biệt 10.0.2.2 để gọi về localhost của máy tính
  static const String _androidEmuHost = 'http://10.0.2.2:8000';

  // 2. IP LAN cho thiết bị thật hoặc Web. 
  // Sau này khi Deploy lên Cloud Run, bạn chỉ cần truyền --dart-define API_LAN_HOST="https://tên-dịch-vụ.a.run.app"
  static const String _lanHost = String.fromEnvironment(
    'API_LAN_HOST',
    defaultValue: 'https://zestguard-api-38261474833.asia-southeast1.run.app',
  );

  static const bool _useAndroidLanHost = bool.fromEnvironment(
    'USE_ANDROID_LAN_HOST',
    defaultValue: false,
  );

  static String get host {
    if (kIsWeb) return _lanHost;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // ✅ Release Mode (APK đã build): Luôn trỏ về Cloud Run
      if (kReleaseMode) {
        return _lanHost; 
      }
      // Debug Mode: Dùng 10.0.2.2 cho emulator hoặc LAN host nếu được set
      return _useAndroidLanHost ? _lanHost : _androidEmuHost;
    }

    // iOS/macOS/Windows dùng LAN Host (localhost hoặc IP thật)
    return _lanHost;
  }

  // Helper cho API cũ vẫn dùng baseURL string check
  static String get baseURL => host;

  static const String _prefix = '/api/v1';

  /// Trả về Uri chuẩn cho API
  static Uri uri(String path, {Map<String, String>? queryParameters}) {
    final p = path.startsWith('/') ? path : '/$path';
    
    // Phân tách host và path để tránh lỗi parse khi host chứa path prefix
    final baseUri = Uri.parse(host);
    
    // Nếu host có path sẵn (ví dụ http://ip/foo), ta phải cẩn thận
    // Nhưng ở đây host thường là protocol + domain + port
    // Ta assume host chỉ là base host. 
    
    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: '$_prefix$p',
      queryParameters: queryParameters,
    );
  }

  static String api(String path) => uri(path).toString();

  /// Token Bearer
  static String? _bearer;
  static set bearer(String? t) => _bearer = t;
  static String? get bearer => _bearer;
  static String? get bearerToken => _bearer;

  // ========================
  // 🧩 Helpers (Ported from api_base.dart)
  // ========================
  static Map<String, String> _headers() {
    final t = _bearer;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (t != null && t.trim().isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

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
  // 📡 CÁC PHƯƠNG THỨC HTTP (Ported)
  // ========================

  /// GET JSON
  static Future<dynamic> getJson(String path) async {
    final u = uri(path);
    final r = await http.get(u, headers: _headers());
    _ensure2xx(r, 'GET', path);
    return _decodeBody(r);
  }

  /// POST JSON
  static Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    // Lưu ý: path ở đây có thể là full URL (do hàm api() trả về) hoặc short path?
    // Code api_base.dart dùng: Uri.parse('$baseURL$path')
    // Nhưng auth_service gọi: ApiBase.postJson(ApiBase.api('/auth/login'), body) -> path là full URL string
    // Vì vậy ta cần xử lý 2 trường hợp:
    // 1. path là full URL (bắt đầu bằng http) -> Uri.parse(path)
    // 2. path là relative path -> dùng uri(path)
    
    Uri u;
    if (path.startsWith('http')) {
      u = Uri.parse(path);
    } else {
      u = uri(path);
    }

    final r = await http.post(
      u,
      headers: _headers(),
      body: json.encode(body),
    );
    _ensure2xx(r, 'POST', path);
    return _decodeBody(r);
  }

  /// PUT JSON
  static Future<dynamic> putJson(String path, Map<String, dynamic> body) async {
    Uri u;
    if (path.startsWith('http')) {
      u = Uri.parse(path);
    } else {
      u = uri(path);
    }

    final r = await http.put(
      u,
      headers: _headers(),
      body: json.encode(body),
    );
    _ensure2xx(r, 'PUT', path);
    return _decodeBody(r);
  }

  /// PATCH JSON
  static Future<dynamic> patchJson(String path, Map<String, dynamic> body) async {
    Uri u;
    if (path.startsWith('http')) {
      u = Uri.parse(path);
    } else {
      u = uri(path);
    }

    final r = await http.patch(
      u,
      headers: _headers(),
      body: json.encode(body),
    );
    _ensure2xx(r, 'PATCH', path);
    return _decodeBody(r);
  }

  /// DELETE JSON
  static Future<dynamic> deleteJson(String path) async {
    Uri u;
    if (path.startsWith('http')) {
      u = Uri.parse(path);
    } else {
      u = uri(path);
    }

    final r = await http.delete(u, headers: _headers());
    _ensure2xx(r, 'DELETE', path);
    return _decodeBody(r);
  }
}
