import 'package:mobile_web_flutter/core/api_base.dart';

class DeviceService {
  /// Lấy danh sách tất cả thiết bị
  static Future<List<Map<String, dynamic>>> listDevices() async {
    final res = await ApiBase.getJson(ApiBase.api('/devices/'));
    // res là List<dynamic> -> ép sang List<Map<String, dynamic>>
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Tạo mới thiết bị (cần token)
  static Future<Map<String, dynamic>> createDevice(
      Map<String, dynamic> body) async {
    final res = await ApiBase.postJson(ApiBase.api('/devices/'), body);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Cập nhật thiết bị (cần token)
  static Future<Map<String, dynamic>> updateDevice(
      int deviceId, Map<String, dynamic> body) async {
    final res = await ApiBase.putJson(
      ApiBase.api('/admin/devices/$deviceId'),
      body,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// Xoá thiết bị (cần token)
  static Future<void> deleteDevice(int deviceId) async {
    await ApiBase.deleteJson(ApiBase.api('/admin/devices/$deviceId'));
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
