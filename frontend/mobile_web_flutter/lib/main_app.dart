import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'modules/auth/auth_service.dart';
import 'core/api_base.dart'; // Đảm bảo import file này

import 'l10n/app_localizations.dart';
import 'l10n/language_service.dart';
import 'services/api_client.dart';
import 'ui/forgot_password_page.dart';
import 'ui/verify_otp_page.dart';
import 'ui/reset_password_page.dart';

import 'ui/login_page.dart';
import 'ui/home_shell.dart';
import 'core/camera_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. THIẾT LẬP KẾT NỐI SERVER (BẮT BUỘC)
  // Dán link Cloud Run bạn vừa nhận được vào đây
  ApiBase.setBaseURL = "https://zestguard-api-38261474833.asia-southeast1.run.app";

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. KHÔI PHỤC TOKEN
  await AuthService.restoreBearer();
  await ApiClient.restoreToken();
  
  // Đồng bộ token sang ApiBase để các hàm getJson/postJson hoạt động
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
            title: 'ZestGuard Mobile',
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
              // Theme xanh nông nghiệp chuẩn của bạn
              colorSchemeSeed: const Color(0xFF7CCD2B),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF7FBEF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            // Logic điều hướng: Nếu có token thì vào thẳng Home
            home: (ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty)
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