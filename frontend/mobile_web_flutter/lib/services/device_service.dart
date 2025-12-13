import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api_base.dart';
import 'api_client.dart';

class DeviceService {
  DeviceService._();

  static Future<List<dynamic>> fetchDevices() async {
    final uri = Uri.parse(ApiBase.api('/devices'));
    final resp = await http.get(uri, headers: ApiClient.authHeaders());
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      if (data is List) return data;
    }
    return [];
  }

  static Future<bool> selectCamera(int deviceId) async {
    final uri = Uri.parse(ApiBase.api('/devices/select_camera'));
    final resp = await http.post(
      uri,
      headers: ApiClient.authHeaders(),
      body: jsonEncode({"device_id": deviceId}),
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  static Future<Map<String, dynamic>?> fetchLatest(int deviceId) async {
    final uri = Uri.parse(ApiBase.api('/devices/$deviceId/latest_detection'));
    final resp = await http.get(uri, headers: ApiClient.authHeaders());
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }
}
