// lib/src/routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'web_routes.dart';

// ===== Public pages =====
import '../../layout/web_shell.dart';
import '../../modules/home/home_content.dart';
import '../../modules/weather/weather_content.dart';
import '../../modules/misc/news_content.dart';

import '../../modules/detect/detect_web.dart';
import '../../modules/auth/login_web.dart';
import '../../modules/auth/confirm_page.dart';
import '../../modules/auth/forgot_password.dart';

// ===== Admin shell + admin pages =====
// Bạn cần 1 AdminShell dạng nhận child để shell giữ nguyên và không khựng.
// Nếu bạn đang có AdminShellWeb(initial: ...), hãy tạo thêm 1 scaffold shell nhận child.
// (Mình đang import ví dụ là admin_shell_scaffold.dart)
import '../../admin/admin_shell_scaffold.dart';

import '../../modules/admin/dashboard/admin_dashboard_page.dart';
import '../../modules/admin/device/admin_devices_page.dart';
import '../../modules/admin/user/admin_users_page.dart';
import '../../modules/admin/support/admin_support_page.dart';
import '../../modules/admin/notifications/admin_notifications_page.dart';
import '../../modules/admin/history/detection_history_page.dart';

final GoRouter appRouter = GoRouter(
  //initialLocation: WebRoutes.home,
  initialLocation: WebRoutes.login,
  routes: [
    // ===== PUBLIC SHELL: navbar giữ nguyên, chỉ child đổi =====
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        // WebShell phải có dạng: WebShell({required Widget child})
        return WebShell(child: child);
      },
      routes: [
        GoRoute(
          path: WebRoutes.home,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeContent()),
        ),
        GoRoute(
          path: WebRoutes.weather,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WeatherContent()),
        ),
        GoRoute(
          path: WebRoutes.news,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: NewsContent()),
        ),
      ],
    ),

    // ===== Routes riêng =====
    GoRoute(
      path: WebRoutes.detect,
      builder: (context, state) => const DetectWebPage(),
    ),
    GoRoute(
      path: WebRoutes.login,
      builder: (context, state) => const LoginWebPage(),
    ),
    GoRoute(
      path: WebRoutes.confirm,
      builder: (context, state) =>
          const Scaffold(body: SafeArea(child: ConfirmPage())),
    ),
    GoRoute(
      path: WebRoutes.forgotPassword,
      builder: (context, state) => const Scaffold(
        body: SafeArea(child: Center(child: ForgotPasswordPage())),
      ),
    ),

    // ===== ADMIN SHELL: sidebar/topbar giữ nguyên, chỉ child đổi =====
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        // AdminShellScaffold là shell nhận child (không dùng initialIndex)
        return AdminShellScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: WebRoutes.admin,
          redirect: (context, state) => WebRoutes.adminDashboard,
        ),
        GoRoute(
          path: WebRoutes.adminDashboard,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdminDashboardPage()),
        ),
        GoRoute(
          path: WebRoutes.adminDevices,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdminDevicesPage()),
        ),
        GoRoute(
          path: WebRoutes.adminUsers,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdminUsersPage()),
        ),
        GoRoute(
          path: WebRoutes.adminSupport,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdminSupportPage()),
        ),
        GoRoute(
          path: WebRoutes.adminNoti,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdminNotificationsPage()),
        ),
        GoRoute(
          path: WebRoutes.adminHis,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdminDetectionHistoryPage()),
        ),

        // nếu bạn chưa làm riêng:
        GoRoute(
          path: WebRoutes.adminPredict,
          redirect: (context, state) => WebRoutes.adminDevices,
        ),
        GoRoute(
          path: WebRoutes.adminSensors,
          redirect: (context, state) => WebRoutes.adminDevices,
        ),
      ],
    ),
  ],

  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('404: ${state.uri}')),
  ),
);
