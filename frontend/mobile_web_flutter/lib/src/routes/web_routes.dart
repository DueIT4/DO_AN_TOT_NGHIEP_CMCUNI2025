import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/api_base.dart';

// ===== Trang hiện có của bạn =====
import '../../modules/home/home_web.dart';
import '../../modules/home/home_mobile.dart';
import '../../modules/detect/detect_web.dart';
import '../../modules/detect/detect_mobile.dart';
import '../../modules/devices/device_web.dart';
import '../../modules/devices/device_mobile.dart';
import '../../modules/sensors/sensors_web.dart';
import '../../modules/sensors/sensors_mobile.dart';
import '../../modules/auth/login_web.dart';
import '../../modules/auth/login_mobile.dart';

// Các trang nội dung “tĩnh” hiện có
import '../../modules/misc/library_web.dart';
import '../../modules/misc/company_web.dart';
import '../../modules/misc/news_web.dart';
import '../../modules/misc/app_download_web.dart';

// ===== Trang mới đã bổ sung =====
import '../../modules/landing/landing_page.dart';     // landing cho web (trang chủ)
import '../../modules/admin/admin_app.dart';          // shell + sidebar admin
import '../../modules/auth/register_page.dart';       // đăng ký (sđt / gg / fb)
import '../../modules/auth/confirm_page.dart';        // xác nhận /auth/confirm

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

  // Auth (mới)
  static const register   = '/register';
  static const confirm    = '/auth/confirm'; // nhận token qua query

  // Admin (mới)
  static const admin          = '/admin';              // dashboard tổng quan
  static const adminUsers     = '/admin/users';
  static const adminPredict   = '/admin/predictions';
  static const adminNoti      = '/admin/notifications';
  static const adminSensors   = '/admin/sensors';

  // ✅ Các route cần đăng nhập (bảo vệ)
  static const _protected = {
    admin,
    adminUsers,
    adminPredict,
    adminNoti,
    adminSensors,
  };

  static Route<dynamic> onGenerate(RouteSettings s) {
    final name = s.name ?? '/';

    // Kiểm tra token (tương thích cả bearer và bearerToken tuỳ bạn đặt)
    final bearer = (() {
      try {
        // tuỳ ApiBase của bạn; dùng cái nào đang có
        // ưu tiên ApiBase.bearer nếu đã dùng trước đó
        // ignore: unnecessary_null_comparison
        if (ApiBase.bearer != null && (ApiBase.bearer as String).isNotEmpty) {
          return ApiBase.bearer as String;
        }
      } catch (_) {}
      try {
        // nếu bạn có ApiBase.bearerToken thì dùng ở đây
        // ignore: unnecessary_null_comparison
        if (ApiBase.bearerToken != null &&
            (ApiBase.bearerToken as String).isNotEmpty) {
          return ApiBase.bearerToken as String;
        }
      } catch (_) {}
      return '';
    })();

    // Nếu route thuộc protected & chưa có token → ép về /login, kèm “returnTo”
    if (_protected.contains(name) && bearer.isEmpty) {
      return _p(
        kIsWeb ? const LoginWebPage() : const LoginMobilePage(),
        arguments: name, // để Login nhận biết quay lại route này sau khi đăng nhập
      );
    }

    switch (name) {
      // ===== Trang chủ: dùng LandingPage cho WEB, giữ HomeMobile cho mobile =====
      case home:
        return _p(kIsWeb ? const LandingPage() : const HomeMobilePage());

      // ===== App hiện có =====
      case detect:   return _p(kIsWeb ? const DetectWebPage()   : const DetectMobilePage());
      case device:   return _p(kIsWeb ? const DeviceWebPage()   : const DeviceMobilePage());
      case sensors:  return _p(kIsWeb ? const SensorsWebPage()  : const SensorsMobilePage());
      case login:    return _p(kIsWeb ? const LoginWebPage()    : const LoginMobilePage());

      // ===== Navbar hiện có =====
      case library:  return _p(const LibraryWebPage());
      case news:     return _p(const NewsWebPage());
      case company:  return _p(const CompanyWebPage());
      case app:      return _p(const AppDownloadWebPage());

      // ===== Auth mới =====
      case register: return _p(const Scaffold(
        body: SafeArea(child: Center(child: SizedBox(width: 520, child: RegisterPage()))),
      ));
      case confirm:  return _p(const Scaffold(
        body: SafeArea(child: ConfirmPage()),
      ));

      // ===== Admin: dùng 1 shell, truyền route để chọn tab ban đầu =====
      case admin:
      case adminUsers:
      case adminPredict:
      case adminNoti:
      case adminSensors:
        return _p(AdminApp(initialRoute: name));

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('404: $name')),
          ),
        );
    }
  }

  static MaterialPageRoute _p(Widget w, {Object? arguments}) =>
      MaterialPageRoute(builder: (_) => w, settings: RouteSettings(arguments: arguments));
}
