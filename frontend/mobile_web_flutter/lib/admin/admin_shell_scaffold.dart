import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile_web_flutter/core/admin_me_service.dart';
import 'package:mobile_web_flutter/core/user_service.dart';
import 'package:mobile_web_flutter/modules/auth/auth_service.dart';
import 'package:mobile_web_flutter/admin/admin_profile_dialog.dart';
import 'package:mobile_web_flutter/core/api_base.dart';

const Color _adminGreen = Color(0xFF3D7A3B);

class AdminShellScaffold extends StatefulWidget {
  final Widget child;
  const AdminShellScaffold({super.key, required this.child});

  @override
  State<AdminShellScaffold> createState() => _AdminShellScaffoldState();
}

class _AdminShellScaffoldState extends State<AdminShellScaffold> {
  final AdminMeService _meService = AdminMeService();

  String get _title {
    final path = GoRouterState.of(context).uri.path;
    switch (path) {
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

  bool _isActive(String path) => GoRouterState.of(context).uri.path == path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context),
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
                        child: widget.child, // ✅ chỉ nội dung thay
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
  }

  Widget _buildSidebar(BuildContext context) {
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
                'PlantGuard Admin',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _adminGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Text('Tổng quan', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 8),
          _item(
            icon: Icons.dashboard_customize_outlined,
            label: 'Dashboard',
            active: _isActive('/admin/dashboard'),
            onTap: () => context.go('/admin/dashboard'),
          ),

          const SizedBox(height: 20),
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
            icon: Icons.support_agent_outlined,
            label: 'Hỗ trợ người dùng',
            active: _isActive('/admin/support'),
            onTap: () => context.go('/admin/support'),
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
                  if (mounted) setState(() {}); // refresh lại avatar sau khi đổi
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
void _showProfileDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AdminProfileDialog(service: _meService),
  );
}

  void _handleLogout(BuildContext context) async {
    await AuthService.logout();
    UserService.clearCache();
    context.go('/login');
  }
}
