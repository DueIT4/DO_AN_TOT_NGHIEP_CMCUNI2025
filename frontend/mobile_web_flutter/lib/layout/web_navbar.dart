import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_base.dart';
import '../core/user_service.dart';
import '../src/routes/web_routes.dart';

class WebNavbar extends StatefulWidget {
  /// Giữ tương thích code cũ:
  /// - Nếu truyền currentIndex/onItemTap => hoạt động kiểu cũ (setState)
  /// - Nếu không truyền => hoạt động kiểu chuẩn web (context.go)
  final int? currentIndex;
  final void Function(int)? onItemTap;

  const WebNavbar({
    super.key,
    this.currentIndex,
    this.onItemTap,
  });

  @override
  State<WebNavbar> createState() => _WebNavbarState();
}

class _WebNavbarState extends State<WebNavbar> {
  bool _isAdmin = false;

  bool get _legacyMode => widget.currentIndex != null && widget.onItemTap != null;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final hasToken =
        ApiBase.bearerToken != null && ApiBase.bearerToken!.isNotEmpty;

    if (!hasToken) {
      if (mounted) setState(() => _isAdmin = false);
      return;
    }

    try {
      final ok = await UserService.isAdmin();
      if (mounted) setState(() => _isAdmin = ok);
    } catch (_) {
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  int _routeIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path == WebRoutes.weather) return 1;
    if (path == WebRoutes.news) return 2;
    return 0;
  }

  void _tapIndex(BuildContext context, int index) {
    if (_legacyMode) {
      // kiểu cũ: chỉ đổi nội dung
      widget.onItemTap!(index);
      return;
    }

    // kiểu chuẩn web: đổi URL
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final current = _legacyMode ? widget.currentIndex! : _routeIndex(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _tapIndex(context, 0),
            mouseCursor: SystemMouseCursors.click,
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.green, size: 30),
                const SizedBox(width: 8),
                Text(
                  'ZestGuard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            children: [
              _navItem(
                title: 'Trang chủ',
                active: current == 0,
                onTap: () => _tapIndex(context, 0),
              ),
              _navItem(
                title: 'Thời tiết',
                active: current == 1,
                onTap: () => _tapIndex(context, 1),
              ),
              _navItem(
                title: 'Tin tức',
                active: current == 2,
                onTap: () => _tapIndex(context, 2),
              ),
              if (_isAdmin)
                FilledButton.icon(
                  onPressed: () {
                    if (_legacyMode) {
                      // nếu đang legacy mode, vẫn cho đi admin bằng navigator stack cũ
                      // nhưng tốt nhất là chuyển sang go_router hết.
                      context.go(WebRoutes.adminDashboard);
                    } else {
                      context.go(WebRoutes.adminDashboard);
                    }
                  },
                  icon: const Icon(Icons.admin_panel_settings, size: 18),
                  label: const Text('Admin'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: active ? Colors.green.shade700 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
