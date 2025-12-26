import 'package:mobile_web_flutter/core/api_base.dart';

class DeviceService {
  /// 1. Lấy danh sách TOÀN BỘ thiết bị (Dành cho Admin)
  /// BE: GET /api/v1/devices/ (Hàm list_devices của bạn)
  static Future<List<Map<String, dynamic>>> listAllDevices() async {
    final res = await ApiBase.getJson(
      ApiBase.api('/devices/'), 
    );
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 2. Tạo thiết bị mới (Dành cho Admin)
  /// BE: POST /api/v1/devices/admin/devices (Do prefix /devices + route /admin/devices)
  static Future<Map<String, dynamic>> createDevice(Map<String, dynamic> body) async {
    final res = await ApiBase.postJson(
      ApiBase.api('/devices/admin/devices'), // <--- KHỚP VỚI BE
      body,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// 3. Cập nhật thiết bị (Dành cho Admin)
  /// BE: PUT /api/v1/devices/admin/devices/{id}
  static Future<Map<String, dynamic>> updateDevice(int id, Map<String, dynamic> body) async {
    final res = await ApiBase.putJson(
      ApiBase.api('/devices/admin/devices/$id'), // <--- KHỚP VỚI BE
      body,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// 4. Xóa thiết bị (Dành cho Admin)
  /// BE: DELETE /api/v1/devices/admin/devices/{id}
  static Future<void> deleteDevice(int id) async {
    await ApiBase.deleteJson(
      ApiBase.api('/devices/admin/devices/$id'), // <--- KHỚP VỚI BE
    );
  }

  /// Lấy log của 1 thiết bị (device_logs)
  static Future<List<Map<String, dynamic>>> getDeviceLogs(
      int deviceId) async {
    // ⚠️ Nhớ tạo BE route khớp path này, hoặc chỉnh lại path cho phù hợp
    final res = await ApiBase.getJson(
      ApiBase.api('/device-logs/$deviceId/logs'),
    );

    if (res is List) {
      return res
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      throw Exception('Response logs không phải dạng List');
    }
  }

  /// (tuỳ chọn) Lấy danh sách thiết bị theo user
  static Future<List<Map<String, dynamic>>> listDevicesByUser(
      int userId) async {
    final res = await ApiBase.getJson(
      ApiBase.api('/users/$userId/devices'),
    );
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
