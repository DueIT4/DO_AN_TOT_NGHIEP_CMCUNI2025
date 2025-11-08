import 'package:flutter/material.dart';
import 'login_content.dart';

class LoginMobilePage extends StatelessWidget {
  const LoginMobilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final returnTo = ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(child: LoginContent(returnTo: returnTo)),
    );
  }
}
