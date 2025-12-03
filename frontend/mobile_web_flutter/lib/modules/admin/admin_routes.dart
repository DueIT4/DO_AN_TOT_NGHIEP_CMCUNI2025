// lib/modules/admin/admin_routes.dart

import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/admin/admin_shell.dart';

/// /admin/dashboard
class AdminDashboardRoute extends StatelessWidget {
  const AdminDashboardRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      initial: AdminMenu.dashboard,
    );
  }
}

/// /admin/devices
class AdminDevicesRoute extends StatelessWidget {
  const AdminDevicesRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      initial: AdminMenu.devices,
    );
  }
}

/// /admin/users
class AdminUsersRoute extends StatelessWidget {
  const AdminUsersRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      initial: AdminMenu.users,
    );
  }
}

/// /admin/support  → TRANG CHÍNH HỖ TRỢ NGƯỜI DÙNG (ticket + chat)
class AdminSupportRoute extends StatelessWidget {
  const AdminSupportRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      initial: AdminMenu.notifications,
    );
  }
}

/// /admin/notifications → trang phụ, nếu sau này muốn tách riêng
class AdminNotificationsRoute extends StatelessWidget {
  const AdminNotificationsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      initial: AdminMenu.notifications,
    );
  }
}

/// /admin/history → Lịch sử dự đoán
class AdminDetectionHistoryRoute extends StatelessWidget {
  const AdminDetectionHistoryRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellWeb(
      initial: AdminMenu.detectionHistory,
    );
  }
}
