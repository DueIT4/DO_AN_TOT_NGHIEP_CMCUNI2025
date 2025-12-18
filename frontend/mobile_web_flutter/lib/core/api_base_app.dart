// lib/core/api_base_app.dart
import 'package:flutter/foundation.dart';

class ApiBase {
  // ✅ Web chạy Chrome
  static const String _webHost = 'http://127.0.0.1:8000';

  // ✅ App Android emulator (nếu bạn chạy app)
  static const String _androidEmuHost = 'http://10.0.2.2:8000';

  // Nếu bạn chạy app trên điện thoại thật, đổi thành IP LAN máy chạy BE:
  // static const String _deviceHost = 'http://192.168.1.10:8000';

  static String get host => kIsWeb ? _webHost : _androidEmuHost;

  static const String _prefix = '/api/v1';

  static Uri uri(String path, {Map<String, String>? queryParameters}) {
  final p = path.startsWith('/') ? path : '/$path';

  // tạo uri gốc như cũ
  final base = Uri.parse('$host$_prefix$p');

  // nếu không truyền query => y như cũ (không ảnh hưởng api khác)
  if (queryParameters == null || queryParameters.isEmpty) return base;

  // gắn queryParameters một cách chuẩn
  return base.replace(queryParameters: queryParameters);
}


  // giữ tương thích nếu nơi khác còn dùng string
  static String api(String path) => uri(path).toString();
}
