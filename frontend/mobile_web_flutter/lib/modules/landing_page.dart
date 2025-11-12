import 'package:flutter/material.dart';
import '../layout/shell_web.dart';
import 'home/home_content.dart';

/// Landing page cho web (trang chủ)
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellWeb(body: HomeContent());
  }
}

