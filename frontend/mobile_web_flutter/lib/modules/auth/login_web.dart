import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';
import 'login_content.dart';

class LoginWebPage extends StatelessWidget {
  const LoginWebPage({super.key});
  @override
  Widget build(BuildContext context) {
    final returnTo = ModalRoute.of(context)?.settings.arguments as String?;
    return ShellWeb(body: LoginContent(returnTo: returnTo));
  }
}
