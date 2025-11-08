import 'package:flutter/material.dart';
import '../../../layout/admin_shell_web.dart';

class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {'title': 'Cảnh báo nhiệt độ cao', 'time': '10 phút trước'},
      {'title': 'Cảm biến ẩm đất ngắt kết nối', 'time': '2 giờ trước'},
    ];

    return AdminShellWeb(
      title: 'Thông báo',
      current: AdminMenu.notifications,
      body: ListView.separated(
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: Text(notifications[i]['title']!),
          subtitle: Text(notifications[i]['time']!),
        ),
      ),
    );
  }
}
