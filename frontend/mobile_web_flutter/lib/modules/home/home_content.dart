import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_web_flutter/src/routes/web_routes.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // ===== HERO SECTION =====
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 80 : 20,
              vertical: isWide ? 80 : 40,
            ),
            color: Colors.white,
            child: isWide 
             ? _buildDesktopHero(context) 
             : _buildMobileHero(context),
          ),

          // ===== FEATURES SECTION =====
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 80 : 20,
              vertical: isWide ? 64 : 40,
            ),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: Column(
              children: [
                Text(
                  'Vì sao chọn ZestGuard?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Công nghệ AI tiên tiến đồng hành cùng nhà nông',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 48),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final cross = w >= 1100 ? 4 : w >= 800 ? 3 : w >= 600 ? 2 : 1;
                    return GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: cross,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 0.9,
                      children: const [
                        _FeatureCard(
                          icon: Icons.camera_enhance_rounded,
                          title: 'Chẩn đoán bằng ảnh',
                          desc: 'Chụp ảnh lá cây, AI sẽ phân tích và nhận diện bệnh chính xác ngay lập tức.',
                          color: Colors.blue,
                        ),
                        _FeatureCard(
                          icon: Icons.health_and_safety_rounded,
                          title: 'Giải pháp xử lý',
                          desc: 'Đề xuất biện pháp phòng trừ sâu bệnh hiệu quả, an toàn và thân thiện môi trường.',
                          color: Colors.green,
                        ),
                        _FeatureCard(
                          icon: Icons.library_books_rounded,
                          title: 'Thư viện tri thức',
                          desc: 'Kho kỹ thuật canh tác, chăm sóc cây trồng được cập nhật liên tục từ chuyên gia.',
                          color: Colors.orange,
                        ),
                        _FeatureCard(
                          icon: Icons.support_agent_rounded,
                          title: 'Hỗ trợ 24/7',
                          desc: 'Kết nối trực tiếp với các kỹ sư nông nghiệp để được tư vấn nhanh chóng.',
                          color: Colors.purple,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          
          // ===== CTA FOOTER =====
           Container(
             padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
             width: double.infinity,
             color: Colors.green.shade900,
             child: Column(
               children: [
                 const Text(
                   'Sẵn sàng bảo vệ mùa màng của bạn?',
                   textAlign: TextAlign.center,
                   style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                 ),
                 const SizedBox(height: 24),
                 FilledButton.icon(
                    onPressed: () async {
                      const url = 'https://play.google.com/store/apps/details?id=com.yourcompany.zestguard';
                      await launchUrl(Uri.parse(url));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    icon: const Icon(Icons.android),
                    label: const Text('Tải ứng dụng ngay'),
                 ),
               ],
             ),
           )
        ],
      ),
    );
  }

  // Desktop: Layout Row (Text - Image)
  Widget _buildDesktopHero(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroContent(context),
            ],
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          flex: 6,
          child: _buildHeroImage(),
        ),
      ],
    );
  }

  // Mobile: Layout Column (Image - Text)
  Widget _buildMobileHero(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
         _buildHeroImage(),
         const SizedBox(height: 48),
         _buildHeroContent(context, centered: true),
      ],
    );
  }

  Widget _buildHeroContent(BuildContext context, {bool centered = false}) {
    return Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
         Container(
           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
           decoration: BoxDecoration(
             color: Colors.green.shade50,
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: Colors.green.shade100),
           ),
           child: Text(
             '✨ Trợ lý nông nghiệp 4.0',
             style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
           ),
         ),
         const SizedBox(height: 24),
         Text(
          'Chẩn đoán bệnh cây trồng\nchính xác bằng AI',
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Giúp bà con nông dân phát hiện sớm sâu bệnh, tối ưu năng suất và giảm thiểu rủi ro với công nghệ nhận diện hình ảnh tiên tiến.',
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: () => context.go(WebRoutes.detect),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Dùng thử miễn phí'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                const url = 'https://play.google.com/store/apps/details?id=com.yourcompany.zestguard';
                await launchUrl(Uri.parse(url));
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.download),
              label: const Text('Tải App Android'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 20),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Ảnh Unsplash chất lượng cao: Nông dân dùng tablet/phone giữa đồng ruộng
      child: Image.network(
        'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?q=80&w=1000&auto=format&fit=crop',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          Text(
            desc, 
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }
}
