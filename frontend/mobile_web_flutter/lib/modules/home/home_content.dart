import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 thêm import này
import 'package:go_router/go_router.dart';
import 'package:mobile_web_flutter/src/routes/web_routes.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
  
    return SingleChildScrollView(
      child: Column(
        children: [
          // ===== HERO =====
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 80 : 20,
              vertical: isWide ? 80 : 48,
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Ứng dụng MIỄN PHÍ \nchẩn đoán và điều trị cây trồng',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 24),

                // 👉 Nhóm nút hành động: Dùng thử chẩn đoán + Tải ngay
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                  onPressed: () => context.go(WebRoutes.detect),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Dùng thử chẩn đoán'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        // 👇 Mở link CH Play thật
                        const url =
                            'https://play.google.com/store/apps/details?id=com.yourcompany.zestguard';
                        // TODO: thay com.yourcompany.zestguard bằng packageId thật của bạn
                        await launchUrl(Uri.parse(url));
                      },
                      icon: const Icon(Icons.android),
                      label: const Text('Tải trên CH Play'),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Ảnh demo ứng dụng (đã đổi)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.green.shade50,
                              Colors.green.shade100,
                              Colors.lightGreen.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _DottedPatternPainter(),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Ảnh demo ứng dụng: chỉ ảnh, không khung gì cả
ClipRRect(
  borderRadius: BorderRadius.circular(16),
  child: Image.asset(
    'assets/images/zestguard_intro.jpg',
    width: isWide ? 900 : double.infinity,
    fit: BoxFit.cover,
  ),
),
const SizedBox(height: 24),

Text(
  'ZestGuard',
  style: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.green.shade900,
  ),
),
const SizedBox(height: 8),
Text(
  'Chẩn đoán bệnh cây trồng\nbằng AI thông minh',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 16,
    color: Colors.green.shade700,
    height: 1.5,
  ),
),
const SizedBox(height: 24),

Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _AppStoreBadge(
      icon: Icons.android,
      label: 'Tải trên CH Play',
      color: Colors.green,
      onTap: () async {
        const url =
            'https://play.google.com/store/apps/details?id=com.yourcompany.zestguard';
        await launchUrl(Uri.parse(url));


                                        },
                                      ),
                                      // 👇 Bỏ iOS (không dùng nữa)
                                      // const SizedBox(width: 16),
                                      // _AppStoreBadge(
                                      //   icon: Icons.apple,
                                      //   label: 'iOS',
                                      //   color: Colors.black87,
                                      // ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                Text(
                  'Vì sao chọn ZestGuard?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final cross = w >= 1100
                        ? 4
                        : w >= 800
                            ? 3
                            : w >= 600
                                ? 2
                                : 1;

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
                          desc:
                              'Biện pháp an toàn, hiệu quả, thân thiện môi trường.',
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
        ],
      ),
    );
  }
}

// ============================================================================
//  FEATURE CARD
// ============================================================================
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

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

// ============================================================================
//  APP BADGE (Android, có onTap mở CH Play)
// ============================================================================
class _AppStoreBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AppStoreBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  DOT PATTERN
// ============================================================================
class _DottedPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.shade200.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    const spacing = 40.0;
    const radius = 3.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
