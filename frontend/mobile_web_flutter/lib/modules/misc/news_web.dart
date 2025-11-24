import 'package:flutter/material.dart';

// Từ lib/modules/misc -> lên lib (../..) -> vào layout/web_navbar.dart
import '../../layout/web_navbar.dart';

// news_content.dart nằm cùng thư mục misc
import 'news_content.dart';

class NewsWeb extends StatelessWidget {
  const NewsWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(72),
        child: WebNavbar(),      // ✅ Thanh menu PlantGuard
      ),
      body: const NewsContent(), // ✅ Nội dung trang tin tức nông nghiệp
    );
  }
}
