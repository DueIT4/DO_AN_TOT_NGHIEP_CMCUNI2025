// lib/modules/auth/login_web.dart
import 'package:flutter/material.dart';
import 'login_content.dart';

class LoginWebPage extends StatelessWidget {
  const LoginWebPage({super.key});

  @override
  Widget build(BuildContext context) {
    final returnTo = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LoginContent(returnTo: returnTo),
          ),
        ),
      ),
    );
  }
}
