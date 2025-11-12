import 'package:flutter/material.dart';

enum AdminMenu { devices, notifications, users }

class AdminShellWeb extends StatelessWidget {
  final Widget body;
  final String title;
  final AdminMenu current;

  const AdminShellWeb({
    super.key,
    required this.body,
    required this.title,
    required this.current,
  });

  void _navigate(BuildContext context, AdminMenu menu) {
    switch (menu) {
      case AdminMenu.devices:
        Navigator.pushReplacementNamed(context, '/admin');
        break;
      case AdminMenu.notifications:
        Navigator.pushReplacementNamed(context, '/admin/notifications');
        break;
      case AdminMenu.users:
        Navigator.pushReplacementNamed(context, '/admin/users');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = AdminMenu.values.indexOf(current);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Row(
        children: [
          // Sidebar trái
          NavigationRail(
            extended: true,
            backgroundColor: scheme.surface,
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => _navigate(context, AdminMenu.values[i]),
            leading: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "PlantGuard Admin",
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.devices_outlined),
                selectedIcon: Icon(Icons.devices),
                label: Text('Thiết bị'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: Text('Thông báo'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                selectedIcon: Icon(Icons.people_alt),
                label: Text('Người dùng'),
              ),
            ],
          ),

          // Vùng nội dung
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(title),
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleTextStyle: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
