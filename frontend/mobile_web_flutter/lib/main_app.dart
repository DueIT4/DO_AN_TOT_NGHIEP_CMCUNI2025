// lib/main_app.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'modules/auth/auth_service.dart';

import 'l10n/app_localizations.dart';
import 'l10n/language_service.dart';
import 'services/api_client.dart';

import 'ui/login_page.dart';
import 'ui/home_user.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
            colorSchemeSeed: const Color(0xFF7CCD2B),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF7FBEF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          home: const LoginPage(),
          routes: {
            '/home_user': (_) => const HomeUserPage(),
          },
        );
      },
    );
  }
}
