import 'package:flutter/material.dart';
import '../core/api_base.dart';

enum AdminMenu { dashboard, users, devices, notifications, logout }

class AdminShell extends StatelessWidget {
  final Widget body;
  final String title;
  final AdminMenu current;

  const AdminShell({
    super.key,
    required this.body,
    required this.title,
    required this.current,
  });

  void _navigate(BuildContext context, AdminMenu menu) {
    switch (menu) {
      case AdminMenu.dashboard:
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
        break;
      case AdminMenu.users:
        Navigator.pushReplacementNamed(context, '/admin/users');
        break;
      case AdminMenu.devices:
        Navigator.pushReplacementNamed(context, '/admin/devices');
        break;
      case AdminMenu.notifications:
        Navigator.pushReplacementNamed(context, '/admin/notifications');
        break;
      case AdminMenu.logout:
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              ApiBase.bearer = null;
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = AdminMenu.values.indexOf(current);
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // Sidebar trái - Menu quản lý
          Container(
            width: isWide ? 280 : 240,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header sidebar
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withOpacity(0.3),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PlantGuard",
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              "Admin Panel",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _MenuTile(
                        icon: Icons.dashboard_outlined,
                        selectedIcon: Icons.dashboard,
                        label: 'Dashboard',
                        isSelected: current == AdminMenu.dashboard,
                        onTap: () => _navigate(context, AdminMenu.dashboard),
                      ),
                      _MenuTile(
                        icon: Icons.people_outline,
                        selectedIcon: Icons.people,
                        label: 'Quản lý người dùng',
                        isSelected: current == AdminMenu.users,
                        onTap: () => _navigate(context, AdminMenu.users),
                      ),
                      _MenuTile(
                        icon: Icons.devices_outlined,
                        selectedIcon: Icons.devices,
                        label: 'Quản lý thiết bị',
                        isSelected: current == AdminMenu.devices,
                        onTap: () => _navigate(context, AdminMenu.devices),
                      ),
                      _MenuTile(
                        icon: Icons.notifications_outlined,
                        selectedIcon: Icons.notifications,
                        label: 'Thông báo',
                        isSelected: current == AdminMenu.notifications,
                        onTap: () => _navigate(context, AdminMenu.notifications),
                      ),
                      const Divider(height: 32, indent: 16, endIndent: 16),
                      _MenuTile(
                        icon: Icons.logout_outlined,
                        selectedIcon: Icons.logout,
                        label: 'Đăng xuất',
                        isSelected: false,
                        onTap: () => _navigate(context, AdminMenu.logout),
                        textColor: Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Vùng nội dung chính
          Expanded(
            child: Column(
              children: [
                // AppBar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // User info (có thể thêm sau)
                      IconButton(
                        icon: const Icon(Icons.account_circle),
                        onPressed: () {},
                        tooltip: 'Tài khoản',
                      ),
                    ],
                  ),
                ),

                // Body content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? textColor;

  const _MenuTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: scheme.primary.withOpacity(0.3), width: 1)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected
              ? scheme.primary
              : (textColor ?? Colors.grey[700]),
          size: 24,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? scheme.primary
                : (textColor ?? Colors.black87),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
