import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'firebase_options.dart';

// 🔐 AUTH + API
// import 'modules/auth/auth_service.dart'; // REMOVED: Admin-only
import 'services/api_client.dart';
import 'core/api_base_app.dart';

// 🌐 I18N
import 'l10n/app_localizations.dart';
import 'l10n/language_service.dart';

// 📷 CAMERA / STREAM
import 'core/camera_provider.dart';

// 🧭 UI
import 'ui/login_page.dart';
import 'ui/home_shell.dart';
import 'ui/forgot_password_page.dart';
import 'ui/verify_otp_page.dart';
import 'ui/reset_password_page.dart';
import 'ui/splash_page.dart'; // ✅ NEW

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZestGuardMobileApp());
}

class ZestGuardMobileApp extends StatelessWidget {
  const ZestGuardMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageService.instance,
      builder: (context, _) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CameraProvider()),
          ],
          child: MaterialApp(
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
              colorSchemeSeed: const Color(0xFF7CCD2B),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF7FBEF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),

            // 5️⃣ SỬ DỤNG SPLASH SCREEN ĐỂ KHỞI TẠO LOGIC
            home: const SplashPage(),

            routes: {
              '/login': (_) => const LoginPage(),
              '/home_user': (_) => const HomeShell(),
              '/forgot_password': (_) => const ForgotPasswordPage(),
              '/verify_otp': (_) => const VerifyOtpPage(),
              '/reset_password': (_) => const ResetPasswordPage(),
            },
          ),
        );
      },
    );
  }
}
