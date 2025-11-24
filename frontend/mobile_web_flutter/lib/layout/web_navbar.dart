import 'package:flutter/material.dart';
import '../src/routes/web_routes.dart';
import '../core/api_base.dart';
import '../core/user_service.dart';

class WebNavbar extends StatefulWidget {
  const WebNavbar({super.key});

  @override
  State<WebNavbar> createState() => _WebNavbarState();
}

class _WebNavbarState extends State<WebNavbar> {
  bool _isAdmin = false;
  bool _isLoggedIn = false;    // giữ nhưng không dùng auth hiển thị

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    if (!mounted) return;

    final hasToken = ApiBase.bearerToken != null && ApiBase.bearerToken!.isNotEmpty;

    if (hasToken) {
      _isLoggedIn = true;
      try {
        _isAdmin = await UserService.isAdmin();
      } catch (e) {
        _isAdmin = false;
        _isLoggedIn = false;
      }
    } else {
      _isLoggedIn = false;
      _isAdmin = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

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
          InkWell(
            onTap: () => Navigator.pushNamed(context, WebRoutes.home),
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.green, size: 30),
                const SizedBox(width: 8),
                Text(
                  'PlantGuard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.green.shade700),
                ),
              ],
            ),
          ),

          const Spacer(),

          Wrap(
            spacing: 8,
            children: [
              _navItem(context, 'Trang chủ', WebRoutes.home),
              _navItem(context, 'Thời tiết', WebRoutes.weather),
              _navItem(context, 'Tin tức', WebRoutes.news),
              _navItem(context, 'Liên hệ', WebRoutes.company),
    
              if (_isAdmin)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, WebRoutes.admin);
                  },
                  icon: const Icon(Icons.admin_panel_settings, size: 18),
                  label: const Text('Admin'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                  ),
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
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
    );
  }
}
