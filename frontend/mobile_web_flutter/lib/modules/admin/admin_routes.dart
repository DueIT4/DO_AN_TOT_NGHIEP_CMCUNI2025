// lib/modules/admin/admin_routes.dart

import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/admin/admin_shell.dart';
import 'package:mobile_web_flutter/modules/admin/device/admin_devices_page.dart';
import 'package:mobile_web_flutter/modules/admin/notifications/admin_notifications_page.dart';
import 'package:mobile_web_flutter/modules/admin/user/admin_users_page.dart';
import 'package:mobile_web_flutter/modules/admin/history/detection_history_page.dart';
import 'package:mobile_web_flutter/core/detection_history_service.dart';
import 'package:mobile_web_flutter/modules/admin/dashboard/admin_dashboard_page.dart';

class AdminDevicesRoute extends StatelessWidget {
  const AdminDevicesRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      title: 'Quản lý thiết bị',
      current: AdminMenu.devices,
      body: AdminDevicesPage(),
    );
  }
}

class AdminNotificationsRoute extends StatelessWidget {
  const AdminNotificationsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      title: 'Quản lý thông báo',
      current: AdminMenu.notifications,
      body: AdminNotificationsPage(),
    );
  }
}

class AdminUsersRoute extends StatelessWidget {
  const AdminUsersRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      title: 'Quản lý người dùng',
      current: AdminMenu.users,
      body: AdminUsersPage(),
    );
  }
}

/// /admin/history
class DetectionHistoryRoute extends StatelessWidget {
  const DetectionHistoryRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShellWeb(
      title: 'Lịch sử dự đoán',
      current: AdminMenu.detectionHistory,
      body: DetectionHistoryPage(
        service: DetectionHistoryService(), // dùng service ở core
      ),
    );
  }
}
class AdminDashboardRoute extends StatelessWidget {
  const AdminDashboardRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      title: 'Dashboard',
      current: AdminMenu.dashboard,
      body: AdminDashboardPage(),
    );
  }
}
