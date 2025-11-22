import 'package:flutter/material.dart';
import '../src/routes/web_routes.dart';

class WebNavbar extends StatelessWidget {
  const WebNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: Colors.green, size: 30),
              const SizedBox(width: 8),
              Text('PlantGuard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.green.shade700)),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            children: [
              _navItem(context, 'Trang chủ', WebRoutes.home),
              _navItem(context, 'Thiết bị',   WebRoutes.device),
              _navItem(context, 'Chẩn đoán',  WebRoutes.detect),
              _navItem(context, 'Thư viện',   WebRoutes.library), // 🔐 cần login
              _navItem(context, 'Tin tức',    WebRoutes.news),    // 🔐 cần login
              _navItem(context, 'Liên hệ',    WebRoutes.company), // 🔐 cần login
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, WebRoutes.login),
                child: const Text('Đăng nhập'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, String title, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
      ),
    );
  }
}
