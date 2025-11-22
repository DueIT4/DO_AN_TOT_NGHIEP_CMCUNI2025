import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';

class CompanyWebPage extends StatelessWidget {
  const CompanyWebPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const ShellWeb(
      body: Center(child: Text('Liên hệ/Công ty – yêu cầu đăng nhập')),
    );
  }
}
