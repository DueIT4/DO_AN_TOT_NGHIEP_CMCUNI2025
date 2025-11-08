// lib/core/api_base.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

/// Bật mock dữ liệu: true để demo, false để gọi API thật.
const bool USE_MOCK = true;

/// ---------------------- MOCK DATA (top-level, không static) ---------------------- ///
const _demoDevices = [
  {
    "device_id": 1,
    "name": "Gateway Vườn Bưởi A",
    "serial_no": "GW-A-001",
    "device_type_id": 1,
    "status": "active",
    "location": "Lô A - Gốc 12",
  },
  {
    "device_id": 2,
    "name": "Cam Quan Sát Tán Lá",
    "serial_no": "CAM-L-023",
    "device_type_id": 2,
    "status": "active",
    "location": "Lô A - Gốc 08",
  },
  {
    "device_id": 3,
    "name": "Cảm Biến Độ Ẩm Đất",
    "serial_no": "SM-310",
    "device_type_id": 3,
    "status": "inactive",
    "location": "Lô B - Gốc 03",
  },
];

const _demoDeviceDetail = {
  1: {
    "device_id": 1,
    "name": "Gateway Vườn Bưởi A",
    "serial_no": "GW-A-001",
    "device_type_id": 1,
    "device_type_name": "GATEWAY",
    "status": "active",
    "location": "Lô A - Gốc 12",
    "fw_version": "1.4.2",
    "ip_addr": "192.168.1.50",
    "last_seen": "2025-11-06T12:58:23Z",
    "notes": "Thiết bị trung tâm thu thập dữ liệu cảm biến."
  },
  2: {
    "device_id": 2,
    "name": "Cam Quan Sát Tán Lá",
    "serial_no": "CAM-L-023",
    "device_type_id": 2,
    "device_type_name": "CAMERA",
    "status": "active",
    "location": "Lô A - Gốc 08",
    "fw_version": "2.0.1",
    "ip_addr": "192.168.1.77",
    "last_seen": "2025-11-06T13:02:10Z",
    "notes": "Camera AI phát hiện bệnh lá bưởi.",
  },
  3: {
    "device_id": 3,
    "name": "Cảm Biến Độ Ẩm Đất",
    "serial_no": "SM-310",
    "device_type_id": 3,
    "device_type_name": "SOIL_SENSOR",
    "status": "inactive",
    "location": "Lô B - Gốc 03",
    "fw_version": "0.9.9",
    "ip_addr": null,
    "last_seen": "2025-10-21T08:11:02Z",
    "notes": "Hết pin, cần thay.",
  },
};

const _demoReadings = {
  1: [
    {"metric": "cpu_temp", "value": 53.2, "unit": "°C", "ts": "2025-11-06T13:15:20Z"},
    {"metric": "ram_usage", "value": 61.0, "unit": "%", "ts": "2025-11-06T13:15:20Z"},
    {"metric": "disk_free", "value": 42.8, "unit": "%", "ts": "2025-11-06T13:15:20Z"},
  ],
  2: [
    {"metric": "yolo_fps", "value": 21.3, "unit": "fps", "ts": "2025-11-06T13:16:02Z"},
    {"metric": "detect_conf_avg", "value": 0.34, "unit": "", "ts": "2025-11-06T13:16:02Z"},
    {"metric": "exposure_ms", "value": 12.0, "unit": "ms", "ts": "2025-11-06T13:16:02Z"},
  ],
  3: [
    {"metric": "soil_moisture", "value": 18.5, "unit": "%", "ts": "2025-11-01T06:45:10Z"},
    {"metric": "soil_temp", "value": 26.1, "unit": "°C", "ts": "2025-11-01T06:45:10Z"},
    {"metric": "battery", "value": 0.0, "unit": "%", "ts": "2025-11-01T06:45:10Z"},
  ],
};
/// ------------------------------------------------------------------------------- ///

class ApiBase {
  // ========================
  // 🔗 URL CƠ SỞ (baseURL)
  // ========================
  static String get baseURL {
    if (USE_MOCK) {
      // baseURL vẫn cần để ghép khi gọi HTTP thật; với mock thì không dùng tới.
      return 'http://127.0.0.1:8000';
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    // Không dùng dart:io; dùng defaultTargetPlatform để phân biệt Android emulator
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // Android emulator -> host machine
    }
    return 'http://127.0.0.1:8000';  // iOS/desktop
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
  static String? get bearerToken => _bearer;

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_bearer != null) 'Authorization': 'Bearer $_bearer',
      };

  // ========================
  // 📡 Gửi GET / POST JSON
  // ========================
  /// [path] phải là chuỗi kiểu "/api/v1/xxx" (dùng ApiBase.api(...))
  static Future<dynamic> getJson(String path) async {
    if (USE_MOCK) {
      // Giả lập endpoint bằng chính [path]
      await Future.delayed(const Duration(milliseconds: 250));

      if (path.endsWith('/devices/')) return _demoDevices;

      final devDetail = RegExp(r'^/api/v1/devices/(\d+)$');
      final devReadings = RegExp(r'^/api/v1/devices/(\d+)/readings');

      if (devDetail.hasMatch(path)) {
        final id = int.parse(devDetail.firstMatch(path)!.group(1)!);
        return _demoDeviceDetail[id] ?? {};
        }
      if (devReadings.hasMatch(path)) {
        final id = int.parse(devReadings.firstMatch(path)!.group(1)!);
        return _demoReadings[id] ?? [];
      }
      throw Exception('Mock GET không hỗ trợ path: $path');
    }

    final url = Uri.parse('$baseURL$path');
    final r = await http.get(url, headers: _headers());
    if (r.statusCode ~/ 100 != 2) {
      throw Exception('GET $path => ${r.statusCode}: ${r.body}');
    }
    return json.decode(utf8.decode(r.bodyBytes));
  }

  static Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    if (USE_MOCK) {
      await Future.delayed(const Duration(milliseconds: 250));

      if (path.endsWith('/devices/')) {
        final nextId =
            (_demoDevices.isEmpty ? 1 : (_demoDevices.last['device_id'] as int) + 1);
        final created = {
          "device_id": nextId,
          "name": body["name"],
          "serial_no": body["serial_no"],
          "device_type_id": body["device_type_id"],
          "status": "active",
          "location": body["location"],
        };
        // Thêm vào danh sách mock
        (_demoDevices as List).add(created);
        return created;
      }

      throw Exception('Mock POST không hỗ trợ path: $path');
    }

    final url = Uri.parse('$baseURL$path');
    final r = await http.post(url, headers: _headers(), body: json.encode(body));
    if (r.statusCode ~/ 100 != 2) {
      throw Exception('POST $path => ${r.statusCode}: ${r.body}');
    }
    return json.decode(utf8.decode(r.bodyBytes));
  }
}
