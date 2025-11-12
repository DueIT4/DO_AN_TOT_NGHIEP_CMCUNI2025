import 'package:flutter/material.dart';
import '../../admin/admin_shell.dart';
import 'device/admin_devices_page.dart';
import 'notifications/admin_notifications_page.dart';
import 'user/admin_users_page.dart';

/// Admin app shell - quản lý routing và hiển thị các trang admin
class AdminApp extends StatelessWidget {
  final String initialRoute;
  
  const AdminApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    // Xác định menu ban đầu dựa trên route
    AdminMenu initialMenu;
    String title;
    Widget body;

    switch (initialRoute) {
      case '/admin':
      case '/admin/devices':
        initialMenu = AdminMenu.devices;
        title = 'Quản lý thiết bị';
        body = const AdminDevicesPage();
        break;
      case '/admin/notifications':
        initialMenu = AdminMenu.notifications;
        title = 'Thông báo';
        body = const AdminNotificationsPage();
        break;
      case '/admin/users':
        initialMenu = AdminMenu.users;
        title = 'Quản lý người dùng';
        body = const AdminUsersPage();
        break;
      case '/admin/predictions':
      case '/admin/sensors':
        // Redirect to devices page for now
        initialMenu = AdminMenu.devices;
        title = 'Quản lý thiết bị';
        body = const AdminDevicesPage();
        break;
      default:
        initialMenu = AdminMenu.devices;
        title = 'Quản lý thiết bị';
        body = const AdminDevicesPage();
    }

    return AdminShellWeb(
      title: title,
      current: initialMenu,
      body: body,
    );
  }
}

