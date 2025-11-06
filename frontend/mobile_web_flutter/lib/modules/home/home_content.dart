import 'package:flutter/material.dart';

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
                  'Ứng dụng MIỄN PHÍ số 1 để\nchẩn đoán và điều trị cây trồng',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w800,
                    color: Colors.black87, height: 1.25,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/detect'),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Dùng thử chẩn đoán'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {}, // TODO: open store
                      icon: const Icon(Icons.android),
                      label: const Text('Google Play'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.apple),
                      label: const Text('App Store'),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
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
                              'Unable to load asset: assets/images/app_preview.png\nThe asset does not exist or has empty data.',
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
                Text('Vì sao chọn PlantGuard?', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final cross = w >= 1100 ? 4 : w >= 800 ? 3 : w >= 600 ? 2 : 1;
                    return GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: cross, crossAxisSpacing: 16,
                      mainAxisSpacing: 16, childAspectRatio: 4 / 3,
                      children: const [
                        _FeatureCard(icon: Icons.camera, title: 'Chẩn đoán bằng ảnh', desc: 'AI nhận diện bệnh đã huấn luyện.'),
                        _FeatureCard(icon: Icons.science, title: 'Hướng dẫn xử lý', desc: 'Biện pháp an toàn, hiệu quả, thân thiện môi trường.'),
                        _FeatureCard(icon: Icons.menu_book, title: 'Thư viện tri thức', desc: 'Tài liệu thực hành canh tác.'),
                        _FeatureCard(icon: Icons.support_agent, title: 'Kết nối chuyên gia', desc: 'Tư vấn nhanh khi cần hỗ trợ.'),
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

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureCard({required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, clipBehavior: Clip.antiAlias,
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
