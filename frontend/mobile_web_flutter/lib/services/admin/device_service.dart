// lib/services/admin/device_service.dart
import 'package:mobile_web_flutter/core/api_base.dart';

class DeviceService {
  /// 1. Lấy danh sách TOÀN BỘ thiết bị (Dành cho Admin)
  /// BE: GET /api/v1/devices/
  static Future<List<Map<String, dynamic>>> listAllDevices() async {
    final res = await ApiBase.getJson(
      ApiBase.api('/devices/'), 
    );
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// 2. Tạo thiết bị mới (Dành cho Admin)
  static Future<Map<String, dynamic>> createDevice(Map<String, dynamic> body) async {
    final res = await ApiBase.postJson(
      ApiBase.api('/devices/admin/devices'),
      body,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// 3. Cập nhật thiết bị (Dành cho Admin)
  static Future<Map<String, dynamic>> updateDevice(int id, Map<String, dynamic> body) async {
    final res = await ApiBase.putJson(
      ApiBase.api('/devices/admin/devices/$id'),
      body,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// 4. Xóa thiết bị (Dành cho Admin)
  static Future<void> deleteDevice(int id) async {
    await ApiBase.deleteJson(
      ApiBase.api('/devices/admin/devices/$id'),
    );
  }

  /// 5. Lấy log của 1 thiết bị (device_logs)
  static Future<List<Map<String, dynamic>>> getDeviceLogs(int deviceId) async {
    final res = await ApiBase.getJson(
      ApiBase.api('/device-logs/$deviceId/logs'),
    );

    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

/// 6. Lấy danh sách thiết bị thuộc về một User cụ thể
  static Future<List<Map<String, dynamic>>> listDevicesByUser(int userId) async {
    final res = await ApiBase.getJson(
      // Sửa từ '/users-devices/user/$userId' thành đường dẫn dưới đây:
      ApiBase.api('/users/$userId/devices'), 
    );
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}
