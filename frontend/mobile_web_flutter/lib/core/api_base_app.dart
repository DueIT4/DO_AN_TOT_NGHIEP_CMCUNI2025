// lib/core/api_base_app.dart
import 'package:flutter/foundation.dart';

class ApiBase {
  // 1. Android emulator dùng IP đặc biệt 10.0.2.2 để gọi về localhost của máy tính
  static const String _androidEmuHost = 'http://10.0.2.2:8000';

  // 2. IP LAN cho thiết bị thật hoặc Web. 
  // Sau này khi Deploy lên Cloud Run, bạn chỉ cần truyền --dart-define API_LAN_HOST="https://tên-dịch-vụ.a.run.app"
  static const String _lanHost = String.fromEnvironment(
    'API_LAN_HOST',
    defaultValue: 'http://localhost:8000',
  );

  static const bool _useAndroidLanHost = bool.fromEnvironment(
    'USE_ANDROID_LAN_HOST',
    defaultValue: false,
  );

  static String get host {
    if (kIsWeb) return _lanHost;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _useAndroidLanHost ? _lanHost : _androidEmuHost;
    }

    // iOS/macOS/Windows dùng LAN Host (localhost hoặc IP thật)
    return _lanHost;
  }

  static const String _prefix = '/api/v1';

  /// Trả về Uri chuẩn cho API
  static Uri uri(String path, {Map<String, String>? queryParameters}) {
    final p = path.startsWith('/') ? path : '/$path';
    
    // Phân tách host và path để tránh lỗi parse khi host chứa path prefix
    final baseUri = Uri.parse(host);
    
    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: '$_prefix$p',
      queryParameters: queryParameters,
    );
  }

  static String api(String path) => uri(path).toString();
}