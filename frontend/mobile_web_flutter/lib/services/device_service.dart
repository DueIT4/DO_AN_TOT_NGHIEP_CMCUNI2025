// lib/services/device_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_base_app.dart';
import 'api_client.dart';

class DeviceService {
  DeviceService._();

  static Map<String, dynamic> _decodeMap(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Dữ liệu phản hồi không hợp lệ');
    }
  }

  static List<dynamic> _decodeList(String body) {
    try {
      final x = jsonDecode(body);
      return x is List ? x : <dynamic>[];
    } catch (_) {
      throw Exception('Dữ liệu phản hồi không hợp lệ');
    }
  }

  static Map<String, String> _jsonHeaders() {
    // đảm bảo POST JSON không bị 415 Unsupported Media Type
    return {
      ...ApiClient.authHeaders(),
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // =========================
  // ✅ USER APIs
  // =========================
bool get _hasToken =>
    ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty;
  /// ✅ GET /devices/me
  static Future<List<dynamic>> fetchMyDevices({String? q}) async {
      if (ApiClient.authToken == null || ApiClient.authToken!.isEmpty) return [];

    final qp = <String, String>{};
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();

    final uri = ApiBase.uri('/devices/my', queryParameters: qp);

    http.Response resp;
    try {
      resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'Lỗi lấy danh sách thiết bị (${resp.statusCode}): ${resp.body}');
    }

    return _decodeList(resp.body);
  }

  /// ✅ GET /devices/me/{device_id}
  static Future<Map<String, dynamic>> fetchMyDeviceDetail(int deviceId) async {
    final uri = ApiBase.uri('/devices/my/$deviceId');
    http.Response resp;

    try {
      resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'Lỗi lấy chi tiết thiết bị (${resp.statusCode}): ${resp.body}');
    }

    return _decodeMap(resp.body);
  }

  /// ✅ POST /devices/select_camera
  /// Chọn camera/thiết bị đang active cho user hiện tại
  static Future<bool> selectCamera(int deviceId) async {
    final uri = ApiBase.uri('/devices/select_camera');

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: _jsonHeaders(),
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'Lỗi chọn camera (${resp.statusCode}): ${resp.body}');
    }

    return true;
  }

  /// ✅ GET /devices/{device_id}/latest_detection
  /// Lấy kết quả nhận diện mới nhất của device
  static Future<Map<String, dynamic>?> fetchLatestDetection(int deviceId) async {
    final uri = ApiBase.uri('/devices/$deviceId/latest_detection');

    http.Response resp;
    try {
      resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ');
    }

    // Nếu backend trả 404 khi chưa có detection nào, bạn có thể coi như "chưa có dữ liệu"
    if (resp.statusCode == 404) return null;

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'Lỗi lấy latest detection (${resp.statusCode}): ${resp.body}');
    }

    return _decodeMap(resp.body);
  }

  // =========================
  // (OPTIONAL) ADMIN APIs - nếu bạn còn dùng ở màn admin
  // =========================

  /// ✅ GET /users (admin)
  static Future<List<dynamic>> fetchUsers({int skip = 0, int limit = 50}) async {
    final uri = ApiBase.uri('/users', queryParameters: {
      'skip': '$skip',
      'limit': '$limit',
    });

    http.Response resp;
    try {
      resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Lỗi lấy danh sách user (${resp.statusCode}): ${resp.body}');
    }

    return _decodeList(resp.body);
  }

  /// ✅ GET /devices/{device_id} (admin)
  static Future<Map<String, dynamic>> fetchDeviceDetailAdmin(int deviceId) async {
    final uri = ApiBase.uri('/devices/$deviceId');
    http.Response resp;

    try {
      resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'Lỗi lấy chi tiết thiết bị (${resp.statusCode}): ${resp.body}');
    }

    return _decodeMap(resp.body);
  }
}
