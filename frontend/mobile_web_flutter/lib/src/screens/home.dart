import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../routes/web_routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Link ngoài (đổi theo hệ thống của bạn)
  static const _playStore =
      'https://play.google.com/store/apps/details?id=com.yourcompany.plantguard';
  static const _appStore  = 'https://apps.apple.com/app/id0000000000';
  static const _email     = 'mailto:support@plantguard.com';
  static const _phone     = 'tel:+84123456789';

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _go(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ===== NAVBAR =====
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 80 : 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // logo + brand
                  Row(
                    children: [
                      const Icon(Icons.eco, color: Colors.green, size: 30),
                      const SizedBox(width: 8),
                      Text(
                        'PlantGuard',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // menu
                  Wrap(
                    spacing: 8,
                    children: [
                      _navItem(context, 'Ứng dụng', () => _go(context, WebRoutes.app)),
                      _navItem(context, 'Thư viện', () => _go(context, WebRoutes.library)),
                      _navItem(context, 'Tin tức', () => _go(context, WebRoutes.news)),
                      _navItem(context, 'Công ty', () => _go(context, WebRoutes.company)),
                      _navItem(context, 'Kinh doanh', () => _go(context, WebRoutes.business)),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _go(context, WebRoutes.app),
                        child: const Text('Tải ứng dụng'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ===== HERO =====
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 80 : 20,
                vertical: isWide ? 80 : 48,
              ),
              width: double.infinity,
              child: Column(
                crossAxisAlignment:
                    isWide ? CrossAxisAlignment.center : CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Ứng dụng MIỄN PHÍ số 1 để\nchẩn đoán và điều trị cây trồng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _go(context, WebRoutes.detect),
                        icon: const Icon(Icons.camera),
                        label: const Text('Dùng thử chẩn đoán'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openExternal(_playStore),
                        icon: const Icon(Icons.android),
                        label: const Text('Google Play'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openExternal(_appStore),
                        icon: const Icon(Icons.apple),
                        label: const Text('App Store'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Preview image (fallback nếu asset thiếu)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          'assets/images/app_preview.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) {
                            return Container(
                              color: Colors.green.withOpacity(.06),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'Unable to load asset: assets/images/app_preview.png\n'
                                'The asset does not exist or has empty data.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ===== FEATURES =====
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 80 : 20,
                vertical: isWide ? 56 : 32,
              ),
              child: Column(
                children: [
                  Text('Vì sao chọn PlantGuard?',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final cross = w >= 1100 ? 4 : w >= 800 ? 3 : w >= 600 ? 2 : 1;
                      return GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        crossAxisCount: cross,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 4 / 3,
                        children: const [
                          _FeatureCard(
                            icon: Icons.camera,
                            title: 'Chẩn đoán bằng ảnh',
                            desc: 'AI nhận diện bệnh đã huấn luyện.',
                          ),
                          _FeatureCard(
                            icon: Icons.science,
                            title: 'Hướng dẫn xử lý',
                            desc: 'Biện pháp an toàn, hiệu quả, thân thiện môi trường.',
                          ),
                          _FeatureCard(
                            icon: Icons.menu_book,
                            title: 'Thư viện tri thức',
                            desc: 'Tài liệu thực hành canh tác.',
                          ),
                          _FeatureCard(
                            icon: Icons.support_agent,
                            title: 'Kết nối chuyên gia',
                            desc: 'Tư vấn nhanh khi cần hỗ trợ.',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // ===== FOOTER =====
            Container(
              color: Colors.green.shade50,
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 80 : 20,
                vertical: 36,
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                          onPressed: () => _go(context, WebRoutes.company),
                          child: const Text('Công ty')),
                      TextButton(
                          onPressed: () => _go(context, WebRoutes.library),
                          child: const Text('Thư viện')),
                      TextButton(
                          onPressed: () => _go(context, WebRoutes.business),
                          child: const Text('Kinh doanh')),
                      TextButton(
                          onPressed: () => _openExternal(_email),
                          child: const Text('support@plantguard.com')),
                      TextButton(
                          onPressed: () => _openExternal(_phone),
                          child: const Text('0123-456-789')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2025 PlantGuard AI – All rights reserved',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureCard({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(desc, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
