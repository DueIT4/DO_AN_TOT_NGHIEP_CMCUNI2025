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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// ===============================
  /// 1️⃣ BASE API – BẮT BUỘC (DEPLOY)
  /// ===============================
  // ApiBase.setBaseURL = ... (Đã được cấu hình cứng trong api_base_app.dart)

  /// ===============================
  /// 2️⃣ FIREBASE INIT
  /// ===============================
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// ===============================
  /// 3️⃣ FACEBOOK AUTH (OPTIONAL)
  /// ===============================
  try {
    await FacebookAuth.instance
        .webAndDesktopInitialize(
          appId: '1884651265804315',
          cookie: true,
          xfbml: true,
          version: 'v18.0',
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('⚠️ FacebookAuth init skipped: $e');
  }

  /// ===============================
  /// 4️⃣ RESTORE TOKEN (CỰC QUAN TRỌNG)
  /// ===============================
  // await AuthService.restoreBearer(); // REMOVED: Admin-only
  await ApiClient.restoreToken();

  // Đồng bộ token cho toàn hệ thống (API + stream)
  ApiBase.bearer = ApiClient.authToken;

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

            /// ===============================
            /// 5️⃣ ĐIỀU HƯỚNG THEO TOKEN
            /// ===============================
            home: (ApiClient.authToken != null &&
                    ApiClient.authToken!.isNotEmpty)
                ? const HomeShell()
                : const LoginPage(),

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
