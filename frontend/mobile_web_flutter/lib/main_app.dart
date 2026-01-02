// lib/main_app.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'modules/auth/auth_service.dart';

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
  // Đảm bảo các plugin Flutter đã được liên kết
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase (Cho Google Login/Push Notifications)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Khôi phục phiên đăng nhập cũ từ SharedPreferences/SecureStorage
  // Stateless Auth: Chỉ cần Token là đủ để làm việc với Cloud Run
  await AuthService.restoreBearer();
  await ApiClient.restoreToken();

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
            // Cung cấp trạng thái Camera cho toàn bộ ứng dụng (HLS Streaming)
            ChangeNotifierProvider(create: (_) => CameraProvider()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ZestGuard',
            // Quản lý ngôn ngữ (Vi/En)
            locale: LanguageService.instance.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Theme tối ưu cho UI Nông nghiệp (Xanh lá)
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            // Logic điều hướng ban đầu
            home: ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty 
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