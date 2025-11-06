import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';

class NewsWebPage extends StatelessWidget {
  const NewsWebPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const ShellWeb(
      body: Center(child: Text('Tin tức – yêu cầu đăng nhập')),
    );
  }
}
