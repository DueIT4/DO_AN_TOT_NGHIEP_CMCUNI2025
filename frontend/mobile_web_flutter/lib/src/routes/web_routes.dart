import 'package:flutter/material.dart';
import '../screens/home.dart';
import '../screens/detect.dart';
import '../screens/device.dart';
import '../screens/login.dart';
import '../screens/profile.dart';
import '../screens/signup.dart';
import '../screens/support.dart';
import '../screens/user.dart';

import '../screens/library.dart';
import '../screens/news.dart';
import '../screens/company.dart';
import '../screens/business.dart';
import '../screens/app_download.dart';

class WebRoutes {
  static const home = '/';
  static const detect = '/detect';
  static const device = '/device';
  static const login = '/login';
  static const signup = '/signup';
  static const profile = '/profile';
  static const support = '/support';
  static const user = '/user';
  static const app = '/app';
  static const library = '/library';
  static const news = '/news';
  static const company = '/company';
  static const business = '/business';

  static Route<dynamic> onGenerate(RouteSettings s) {
    switch (s.name) {
      case home:     return _p(const HomeScreen());
      case detect:   return _p(const DetectScreen());
      case device:   return _p(const DeviceScreen());
      case login:    return _p(const LoginScreen());
      case signup:   return _p(const SignupScreen());
      case profile:  return _p(const ProfileScreen());
      case support:  return _p(const SupportScreen());
      case user:     return _p(const UserScreen());
      case app:      return _p(const AppDownloadScreen());
      case library:  return _p(const LibraryScreen());
      case news:     return _p(const NewsScreen());
      case company:  return _p(const CompanyScreen());
      case business: return _p(const BusinessScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('404: ${s.name}')),
          ),
        );
    }
  }

  static MaterialPageRoute _p(Widget w) =>
      MaterialPageRoute(builder: (_) => w);
}
