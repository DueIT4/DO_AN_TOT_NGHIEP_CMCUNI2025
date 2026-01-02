import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_base_app.dart';
import 'api_client.dart';

class CameraStreamService {
  // 1. Lấy camera đang được chọn của người dùng hiện tại
  static Future<Map<String, dynamic>> getSelectedCamera() async {
    final uri = ApiBase.uri('/devices/me/selected');
    try {
      final resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return data is Map<String, dynamic> ? data : <String, dynamic>{};
      }
      return {
        'device_id': null,
        'message': 'Không thể tải camera (${resp.statusCode})',
        'error': true,
      };
    } catch (e) {
      return {'device_id': null, 'message': 'Lỗi kết nối: $e', 'error': true};
    }
  }

  // 2. Kiểm tra sức khỏe của Stream (FFmpeg đang chạy không? Có file .ts mới không?)
  static Future<Map<String, dynamic>> checkStreamHealth(int deviceId) async {
    final uri = ApiBase.uri('/streams/health/$deviceId');
    try {
      final resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return data is Map<String, dynamic> ? data : <String, dynamic>{};
      }
      return {'healthy': false, 'running': false, 'error': 'Lỗi phản hồi (${resp.statusCode})'};
    } catch (e) {
      return {'healthy': false, 'running': false, 'error': 'Lỗi kết nối: $e'};
    }
  }

  // 3. Yêu cầu Backend bắt đầu FFmpeg transcode từ RTSP sang HLS
  static Future<Map<String, dynamic>> startStream(int deviceId) async {
    final uri = ApiBase.uri('/streams/start');
    int retries = 3;
    Duration delay = const Duration(seconds: 1);

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final resp = await http
            .post(
              uri,
              headers: {
                ...ApiClient.authHeaders(),
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'device_id': deviceId}),
            )
            .timeout(const Duration(seconds: 20));

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final data = jsonDecode(resp.body);
          return data is Map<String, dynamic> ? data : <String, dynamic>{};
        }

        if (attempt < retries - 1) {
          await Future.delayed(delay);
          delay *= 2;
          continue;
        }

        return {'hls_url': null, 'running': false, 'message': 'Lỗi khởi động (${resp.statusCode})'};
      } catch (e) {
        if (attempt < retries - 1) {
          await Future.delayed(delay);
          delay *= 2;
          continue;
        }
        return {'hls_url': null, 'running': false, 'message': 'Lỗi: $e'};
      }
    }
    return {'hls_url': null, 'running': false, 'message': 'Thất bại sau nhiều lần thử'};
  }

  // 4. Dừng Stream (Tắt FFmpeg để giải phóng tài nguyên CPU/RAM trên Cloud Run)
  static Future<bool> stopStream(int deviceId) async {
    final uri = ApiBase.uri('/streams/stop');
    try {
      final resp = await http
          .post(
            uri,
            headers: {
              ...ApiClient.authHeaders(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 20));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // ✅ CẬP NHẬT: Đường dẫn HLS mới để khớp với cấu trúc /tmp/hls của Cloud Run
  // Backend hiện serve /tmp/hls tại endpoint /api/v1/stream/hls/playlist/...
  static String buildFullHlsUrl(int deviceId) =>
      '${ApiBase.host}/api/v1/stream/hls/playlist/$deviceId/index.m3u8';
}