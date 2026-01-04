import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'modules/auth/auth_service.dart';
import 'src/routes/app_router.dart'; 
import 'package:mobile_web_flutter/core/api_base.dart'; // ✅ Web version

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo Firebase cho Web
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Load biến môi trường (nếu cần thiết cho cấu hình API)
  try {
    //await dotenv.load(fileName: ".env");
  } catch (_) {
    // Nếu không có file .env ở local, có thể bỏ qua hoặc dùng giá trị mặc định
  }

  // 3. Khôi phục Token từ LocalStorage của trình duyệt
  // Bản Web Admin thường lưu token vào localStorage để giữ phiên làm việc
  await AuthService.restoreBearer();

  // 4. Cấu hình URL Backend (Cloud Run) cho bản Web
  // Nếu bạn đã có link Cloud Run, hãy set vào đây
  // ApiBase.setBaseURL = "https://zestguard-admin-api-xxx.a.run.app";
ApiBase.setBaseURL = "https://zestguard-api-38261474833.asia-southeast1.run.app";
  runApp(const ZestGuardWeb());
}

class ZestGuardWeb extends StatelessWidget {
  const ZestGuardWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZestGuard Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Tông màu xanh lá đậm chuyên dụng cho Admin Nông nghiệp
        colorSchemeSeed: const Color(0xFF2F6D3A), 
        scaffoldBackgroundColor: const Color(0xFFF8FAF8),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF2F6D3A),
          ),
        ),
        // Tối ưu hóa giao diện bảng biểu cho Web
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      // Sử dụng GoRouter hoặc hệ thống Router đã cấu hình cho Web
      routerConfig: appRouter, 
    );
  }
}
