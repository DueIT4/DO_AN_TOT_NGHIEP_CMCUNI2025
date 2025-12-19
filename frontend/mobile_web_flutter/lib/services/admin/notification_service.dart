import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/models/admin/notification_models.dart';

class NotificationService {
  static Future<List<NotificationItem>> listSent() async {
    final res = await ApiBase.getJson(ApiBase.api('/notifications/sent'));
    return (res as List)
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

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

    await ApiBase.postJson(ApiBase.api('/notifications/create'), body);
  }

  static Future<void> resend({
    required int notificationId,
    required bool sendAll,
    List<int>? userIds,
  }) async {
    final body = <String, dynamic>{'send_all': sendAll};

    if (!sendAll) {
      body['user_ids'] = (userIds ?? <int>[]);
    }

    await ApiBase.postJson(ApiBase.api('/notifications/$notificationId/resend'), body);
  }

  static Future<List<NotificationItem>> listMy() async {
    final res = await ApiBase.getJson(ApiBase.api('/notifications/my'));
    return (res as List)
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<List<NotificationItem>> listMe() async {
    final res = await ApiBase.getJson(ApiBase.api('/notifications/me'));
    return (res as List)
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> deleteNotification(int notificationId) async {
    throw UnimplementedError(
      'Backend chưa có endpoint DELETE /notifications/$notificationId/delete',
    );
  }
}
