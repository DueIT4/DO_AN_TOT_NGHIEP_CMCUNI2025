import 'package:flutter/material.dart';
import 'core/firebase_init.dart';
import 'src/routes/web_routes.dart';

/// ⚙️ Hàm main — khởi động ứng dụng PlantGuard Web
Future<void> main() async {
  // Đảm bảo Flutter binding sẵn sàng (cần thiết trước khi khởi tạo plugin)
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Khởi tạo Firebase (dành cho push notification, Firestore, analytics,...)
  await FirebaseInit.ensureInited();

  // Chạy ứng dụng chính
  runApp(const App());
}

/// 🌿 Lớp App — gốc của toàn bộ ứng dụng
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantGuard',
      debugShowCheckedModeBanner: false,

      // 🌈 Giao diện sử dụng Material 3 + màu chủ đạo xanh lá
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2F6D3A), // màu thương hiệu PlantGuard
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

      // 🏠 Trang bắt đầu (home page)
      initialRoute: WebRoutes.home,

      // 🧭 Quản lý route động (định nghĩa trong src/routes/web_routes.dart)
      onGenerateRoute: WebRoutes.onGenerate,
    );
  }
}
