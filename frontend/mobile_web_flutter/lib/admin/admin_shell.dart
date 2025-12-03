// lib/admin/admin_shell.dart

import 'package:flutter/material.dart';

import 'package:mobile_web_flutter/core/admin_me_service.dart';
import 'package:mobile_web_flutter/core/user_service.dart';
import 'package:mobile_web_flutter/src/routes/web_routes.dart';
import 'package:mobile_web_flutter/modules/auth/auth_service.dart';

// Các trang con admin
import 'package:mobile_web_flutter/modules/admin/dashboard/admin_dashboard_page.dart';
import 'package:mobile_web_flutter/modules/admin/device/admin_devices_page.dart';
import 'package:mobile_web_flutter/modules/admin/user/admin_users_page.dart';
import 'package:mobile_web_flutter/modules/admin/notifications/admin_notifications_page.dart';
import 'package:mobile_web_flutter/modules/admin/support/admin_support_page.dart';
import 'package:mobile_web_flutter/modules/admin/history/detection_history_page.dart';

/// Màu chủ đạo admin
const Color _adminGreen = Color(0xFF3D7A3B);

/// Các menu chính của admin
enum AdminMenu {
  dashboard,
  devices,
  users,
  notifications,
  detectionHistory,
  settings,
}

/// Khung layout admin dùng cho web – chỉ tạo **một shell**, body bên trong đổi theo menu
class AdminShellWeb extends StatefulWidget {
  final AdminMenu initial; // tab ban đầu

  const AdminShellWeb({
    super.key,
    required this.initial,
  });

  @override
  State<AdminShellWeb> createState() => _AdminShellWebState();
}

class _AdminShellWebState extends State<AdminShellWeb> {
  late AdminMenu _current;
  final AdminMeService _meService = AdminMeService();

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  // Đổi menu (chỉ đổi body, không đổi route)
  void _selectMenu(AdminMenu menu) {
    if (menu == _current) return;
    setState(() {
      _current = menu;
    });
  }

  String get _title {
    switch (_current) {
      case AdminMenu.dashboard:
        return 'Dashboard';
      case AdminMenu.devices:
        return 'Quản lý thiết bị';
      case AdminMenu.users:
        return 'Quản lý người dùng';
      case AdminMenu.notifications:
        return 'Hỗ trợ / Thông báo';
      case AdminMenu.detectionHistory:
        return 'Lịch sử dự đoán';
      case AdminMenu.settings:
        return 'Cài đặt hệ thống';
    }
  }

  Widget get _body {
    switch (_current) {
      case AdminMenu.dashboard:
        return const AdminDashboardPage();
      case AdminMenu.devices:
        return const AdminDevicesPage();
      case AdminMenu.users:
        return const AdminUsersPage();
      case AdminMenu.notifications:
        // bạn có 2 trang: Support & Notifications – có thể tuỳ chỉnh thêm nếu muốn
        return const AdminSupportPage(); // hoặc AdminNotificationsPage()
      case AdminMenu.detectionHistory:
        return const AdminDetectionHistoryPage();
      case AdminMenu.settings:
        // TODO: Tạo trang settings riêng sau
        return const Center(child: Text('Trang cài đặt hệ thống (TODO)'));
    }
  }

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
                        child: _body, // 🔑 chỉ body thay đổi theo _current
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

  // ===== Sidebar trái =====
  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFFEDF5E8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo + tên
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _adminGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: _adminGreen,
                  size: 28,
                ),
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

          // Nhóm: Tổng quan
          Text(
            'Tổng quan',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _sidebarItem(
            context: context,
            menu: AdminMenu.dashboard,
            icon: Icons.dashboard_customize_outlined,
            label: 'Dashboard',
          ),

          const SizedBox(height: 20),

          // Nhóm: Quản lý
          Text(
            'Quản lý',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _sidebarItem(
            context: context,
            menu: AdminMenu.devices,
            icon: Icons.sensors,
            label: 'Quản lý thiết bị',
          ),
          _sidebarItem(
            context: context,
            menu: AdminMenu.users,
            icon: Icons.group_outlined,
            label: 'Quản lý người dùng',
          ),
          _sidebarItem(
            context: context,
            menu: AdminMenu.notifications,
            icon: Icons.support_agent_outlined,
            label: 'Hỗ trợ người dùng',
          ),
          _sidebarItem(
            context: context,
            menu: AdminMenu.detectionHistory,
            icon: Icons.history,
            label: 'Lịch sử dự đoán',
          ),

          const SizedBox(height: 20),

          // Nhóm: Hệ thống
          Text(
            'Hệ thống',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _sidebarItem(
            context: context,
            menu: AdminMenu.settings,
            icon: Icons.settings_outlined,
            label: 'Cài đặt hệ thống',
          ),

          const Spacer(),

          Text(
            '© 2025 PlantGuard',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required BuildContext context,
    required AdminMenu menu,
    required IconData icon,
    required String label,
  }) {
    final bool isActive = _current == menu;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectMenu(menu), // 🔑 chỉ đổi state, không dùng Navigator
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? _adminGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.white : Colors.grey[800],
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? Colors.white : Colors.grey[900],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Top bar =====
  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            spreadRadius: 0,
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

          // Avatar + menu, dùng API /me/get_me
          FutureBuilder<AdminUserMe>(
            future: _meService.getMe(),
            builder: (context, snapshot) {
              final name = snapshot.data?.username ?? 'Admin';
              final email = snapshot.data?.email ?? 'admin@plantguard.local';

              return PopupMenuButton<String>(
                offset: const Offset(0, 40),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: Text('Thông tin cá nhân'),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Text('Đăng xuất'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'profile') {
                    _showProfileDialog(context);
                  } else if (value == 'logout') {
                    _handleLogout(context);
                  }
                },
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: _adminGreen,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ],
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
      builder: (_) {
        return AdminProfileDialog(service: _meService);
      },
    );
  }

  void _handleLogout(BuildContext context) async {
    await AuthService.logout();
    UserService.clearCache();

    Navigator.of(context).pushNamedAndRemoveUntil(
      WebRoutes.login,
      (route) => false,
    );
  }
}

/// ===== Dialog xem + cập nhật thông tin cá nhân admin =====

class AdminProfileDialog extends StatefulWidget {
  const AdminProfileDialog({super.key, required this.service});

  final AdminMeService service;

  @override
  State<AdminProfileDialog> createState() => _AdminProfileDialogState();
}

class _AdminProfileDialogState extends State<AdminProfileDialog> {
  AdminUserMe? _user;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _loadMe();
  }

  Future<void> _loadMe() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = await widget.service.getMe();
      if (!mounted) return;
      setState(() {
        _user = me;
        _usernameCtrl.text = me.username ?? '';
        _phoneCtrl.text = me.phone ?? '';
        _emailCtrl.text = me.email ?? '';
        _addressCtrl.text = me.address ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.service.updateMe(
        username: _usernameCtrl.text.trim().isEmpty
            ? null
            : _usernameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
      );
      if (!mounted) return;

      setState(() {
        _user = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thông tin cá nhân'),
      content: SizedBox(
        width: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_user?.roleType != null)
                    Text(
                      'Vai trò: ${_user!.roleType}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (_user?.status != null)
                    Text(
                      'Trạng thái: ${_user!.status}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
