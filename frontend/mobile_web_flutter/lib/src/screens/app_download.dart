import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDownloadScreen extends StatelessWidget {
  const AppDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaffoldStub(
      title: 'Tải ứng dụng PlantGuard',
      child: Wrap(
        spacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () => _open('https://play.google.com/store/apps/details?id=com.yourcompany.plantguard'),
            icon: const Icon(Icons.android),
            label: const Text('Google Play'),
          ),
          FilledButton.icon(
            onPressed: () => _open('https://apps.apple.com/app/id0000000000'),
            icon: const Icon(Icons.apple),
            label: const Text('App Store'),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _ScaffoldStub extends StatelessWidget {
  final String title; final Widget child;
  const _ScaffoldStub({required this.title, required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: child),
      )),
    );
  }
}
