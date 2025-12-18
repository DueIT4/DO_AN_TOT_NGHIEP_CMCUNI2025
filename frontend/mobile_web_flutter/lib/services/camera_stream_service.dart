import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_base_app.dart';
import 'api_client.dart';

class CameraStreamService {
  // GET /devices/me/selected
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
        'message': 'Không thể tải camera được chọn (${resp.statusCode})',
        'error': true,
      };
    } on TimeoutException {
      return {
        'device_id': null,
        'message': 'Hết thời gian kết nối máy chủ',
        'error': true,
      };
    } catch (e) {
      return {
        'device_id': null,
        'message': 'Lỗi kết nối: $e',
        'error': true,
      };
    }
  }

  // GET /streams/health/{deviceId}
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
      return {
        'healthy': false,
        'running': false,
        'error': 'Không thể kiểm tra stream health (${resp.statusCode})',
      };
    } on TimeoutException {
      return {
        'healthy': false,
        'running': false,
        'error': 'Hết thời gian kết nối máy chủ',
      };
    } catch (e) {
      return {
        'healthy': false,
        'running': false,
        'error': 'Lỗi kết nối: $e',
      };
    }
  }

  // POST /streams/start
  static Future<Map<String, dynamic>> startStream(int deviceId) async {
    final uri = ApiBase.uri('/streams/start');
    try {
      final resp = await http
          .post(
            uri,
            headers: {
              ...ApiClient.authHeaders(),
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return data is Map<String, dynamic> ? data : <String, dynamic>{};
      }
      return {
        'hls_url': null,
        'running': false,
        'message': 'Không thể khởi động stream (${resp.statusCode})',
      };
    } on TimeoutException {
      return {
        'hls_url': null,
        'running': false,
        'message': 'Hết thời gian kết nối máy chủ',
      };
    } catch (e) {
      return {
        'hls_url': null,
        'running': false,
        'message': 'Lỗi kết nối: $e',
      };
    }
  }

  // POST /streams/stop
  static Future<bool> stopStream(int deviceId) async {
    final uri = ApiBase.uri('/streams/stop');
    try {
      final resp = await http
          .post(
            uri,
            headers: {
              ...ApiClient.authHeaders(),
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 20));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // Relative and absolute HLS URL builders
  static String relativeHlsPath(int deviceId) =>
      '/media/hls/$deviceId/index.m3u8';
  static String buildFullHlsUrl(int deviceId) =>
      '${ApiBase.host}${relativeHlsPath(deviceId)}';
}
