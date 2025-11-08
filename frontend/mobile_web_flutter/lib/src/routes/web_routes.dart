import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/api_base.dart';

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

// các trang nội dung “tĩnh” tạm thời
import '../../modules/misc/library_web.dart';
import '../../modules/misc/company_web.dart';
import '../../modules/misc/news_web.dart';
import '../../modules/misc/app_download_web.dart';

class WebRoutes {
  static const home     = '/';
  static const detect   = '/detect';
  static const device   = '/device';
  static const sensors  = '/sensors';
  static const login    = '/login';

  // các tuyến bạn muốn có trên navbar
  static const library  = '/library';
  static const news     = '/news';
  static const company  = '/company';
  static const app      = '/app';

  // ✅ danh sách route cần đăng nhập mới vào được
  static const _protected = {
 
  };

  static Route<dynamic> onGenerate(RouteSettings s) {
    final name = s.name ?? '/';

    // Nếu route thuộc protected & chưa có token → ép về /login, kèm “returnTo”
    // if (_protected.contains(name) && (ApiBase.bearerToken == null || ApiBase.bearerToken!.isEmpty)) {
    //   return _p(
    //     kIsWeb ? const LoginWebPage() : const LoginMobilePage(),
    //     arguments: name, // giữ nguyên chuỗi tên route (có thể có query)
    //   );
    // }

    switch (name) {
      case home:    return _p(kIsWeb ? const HomeWebPage()    : const HomeMobilePage());
      case detect:  return _p(kIsWeb ? const DetectWebPage()  : const DetectMobilePage());
      case device:  return _p(kIsWeb ? const DeviceWebPage()  : const DeviceMobilePage());
      case sensors: return _p(kIsWeb ? const SensorsWebPage() : const SensorsMobilePage());
      case login:   return _p(kIsWeb ? const LoginWebPage()   : const LoginMobilePage());

      // các tuyến ở navbar (đã bảo vệ ở trên)
      case library: return _p(const LibraryWebPage());
      case news:    return _p(const NewsWebPage());
      case company: return _p(const CompanyWebPage());
      case app:     return _p(const AppDownloadWebPage());

      default:
        return MaterialPageRoute(builder: (_) => Scaffold(body: Center(child: Text('404: $name'))));
    }
  }

  static MaterialPageRoute _p(Widget w, {Object? arguments}) =>
      MaterialPageRoute(builder: (_) => w, settings: RouteSettings(arguments: arguments));
}
