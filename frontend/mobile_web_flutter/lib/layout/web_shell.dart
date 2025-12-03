// lib/layout/web_shell.dart
import 'package:flutter/material.dart';

import '../modules/home/home_content.dart';
import '../modules/weather/weather_content.dart';
import '../modules/misc/news_content.dart';
import 'web_navbar.dart';

class WebShell extends StatefulWidget {
  final int initialIndex; // 👈 tab ban đầu: 0=Home, 1=Weather, 2=News

  const WebShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex; // 👈 lấy từ route
  }

  final List<Widget> _pages = const [
    HomeContent(),      // index 0: Trang chủ
    WeatherContent(),   // index 1: Thời tiết
    NewsContent(),      // index 2: Tin tức
  ];

  void _onItemTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          WebNavbar(
            currentIndex: _currentIndex,
            onItemTap: _onItemTap,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}
