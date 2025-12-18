import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'login_content.dart';

class LoginWebPage extends StatelessWidget {
  const LoginWebPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Lấy returnTo từ query: /login?returnTo=/admin/support
    final returnTo =
        GoRouterState.of(context).uri.queryParameters['returnTo'];

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
