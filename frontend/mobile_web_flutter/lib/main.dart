// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/routes/web_routes.dart';
import 'modules/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AuthService.restoreBearer();

  runApp(const App());
}
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2F6D3A),
        scaffoldBackgroundColor: const Color(0xFFF8FAF8),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
      ),
      // ❌ Đừng set initialRoute ở đây nữa
      // initialRoute: WebRoutes.home,

      // 👇 Chỉ giữ onGenerateRoute
      onGenerateRoute: WebRoutes.onGenerate,
    );
  }
}
