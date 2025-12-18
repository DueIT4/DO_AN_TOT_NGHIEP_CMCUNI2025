import 'package:flutter/material.dart';

import 'home_user.dart';
import 'camera_detection_page.dart';
import 'devices_page.dart';
import 'user_settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Cho phép các tab gọi: HomeShell.maybeOf(context)?.goToTab(x)
  static HomeShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

// ✅ Bỏ "_" để không còn private type trong public API
class HomeShellState extends State<HomeShell> {
  int _index = 0;

  void goToTab(int index) {
    if (!mounted) return;
    setState(() => _index = index);
  }

  final _tabs = const [
    HomeUserPage(),          // tab 0
    CameraDetectionPage(),   // tab 1
    DevicesPage(),           // tab 2
    UserSettingsPage(),      // tab 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: goToTab,
        selectedItemColor: const Color(0xFF7CCD2B),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.videocam_outlined), label: 'Camera'),
          BottomNavigationBarItem(icon: Icon(Icons.sensors_outlined), label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
