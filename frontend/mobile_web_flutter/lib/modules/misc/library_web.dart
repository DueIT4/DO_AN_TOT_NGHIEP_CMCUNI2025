import 'package:flutter/material.dart';
import '../../layout/shell_web.dart';

class LibraryWebPage extends StatelessWidget {
  const LibraryWebPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const ShellWeb(
      body: Center(child: Text('Thư viện – yêu cầu đăng nhập')),
    );
  }
}
