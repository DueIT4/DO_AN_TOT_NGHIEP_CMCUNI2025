import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';
import 'detect_content.dart';

class DetectWebPage extends StatelessWidget {
  const DetectWebPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellWeb(
      body: DetectContent(),
    );
  }
}