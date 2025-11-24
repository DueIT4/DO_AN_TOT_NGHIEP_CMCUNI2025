// lib/src/routes/web_routes.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/api_base.dart';

// ===== Trang hiện có =====
import '../../modules/home/home_web.dart';
import '../../modules/detect/detect_web.dart';
import '../../modules/auth/login_web.dart';

import '../../modules/misc/library_web.dart';
import '../../modules/misc/company_web.dart';
import '../../modules/misc/news_web.dart';
import '../../modules/misc/app_download_web.dart';

// ✅ THAY AdminApp bằng các route admin mới
import '../../modules/admin/admin_routes.dart';

// Auth
import '../../modules/auth/confirm_page.dart';
import '../../modules/auth/forgot_password.dart';

// Weather
import '../../modules/weather/weather_page.dart';
import '../../modules/weather/weather_content.dart';

class WebRoutes {
  // Công khai
  static const home = '/';
  static const detect = '/detect';
  static const device = '/device';
  static const sensors = '/sensors';
  static const login = '/login';

  // Navbar (public)
  static const library = '/library';
  static const news = '/news';
  static const company = '/company';
  static const app = '/app';
  static const weather = '/weather';

  // Auth
  static const confirm = '/auth/confirm'; // nhận token qua query
  static const forgotPassword = '/forgot-password';

  // Admin
  static const admin = '/admin';
  static const adminDevices = '/admin/devices';
  static const adminUsers = '/admin/users';
  static const adminPredict = '/admin/predictions';
  static const adminHis = '/admin/history';
  static const adminSensors = '/admin/sensors';
  static const adminDashboard = '/admin/dashboard';
  static const adminSupport = '/admin/support';
  static const adminNoti = '/admin/notifications';

  // static const _protected = {...} // nếu sau này muốn bảo vệ route admin

  static Route<dynamic> onGenerate(RouteSettings s) {
    final name = s.name ?? home;

    // Đọc bearer (nếu sau này muốn chặn chưa login)
    final bearer = (() {
      try {
        if (ApiBase.bearerToken != null &&
            (ApiBase.bearerToken as String).isNotEmpty) {
          return ApiBase.bearerToken as String;
        }
      } catch (_) {}
      return '';
    })();

    // Nếu muốn bật bảo vệ route admin thì mở lại:
    // if (_protected.contains(name) && bearer.isEmpty) {
    //   return _p(
    //     kIsWeb ? const LoginWebPage() : const LoginMobilePage(),
    //     s,
    //   );
    // }

    switch (name) {
      // ===== Trang chủ =====
      case home:
        return _p(const HomeWebPage(), s);

      // ===== Detect =====
      case detect:
        return _p(const DetectWebPage(), s);

      // LOGIN
      case login:
        return _p(const LoginWebPage(), s);

      // ===== Navbar hiện có =====
      case weather:
        return _p(const WeatherPage(), s);

      case library:
        return _p(const LibraryWebPage(), s);

      case news:
        return _p(const NewsWeb(), s);

      case app:
        return _p(const AppDownloadWebPage(), s);

      // ===== Auth =====
      case confirm:
        return _p(
          const Scaffold(
            body: SafeArea(child: ConfirmPage()),
          ),
          s,
        );

      case forgotPassword:
        return _p(
          const Scaffold(
            body: SafeArea(
              child: Center(child: ForgotPasswordPage()),
            ),
          ),
          s,
        );

      // ===== ADMIN: mỗi route là 1 Shell riêng =====
      case admin: // /admin: tạm cho về trang thiết bị
      case adminDevices: // /admin/devices
        return _p(const AdminDevicesRoute(), s);

      case adminSupport:
        return _p(const AdminSupportRoute(), s);

      case adminNoti: // /admin/notifications
        return _p(const AdminNotificationsRoute(), s);

      case adminHis: // /admin/history
        return _p(const AdminDetectionHistoryRoute(), s);

      case adminDashboard:
        return _p(const AdminDashboardRoute(), s);

      case adminUsers: // /admin/users
        return _p(const AdminUsersRoute(), s);

      // Chưa làm 2 trang này nên tạm reuse Devices (hoặc bạn tạo route riêng)
      case adminPredict:
      case adminSensors:
        return _p(const AdminDevicesRoute(), s);

      // ===== 404 =====
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('404: $name')),
          ),
          settings: s, // giữ settings (name) -> URL đúng khi 404
        );
    }
  }

  // 🔑 Quan trọng: giữ nguyên RouteSettings (name + arguments)
  static MaterialPageRoute _p(Widget w, RouteSettings settings) =>
      MaterialPageRoute(
        builder: (_) => w,
        settings: settings,
      );
}
