import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../layout/shell_web.dart';

class AppDownloadWebPage extends StatelessWidget {
  const AppDownloadWebPage({super.key});

  // TODO: đổi sang link thật của bạn
  static const String _playStore =
      'https://play.google.com/store/apps/details?id=com.yourcompany.plantguard';
  static const String _appStore  =
      'https://apps.apple.com/app/id0000000000';

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return ShellWeb(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 16,
              vertical: 40,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tải ứng dụng PlantGuard',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Theo dõi cảm biến tại vườn, chẩn đoán bệnh bằng AI và nhận thông báo ngay trên điện thoại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _open(_playStore),
                      icon: const Icon(Icons.android),
                      label: const Text('Google Play'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _open(_appStore),
                      icon: const Icon(Icons.apple),
                      label: const Text('App Store'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Bạn cũng có thể đăng nhập để dùng bản web ngay bây giờ.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
