import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';
import 'home_content.dart';

class HomeWebPage extends StatelessWidget {
  const HomeWebPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const ShellWeb(body: HomeContent());
  }
}
