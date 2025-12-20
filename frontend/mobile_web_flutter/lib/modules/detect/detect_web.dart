// lib/modules/detect/detect_web.dart

import 'package:flutter/material.dart';

import '../../layout/web_navbar.dart';
import '../../src/routes/web_routes.dart';
import 'detect_content.dart';
import 'package:go_router/go_router.dart';


class DetectWebPage extends StatelessWidget {
  const DetectWebPage({super.key});

  void _handleNavTap(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go(WebRoutes.home);
      break;
    case 1:
      context.go(WebRoutes.weather);
      break;
    case 2:
      context.go(WebRoutes.news);
      break;
    default:
      break;
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 🔼 Navbar giống các trang khác
          WebNavbar(
            currentIndex:
                -1, // không highlight tab nào vì Detect không có trong menu
            onItemTap: (index) => _handleNavTap(context, index),
          ),

          // 🔽 Nội dung detect
          const Expanded(
            child: DetectContent(),
          ),
        ],
      ),
    );
  }
}
