// lib/core/api_base_app.dart
import 'package:flutter/foundation.dart';

class ApiBase {
  // ✅ App Android emulator (mặc định Flutter run trên emulator)
  static const String _androidEmuHost = 'http://10.0.2.2:8000';

  // ✅ Host cho web và thiết bị thật (LAN). Đổi IP này cho phù hợp mạng nội bộ.
  // Có thể gán bằng --dart-define API_LAN_HOST="http://192.168.x.x:8000"
  static const String _lanHost = String.fromEnvironment(
    'API_LAN_HOST',
    defaultValue: 'http://localhost:8000',
  );

  // ✅ Cho phép chọn chạy Android trên thiết bị thật dùng LAN thay vì 10.0.2.2
  // Bật bằng --dart-define USE_ANDROID_LAN_HOST=true khi build/run trên máy thật.
  static const bool _useAndroidLanHost = bool.fromEnvironment(
    'USE_ANDROID_LAN_HOST',
    defaultValue: false,
  );

  static String get host {
    if (kIsWeb)
      return _lanHost; // Web cần IP LAN, không phải 127.0.0.1 trên mobile

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Mặc định emulator; nếu build chạy trên thiết bị thật, bật flag để dùng LAN
      return _useAndroidLanHost ? _lanHost : _androidEmuHost;
    }

    // macOS/Windows/iOS nếu có, tạm dùng LAN host
    return _lanHost;
  }

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
