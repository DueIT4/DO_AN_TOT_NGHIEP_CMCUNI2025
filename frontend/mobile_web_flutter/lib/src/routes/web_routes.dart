// lib/src/routes/web_routes.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/api_base.dart';

// ===== Layout shell cho web public =====
import '../../layout/web_shell.dart';

// ===== Trang hiện có (dùng riêng) =====
import '../../modules/detect/detect_web.dart';
import '../../modules/auth/login_web.dart';

// ✅ Admin routes
import '../../modules/admin/admin_routes.dart';

// Auth
import '../../modules/auth/confirm_page.dart';
import '../../modules/auth/forgot_password.dart';

class WebRoutes {
  // Công khai
  static const home = '/';
  static const detect = '/detect';
  static const device = '/device';
  static const sensors = '/sensors';
  static const login = '/login';

  // Navbar (public)
  static const news = '/news';
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

  static Route<dynamic> onGenerate(RouteSettings s) {
    // 🔧 Chuẩn hoá tên route: bỏ dấu "/" ở cuối nếu có
    var name = s.name ?? home;
    if (name.length > 1 && name.endsWith('/')) {
      name = name.substring(0, name.length - 1);
    }

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
      // ===== Public shell: Home / Weather / News dùng chung WebShell =====
      case home: // '/'
        return _p(const WebShell(initialIndex: 0), s);

      case weather: // '/weather'
        return _p(const WebShell(initialIndex: 1), s);

      case news: // '/news'
        return _p(const WebShell(initialIndex: 2), s);

      // ===== Detect (trang riêng) =====
      case detect:
        return _p(DetectWebPage(), s);

      // ===== Tạm route /device, /sensors về Home cho khỏi 404 =====
      // Nếu sau này bạn có trang riêng thì đổi ở đây
      case device:
      case sensors:
        return _p(const WebShell(initialIndex: 0), s);

      // LOGIN
      case login:
        return _p(const LoginWebPage(), s);

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
      case admin: // /
      case adminDashboard: 
        return _p(const AdminDashboardRoute(), s);

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

      case adminPredict:
      case adminSensors:
        return _p(const AdminDevicesRoute(), s);

      // ===== 404 =====
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('404: $name')),
          ),
          settings: s,
        );
    }
  }

  // 🔑 Giữ nguyên RouteSettings (name + arguments)
  static MaterialPageRoute _p(Widget w, RouteSettings settings) =>
      MaterialPageRoute(
        builder: (_) => w,
        settings: settings,
      );
}
