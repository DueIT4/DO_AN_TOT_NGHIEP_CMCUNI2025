import 'package:flutter/material.dart';
import 'web_navbar.dart';

class WebShell extends StatelessWidget {
  final Widget child;
  const WebShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const WebNavbar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
