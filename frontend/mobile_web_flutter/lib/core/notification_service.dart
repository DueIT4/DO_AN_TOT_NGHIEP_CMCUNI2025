import 'package:mobile_web_flutter/core/api_base.dart';

class NotificationService {
  /// Danh sách thông báo đã gửi (admin) -> GET /notifications/sent
  static Future<List<Map<String, dynamic>>> listSent() async {
    final res = await ApiBase.getJson(ApiBase.api('/notifications/sent'));
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Tạo thông báo -> POST /notifications/create
  static Future<void> create({
    required String title,
    required String description,
    required bool sendAll,
    List<int>? userIds,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'send_all': sendAll,
    };

    if (!sendAll) {
      body['user_ids'] = (userIds ?? <int>[]);
    }

    await ApiBase.postJson(
      ApiBase.api('/notifications/create'),
      body,
    );
  }

  /// Gửi lại thông báo -> POST /notifications/{id}/resend
  static Future<void> resend({
    required int notificationId,
    required bool sendAll,
    List<int>? userIds,
  }) async {
    final body = <String, dynamic>{
      'send_all': sendAll,
    };

    if (!sendAll) {
      body['user_ids'] = (userIds ?? <int>[]);
    }

    await ApiBase.postJson(
      ApiBase.api('/notifications/$notificationId/resend'),
      body,
    );
  }

  /// Backend bạn gửi KHÔNG có route delete.
  /// Nếu bạn vẫn muốn giữ hàm để compile, mình để throw rõ ràng để khỏi gọi nhầm.
  static Future<void> deleteNotification(int notificationId) async {
    throw UnimplementedError(
      'Backend chưa có endpoint DELETE /notifications/$notificationId/delete',
    );
  }

  /// (Tuỳ chọn) danh sách thông báo của user -> GET /notifications/my
  static Future<List<Map<String, dynamic>>> listMy() async {
    final res = await ApiBase.getJson(ApiBase.api('/notifications/my'));
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// (Tuỳ chọn) /notifications/me (có sender_name) -> GET /notifications/me
  static Future<List<Map<String, dynamic>>> listMe() async {
    final res = await ApiBase.getJson(ApiBase.api('/notifications/me'));
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
