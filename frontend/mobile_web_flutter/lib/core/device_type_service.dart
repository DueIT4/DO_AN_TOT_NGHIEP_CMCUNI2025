import '../core/api_base.dart';

class DeviceTypeService {
  /// Lấy danh sách tất cả loại thiết bị
  static Future<List<Map<String, dynamic>>> listDeviceTypes() async {
    final res = await ApiBase.getJson(
      ApiBase.api('/device-types/device-types/'),
    );

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Tạo mới loại thiết bị (admin)
  static Future<Map<String, dynamic>> createDeviceType(
      Map<String, dynamic> body) async {
    final res = await ApiBase.postJson(
      ApiBase.api('/device-types/device-types/'),
      body,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// Cập nhật loại thiết bị (admin)
  static Future<Map<String, dynamic>> updateDeviceType(
      int id, Map<String, dynamic> body) async {
    final res = await ApiBase.putJson(
      ApiBase.api('/device-types/device-types/$id'),
      body,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// Xoá loại thiết bị (admin)
  static Future<void> deleteDeviceType(int id) async {
    await ApiBase.deleteJson(
      ApiBase.api('/device-types/device-types/$id'),
    );
  }
}
