import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile_web_flutter/services/admin/admin_me_service.dart';
import 'package:mobile_web_flutter/services/admin/user_service.dart';
import 'package:mobile_web_flutter/modules/auth/auth_service.dart';
import 'package:mobile_web_flutter/admin/admin_profile_dialog.dart';
import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/models/admin/admin_user_me.dart';

const Color _adminGreen = Color(0xFF3D7A3B);

class AdminShellScaffold extends StatefulWidget {
  final Widget child;
  const AdminShellScaffold({super.key, required this.child});

  @override
  State<AdminShellScaffold> createState() => _AdminShellScaffoldState();
}

class _AdminShellScaffoldState extends State<AdminShellScaffold> {
  final AdminMeService _meService = AdminMeService();

  String get _path => GoRouterState.of(context).uri.path;

  String get _title {
    switch (_path) {
      case '/admin/dashboard':
        return 'Dashboard';
      case '/admin/devices':
        return 'Quản lý thiết bị';
      case '/admin/users':
        return 'Quản lý người dùng';
      case '/admin/support':
        return 'Hỗ trợ người dùng';
      case '/admin/notifications':
        return 'Quản lý thông báo';
      case '/admin/history':
        return 'Lịch sử dự đoán';
      default:
        return 'Admin';
    }
  }

  bool _isActive(String path) => _path == path;

  // ===== Quy tắc theo role (đúng theo yêu cầu của bạn) =====
  bool _canAccessSupportPage(String role) {
    final r = role.toLowerCase();
    return r == 'support' || r == 'admin';
  }

  bool _canAccessAdminAreaExceptSupport(String role) {
    final r = role.toLowerCase();
    return r == 'admin';
  }

  bool _isViewer(String role) => role.toLowerCase() == 'viewer';

  /// Trang "an toàn" để chuyển hướng theo role
  String _homeForRole(String role) {
    final r = role.toLowerCase();
    if (r == 'support') return '/admin/support';
    if (r == 'support_admin' || r == 'admin') return '/admin/dashboard';
    // viewer hoặc unknown -> login
    return '/login';
  }

  /// Kiểm tra route hiện tại có hợp lệ với role không
  bool _isAllowedPathForRole(String role, String path) {
    final r = role.toLowerCase();

    // viewer: không cho vào admin
    if (r == 'viewer') return false;

    // support: chỉ support page
    if (r == 'support') return path == '/admin/support';

    // support_admin: tất cả trừ support
    if (r == 'support_admin') return path != '/admin/support';

    // admin: tất cả
    if (r == 'admin') return true;

    // role không rõ: chặn
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Nếu chưa login thì đá về login luôn (tránh gọi API dashboard gây 401 log)
    if (!AuthService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: UserService.getRoleType(),
      builder: (context, snap) {
        // đang load role: vẫn render skeleton nhẹ để không giật
        final role = (snap.data ?? '').trim();

        // Nếu không lấy được role (null/empty) thì coi như chưa xác định -> đẩy về login
        if (snap.connectionState == ConnectionState.done && role.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/login');
          });
          return const SizedBox.shrink();
        }

        // Khi đã có role: nếu vào sai route => redirect về route hợp lệ theo role
        if (role.isNotEmpty && !_isAllowedPathForRole(role, _path)) {
          final to = _homeForRole(role);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(to);
          });
        }

        // viewer: không render admin shell
        if (role.isNotEmpty && _isViewer(role)) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          body: Row(
            children: [
              _buildSidebar(context, role),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF3F6F2),
                        padding: const EdgeInsets.all(24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Material(
                            elevation: 0,
                            color: Colors.white,
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, String role) {
    final r = role.toLowerCase();

    // Quyền theo role
    final showSupport = role.isNotEmpty && _canAccessSupportPage(r);
    final showAdminExceptSupport = role.isNotEmpty && _canAccessAdminAreaExceptSupport(r);

    return Container(
      width: 240,
      color: const Color(0xFFEDF5E8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _adminGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.eco_rounded, color: _adminGreen, size: 28),
              ),
              const SizedBox(width: 10),
              const Text(
                'ZestGuard',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _adminGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ===== Dashboard (chỉ admin/support_admin) =====
          if (showAdminExceptSupport) ...[
            Text('Tổng quan', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(height: 8),
            _item(
              icon: Icons.dashboard_customize_outlined,
              label: 'Dashboard',
              active: _isActive('/admin/dashboard'),
              onTap: () => context.go('/admin/dashboard'),
            ),
            const SizedBox(height: 20),
          ],

          // ===== Quản lý (admin/support_admin) =====
          if (showAdminExceptSupport) ...[
            Text('Quản lý', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(height: 8),
            _item(
              icon: Icons.sensors,
              label: 'Quản lý thiết bị',
              active: _isActive('/admin/devices'),
              onTap: () => context.go('/admin/devices'),
            ),
            _item(
              icon: Icons.group_outlined,
              label: 'Quản lý người dùng',
              active: _isActive('/admin/users'),
              onTap: () => context.go('/admin/users'),
            ),
            _item(
              icon: Icons.campaign_outlined,
              label: 'Quản lý thông báo',
              active: _isActive('/admin/notifications'),
              onTap: () => context.go('/admin/notifications'),
            ),
            _item(
              icon: Icons.history,
              label: 'Lịch sử dự đoán',
              active: _isActive('/admin/history'),
              onTap: () => context.go('/admin/history'),
            ),
          ],

          // ===== Hỗ trợ (support/admin) =====
          if (showSupport) ...[
            const SizedBox(height: 20),
            Text('Hỗ trợ', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(height: 8),
            _item(
              icon: Icons.support_agent_outlined,
              label: 'Hỗ trợ người dùng',
              active: _isActive('/admin/support'),
              onTap: () => context.go('/admin/support'),
            ),
          ],

          const Spacer(),
          Text('© 2025 PlantGuard', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: active ? _adminGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: active ? Colors.white : Colors.grey[800]),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Colors.white : Colors.grey[900],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            offset: Offset(0, 1),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _adminGreen,
            ),
          ),
          const Spacer(),
          FutureBuilder<AdminUserMe>(
            future: _meService.getMe(),
            builder: (context, snapshot) {
              final avt = snapshot.data?.avtUrl;
              final fullAvtUrl = (avt != null && avt.isNotEmpty)
                  ? '${ApiBase.baseURL}$avt?v=${DateTime.now().millisecondsSinceEpoch}'
                  : null;

              final provider = fullAvtUrl != null ? NetworkImage(fullAvtUrl) : null;

              return PopupMenuButton<String>(
                offset: const Offset(0, 40),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'profile', child: Text('Thông tin cá nhân')),
                  PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
                ],
                onSelected: (value) async {
                  if (value == 'profile') {
                    await showDialog(
                      context: context,
                      builder: (_) => AdminProfileDialog(service: _meService),
                    );
                    if (mounted) setState(() {});
                  } else if (value == 'logout') {
                    _handleLogout(context);
                  }
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _adminGreen,
                  backgroundImage: provider,
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (provider == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    await AuthService.logout();
    UserService.clearCache();
    context.go('/login');
  }
}
