import 'package:flutter/material.dart';
class LibraryScreen extends StatelessWidget { const LibraryScreen({super.key});
  @override Widget build(BuildContext context) => _stub('Thư viện', 'Tài liệu/FAQ/Blog…');
}
class _stub extends StatelessWidget {
  final String title; final String text;
  const _stub(this.title, this.text);
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: Center(child: Text(text)));
}
