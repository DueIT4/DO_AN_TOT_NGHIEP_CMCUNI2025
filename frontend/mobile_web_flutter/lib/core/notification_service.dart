// lib/core/notification_service.dart
import 'package:mobile_web_flutter/core/api_base.dart';

class NotificationService {
  /// Danh sách thông báo đã gửi (admin)
  static Future<List<Map<String, dynamic>>> listSent() async {
    final res = await ApiBase.getJson(ApiBase.api('/notifications/sent'));
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Tạo thông báo (gửi tất cả hoặc theo user_ids)
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
      body['user_ids'] = userIds ?? [];
    }

    await ApiBase.postJson(
      ApiBase.api('/notifications/create'),
      body,
    );
  }

  /// Xoá một thông báo
  static Future<void> deleteNotification(int notificationId) async {
    await ApiBase.deleteJson(
      ApiBase.api('/notifications/$notificationId/delete'),
    );
  }
}
