// lib/main.dart
import 'package:flutter/material.dart';
//<<<<<<< HEAD
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'l10n/language_service.dart';
import 'ui/home_user.dart';
import 'ui/login_page.dart';
// =======
//import 'package:firebase_core/firebase_core.dart';
// >>>>>>> chi

import 'firebase_options.dart';
import 'src/routes/web_routes.dart';
import 'modules/auth/auth_service.dart'; // 👈 thêm import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase (web/android) bằng file firebase_options.dart đã tạo
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 👇 Khôi phục bearer đã lưu (nếu có) để F5 không bị mất đăng nhập
  await AuthService.restoreBearer();

  runApp(const App());
}

/// 🌿 App gốc
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
//<<<<<<< HEAD
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
// =======
//     return MaterialApp(
//       title: 'PlantGuard',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         colorSchemeSeed: const Color(0xFF2F6D3A),
//         scaffoldBackgroundColor: const Color(0xFFF8FAF8),
//         fontFamily: 'Roboto',
//         appBarTheme: const AppBarTheme(
//           elevation: 0,
//           backgroundColor: Colors.white,
//           foregroundColor: Colors.black87,
//           centerTitle: false,
//           titleTextStyle: TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 18,
//             color: Colors.black87,
//           ),
//         ),
//       ),
//       initialRoute: WebRoutes.home,
//       onGenerateRoute: WebRoutes.onGenerate,
// >>>>>>> chi
    );
  }
}
