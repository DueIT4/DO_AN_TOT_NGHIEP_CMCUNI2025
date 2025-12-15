import 'package:flutter/material.dart';
import 'web_shell.dart';

class PublicShellScaffold extends StatelessWidget {
  final Widget child;
  const PublicShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Giữ WebShell làm layout gốc; WebShell render child
    return WebShell(child: child);
  }
}
