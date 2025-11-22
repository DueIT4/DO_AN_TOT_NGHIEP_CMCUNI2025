import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDownloadWebPage extends StatelessWidget {
  const AppDownloadWebPage({super.key});

  Future<void> _open(String link) async {
    final uri = Uri.parse(link);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Không mở được: $link';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tải ứng dụng')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _open('https://example.com/download'),
          child: const Text('Mở trang tải app'),
        ),
      ),
    );
  }
}
