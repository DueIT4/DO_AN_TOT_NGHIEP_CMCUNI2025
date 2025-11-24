// lib/modules/admin/admin_routes.dart

import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/admin/admin_shell.dart';

// Trang con
import 'package:mobile_web_flutter/modules/admin/dashboard/admin_dashboard_page.dart';
import 'package:mobile_web_flutter/modules/admin/device/admin_devices_page.dart';
import 'package:mobile_web_flutter/modules/admin/user/admin_users_page.dart';
import 'package:mobile_web_flutter/modules/admin/notifications/admin_notifications_page.dart';
import 'package:mobile_web_flutter/modules/admin/support/admin_support_page.dart';
import 'package:mobile_web_flutter/modules/admin/history/detection_history_page.dart';

// Service cho lịch sử dự đoán (hiện chưa dùng trực tiếp ở đây, giữ lại)
import 'package:mobile_web_flutter/core/detection_history_service.dart';

/// /admin/dashboard
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

/// /admin/devices
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

/// /admin/users
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

/// /admin/support  → TRANG CHÍNH HỖ TRỢ NGƯỜI DÙNG (ticket + chat)
class AdminSupportRoute extends StatelessWidget {
  const AdminSupportRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      title: 'Hỗ trợ người dùng',
      current: AdminMenu.notifications, // dùng menu "Hỗ trợ người dùng"
      body: AdminSupportPage(),
    );
  }
}

/// /admin/notifications → trang phụ, chỉ đi từ nút "Tạo thông báo"
class AdminNotificationsRoute extends StatelessWidget {
  const AdminNotificationsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      title: 'Thông báo hệ thống',
      current: AdminMenu.notifications,
      body: AdminNotificationsPage(),
    );
  }
}

/// /admin/history → Lịch sử dự đoán
class AdminDetectionHistoryRoute extends StatelessWidget {
  const AdminDetectionHistoryRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      title: 'Lịch sử dự đoán',
      current: AdminMenu.detectionHistory,
      body: AdminDetectionHistoryPage(),
    );
  }
}
