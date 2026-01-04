import 'package:mobile_web_flutter/core/api_base.dart';

/// Service để quản lý thông tin user hiện tại
class UserService {
  static Map<String, dynamic>? _currentUser;
  static DateTime? _lastFetch;

  /// Lấy thông tin user hiện tại từ API
  static Future<Map<String, dynamic>?> getCurrentUser({
    bool forceRefresh = false,
  }) async {
    // Kiểm tra token (thống nhất với các service khác: ApiBase.bearer)
    final token = ApiBase.bearer;
    if (token == null || token.isEmpty) {
      _currentUser = null;
      _lastFetch = null;
      return null;
    }

    // Cache trong 5 phút trừ khi force refresh
    if (!forceRefresh &&
        _currentUser != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return _currentUser;
    }

    try {
      final userData = await ApiBase.getJson(ApiBase.api('/me/get_me'));

      // Đảm bảo kiểu Map<String, dynamic> để các hàm dưới truy cập key an toàn
      _currentUser = Map<String, dynamic>.from(userData as Map);
      _lastFetch = DateTime.now();
      return _currentUser;
    } catch (e) {
      // Nếu lỗi 401, clear cache
      if (e.toString().contains('401')) {
        _currentUser = null;
        _lastFetch = null;
      }
      return null;
    }
  }

  /// Kiểm tra user có phải admin không
  static Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    if (user == null) return false;
    final roleType = user['role_type'] as String?;
    return roleType == 'admin' || roleType == 'support_admin';
  }

  /// Kiểm tra user có phải admin hoàn toàn không
  static Future<bool> isFullAdmin() async {
    final user = await getCurrentUser();
    if (user == null) return false;
    return user['role_type'] == 'admin';
  }

  /// Lấy role type hiện tại
  static Future<String?> getRoleType() async {
    final user = await getCurrentUser();
    return user?['role_type'] as String?;
  }

  /// Clear cache
  static void clearCache() {
    _currentUser = null;
    _lastFetch = null;
  }

  /// Lấy danh sách tất cả user (cho trang admin)
  static Future<List<Map<String, dynamic>>> listUsers() async {
    final res = await ApiBase.getJson(ApiBase.api('/users'));

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
