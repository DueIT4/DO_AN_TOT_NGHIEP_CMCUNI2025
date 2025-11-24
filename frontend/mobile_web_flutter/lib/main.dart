// =============================
// pubspec.yaml (thêm các dependencies)
// =============================
// Copy các dòng dưới vào phần dependencies của pubspec.yaml rồi chạy `flutter pub get`


// =============================
// lib/main.dart
// =============================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'l10n/language_service.dart';
import 'ui/home_user.dart';
import 'ui/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZestGuardApp());
}

class ZestGuardApp extends StatelessWidget {
  const ZestGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageService.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ZestGuard',
          locale: LanguageService.instance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF7CCD2B), // xanh nút Đăng nhập
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF7FBEF), // nền ô input nhạt
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4EED6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4EED6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF7CCD2B), width: 1.2),
              ),
            ),
          ),
          home: const LoginPage(),
          routes: {
            '/home_user': (context) => const HomeUserPage(), // 👈 route đích
          },
        );
      },
    );
  }
}
