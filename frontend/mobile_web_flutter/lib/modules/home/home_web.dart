import 'package:flutter/material.dart';
import '../../layout/web_shell.dart';
import 'home_content.dart';

class HomeWebPage extends StatelessWidget {
  const HomeWebPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const WebShell(child: HomeContent());
  }
}