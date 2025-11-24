import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/api_base.dart';

// ===== Trang hiện có =====
import '../../modules/home/home_web.dart';
import '../../modules/detect/detect_web.dart';
// import '../../modules/devices/device_web.dart';
import '../../modules/sensors/sensors_web.dart';
import '../../modules/auth/login_web.dart';

import '../../modules/misc/library_web.dart';
import '../../modules/misc/company_web.dart';
import '../../modules/misc/news_web.dart';
import '../../modules/misc/app_download_web.dart';


// ✅ THAY AdminApp bằng các route admin mới
import '../../modules/admin/admin_routes.dart';

// Auth
import '../../modules/auth/confirm_page.dart';
import '../../modules/auth/forgot_password_page.dart';

// Weather
import '../../modules/weather/weather_page.dart';
import '../../modules/weather/weather_content.dart';

class WebRoutes {
  // Công khai
  static const home       = '/';
  static const detect     = '/detect';
  static const device     = '/device';
  static const sensors    = '/sensors';
  static const login      = '/login';

  // Navbar (public)
  static const library    = '/library';
  static const news       = '/news';
  static const company    = '/company';
  static const app        = '/app';

  // Auth
  static const confirm    = '/auth/confirm';         // nhận token qua query
  static const forgotPassword = '/forgot-password';

  // Weather
  static const weather    = '/weather';

  // Admin
  static const admin          = '/admin';            // có thể map về dashboard / devices
  static const adminDevices   = '/admin/devices';    // ✅ thêm hằng số này
  static const adminUsers     = '/admin/users';
  static const adminPredict   = '/admin/predictions';
  static const adminNoti      = '/admin/notifications';
  static const adminHis     = '/admin/history';
  static const adminSensors   = '/admin/sensors';
static const adminDashboard = '/admin/dashboard';

  // Nếu sau này muốn protect các route admin bằng token thì mở lại:
  // static const _protected = {
  //   admin,
  //   adminDevices,
  //   adminUsers,
  //   adminPredict,
  //   adminNoti,
  //   adminSensors,
  // };

  static Route<dynamic> onGenerate(RouteSettings s) {
    final name = s.name ?? '/';

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

    // Nếu muốn bật bảo vệ route admin thì bỏ comment đoạn này:
    //
    // if (_protected.contains(name) && bearer.isEmpty) {
    //   return _p(
    //     kIsWeb ? const LoginWebPage() : const LoginMobilePage(),
    //     arguments: name, // để Login biết quay lại route này sau khi đăng nhập
    //   );
    // }

 switch (name) {
  // ===== Trang chủ =====
  case home:
    return _p(const HomeWebPage());

  // ===== Detect =====
  case detect:
    return _p(const DetectWebPage());

  // ✅ THÊM LẠI LOGIN Ở ĐÂY
  case login:
    return _p(const LoginWebPage(), arguments: s.arguments);

  // ===== Navbar hiện có =====
  case library:
    return _p(const LibraryWebPage());
  case news:
    return _p(const NewsWeb());
  case app:
    return _p(const AppDownloadWebPage());
      // ===== Auth =====
    

      case confirm:
        return _p(const Scaffold(
          body: SafeArea(child: ConfirmPage()),
        ));

      case forgotPassword:
        return _p(const Scaffold(
          body: SafeArea(
            child: Center(child: ForgotPasswordPage()),
          ),
        ));

      // ===== ADMIN: mỗi route là 1 Shell riêng =====
      case admin:                 // /admin: tạm cho về trang thiết bị
      case adminDevices:          // /admin/devices
        return _p(const AdminDevicesRoute());

      case adminNoti:             // /admin/notifications
        return _p(const AdminNotificationsRoute());      
      case adminHis:             // /admin/
        return _p(const DetectionHistoryRoute());
case adminDashboard:
  return _p(const AdminDashboardRoute());

      case adminUsers:            // /admin/users
        return _p(const AdminUsersRoute());

      // Chưa làm 2 trang này nên tạm reuse Devices (hoặc bạn tạo route riêng)
      case adminPredict:
      case adminSensors:
        return _p(const AdminDevicesRoute());

      // ===== 404 =====
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('404: $name')),
          ),
        );
    }
  }

  static MaterialPageRoute _p(Widget w, {Object? arguments}) =>
      MaterialPageRoute(
        builder: (_) => w,
        settings: RouteSettings(arguments: arguments),
      );
}
