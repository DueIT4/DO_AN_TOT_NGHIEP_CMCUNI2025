import 'package:flutter/material.dart';
import 'web_navbar.dart';
import 'web_footer.dart';

class ShellWeb extends StatelessWidget {
  final Widget body;
  const ShellWeb({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const WebNavbar(),
          Expanded(child: body),
        ],
      ),
    );
  }
}