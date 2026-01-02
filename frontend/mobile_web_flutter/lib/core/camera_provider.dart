import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider quản lý camera được chọn của người dùng
class CameraProvider extends ChangeNotifier {
  int? _selectedCameraId;
  String? _selectedCameraName;
  String? _selectedCameraStreamUrl;

  int? get selectedCameraId => _selectedCameraId;
  String? get selectedCameraName => _selectedCameraName;
  String? get selectedCameraStreamUrl => _selectedCameraStreamUrl;

  CameraProvider() {
    _loadFromStorage();
  }

  // Khôi phục camera đã chọn từ lần đăng nhập trước
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedCameraId = prefs.getInt('selected_camera_id');
      _selectedCameraName = prefs.getString('selected_camera_name');
      _selectedCameraStreamUrl = prefs.getString('selected_camera_stream_url');
      notifyListeners();
    } catch (_) {}
  }

  /// Cập nhật thiết bị mới được chọn
  Future<void> setSelectedCamera({
    required int deviceId,
    required String deviceName,
    required String streamUrl,
  }) async {
    _selectedCameraId = deviceId;
    _selectedCameraName = deviceName;
    _selectedCameraStreamUrl = streamUrl;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_camera_id', deviceId);
      await prefs.setString('selected_camera_name', deviceName);
      await prefs.setString('selected_camera_stream_url', streamUrl);
    } catch (_) {}

    // Thông báo cho toàn bộ App (Home, CameraPage...) để cập nhật luồng stream
    notifyListeners();
  }

  /// Xóa camera (ví dụ khi người dùng Logout hoặc xóa thiết bị)
  Future<void> clearSelectedCamera() async {
    _selectedCameraId = null;
    _selectedCameraName = null;
    _selectedCameraStreamUrl = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_camera_id');
      await prefs.remove('selected_camera_name');
      await prefs.remove('selected_camera_stream_url');
    } catch (_) {}

    notifyListeners();
  }
}