import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_web_flutter/core/api_base.dart';

class NewsContent extends StatefulWidget {
  const NewsContent({super.key});

  @override
  State<NewsContent> createState() => _NewsContentState();
}

class _NewsContentState extends State<NewsContent> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _articles = [];
  static const String _cacheKey = 'agri_news_cache_v3';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await _loadCache();
    if (!mounted) return;

    if (cached.isNotEmpty) {
      setState(() {
        _articles = cached;
        _isLoading = false;
      });
    }

    // Luôn fetch data mới ngầm
    await _loadNews(silent: cached.isNotEmpty);
  }

  Future<void> _saveCache(List<Map<String, dynamic>> articles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(articles));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return [];
      final List decoded = jsonDecode(raw);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadNews({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    final news = await _fetchNews(
      query: '"nông nghiệp" OR "nông dân" OR "trồng trọt" OR "cây trồng" OR "nông sản"',
    );

    if (!mounted) return;

    if (news.isNotEmpty) {
      await _saveCache(news);
      setState(() {
        _articles = news;
        _isLoading = false;
      });
    } else {
      // Nếu API lỗi hoặc rỗng
      if (_articles.isEmpty) {
        setState(() {
           _articles = _defaultArticles(); // Dữ liệu giả nếu không có gì cả
           _isLoading = false;
        });
      }
      // Nếu đã có _articles (từ cache), giữ nguyên, không báo lỗi -> Silent Fail
    }
  }

  Future<List<Map<String, dynamic>>> _fetchNews({required String query}) async {
    try {
        String baseUrl = ApiBase.baseURL.endsWith('/') 
            ? ApiBase.baseURL.substring(0, ApiBase.baseURL.length - 1) 
            : ApiBase.baseURL;
        
        String apiPath = ApiBase.api('/news');
        if (!apiPath.startsWith('/')) apiPath = '/$apiPath';

        final uri = Uri.parse('$baseUrl$apiPath').replace(
          queryParameters: {
            'q': query,
            'lang': 'vi',
            'pageSize': '12', // Tăng page size cho đẹp layout lưới
          },
        );

        final res = await http.get(uri, headers: {
          'Content-Type': 'application/json',
           if (ApiBase.bearerToken != null) 'Authorization': 'Bearer ${ApiBase.bearerToken}',
        }).timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final List decoded = jsonDecode(utf8.decode(res.bodyBytes));
          return decoded.cast<Map<String, dynamic>>();
        }
        return [];
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> _defaultArticles() {
    return [
      {
        'title': 'Cục Bảo vệ Thực vật - Bộ NN&PTNT',
        'description': 'Cổng thông tin chính thức về kiểm dịch thực vật, quản lý thuốc BVTV và mã số vùng trồng quốc gia.',
        'url': 'https://www.ppd.gov.vn',
        'imageUrl': '', 
        'source': 'Chính phủ', // Trigger màu Xanh dương/Blue
        'publishedAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Tạp chí Nông nghiệp và Môi trường',
        'description': 'Cập nhật tin tức chuyên sâu về nông nghiệp xanh, bảo vệ môi trường và phát triển bền vững.',
        'url': 'https://nnmt.net.vn',
        'imageUrl': '',
        'source': 'Tạp chí', // Trigger màu Xanh lá/Green
        'publishedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        'title': 'Cộng đồng Nông nghiệp AgriViet',
        'description': 'Diễn đàn chia sẻ kỹ thuật trồng trọt, chăn nuôi và giá cả thị trường lớn nhất Việt Nam.',
        'url': 'https://agriviet.com',
        'imageUrl': '',
        'source': 'Cộng đồng', // Trigger màu Cam/Orange
        'publishedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
       {
        'title': 'Thần Nông - Bạn nhà nông',
        'description': 'Cẩm nang tra cứu sâu bệnh, kỹ thuật canh tác và dự báo thời tiết nông vụ chuẩn xác.',
        'url': 'https://thannong.net',
        'imageUrl': '',
        'source': 'Ứng dụng', // Trigger màu Tím/Indigo
        'publishedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    
    // Layout responsive
    int crossAxisCount = 1;
    if (width >= 600) crossAxisCount = 2;
    if (width >= 1100) crossAxisCount = 3;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 64 : 16,
        vertical: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          if (_isLoading && _articles.isEmpty)
             const Center(child: Padding(padding: EdgeInsets.all(64), child: CircularProgressIndicator()))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _articles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 24),
                        itemBuilder: (_, i) => _NewsCard(
                          article: _articles[i], 
                          isHorizontal: false, 
                          isBigCard: true, // Force Big Card style
                        ),
                      ),
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 32),
                      const Expanded(flex: 1, child: _SidebarLinks()),
                    ]
                  ],
                );
              }
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.newspaper, size: 28, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Tin Tức Nông Nghiệp',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cập nhật thông tin thị trường, kỹ thuật và xu hướng mới nhất',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final bool isHorizontal; // Cho mobile view dạng list
  final bool isBigCard; // Cho view demo to
  
  const _NewsCard({
    required this.article, 
    this.isHorizontal = false,
    this.isBigCard = false,
  });

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = article['imageUrl'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final url = Uri.tryParse(article['url'] ?? '');
          if (url != null && await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: isHorizontal 
            ? _buildHorizontalLayout(context, imageUrl, hasImage) 
            : _buildVerticalLayout(context, imageUrl, hasImage),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context, String? imageUrl, bool hasImage) {
    // LAYOUT TẠP CHÍ (Magazine Style) cho card to
    if (isBigCard) {
      // Xác định màu gradient dựa trên nguồn/chủ đề
      final source = (article['source'] ?? '').toString().toLowerCase();
      List<Color> gradientColors = [Colors.blue.shade900, Colors.blue.shade600]; // Default
      IconData bgIcon = Icons.article;

      if (source.contains('chính phủ') || article['title'].toString().toLowerCase().contains('cục')) {
        gradientColors = [const Color(0xFF1565C0), const Color(0xFF1976D2)]; // Blue (Chính phủ)
        bgIcon = Icons.account_balance;
      } else if (source.contains('tạp chí') || article['title'].toString().toLowerCase().contains('báo')) {
        gradientColors = [const Color(0xFF2E7D32), const Color(0xFF43A047)]; // Green (Báo chí)
        bgIcon = Icons.newspaper;
      } else if (source.contains('cộng đồng') || article['title'].toString().toLowerCase().contains('agriviet')) {
        gradientColors = [const Color(0xFFEF6C00), const Color(0xFFFFA726)]; // Orange (Cộng đồng)
        bgIcon = Icons.groups;
      } else {
        gradientColors = [const Color(0xFF4527A0), const Color(0xFF673AB7)]; // Purple (Thần Nông/Khác)
        bgIcon = Icons.smartphone;
      }

      return Container(
        height: 280,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            // Icon chìm trang trí
            Positioned(
              right: -20,
              bottom: -20,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(bgIcon, size: 180, color: Colors.white.withOpacity(0.15)),
              ),
            ),
            // Pattern chìm
            Positioned.fill(
              child: CustomPaint(
                painter: _DotPatternPainter(),
              ),
            ),
            // Nội dung
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        (article['source'] ?? 'TIN TỨC').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                   ),
                   const Spacer(),
                   Text(
                    article['title'] ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      fontFamily: 'Roboto', // Đảm bảo font đẹp nếu có
                    ),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     article['description'] ?? '',
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                     style: TextStyle(
                       color: Colors.white.withOpacity(0.9),
                       fontSize: 14,
                       height: 1.4,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Row(
                     children: [
                       Icon(Icons.calendar_today, size: 12, color: Colors.white.withOpacity(0.8)),
                       const SizedBox(width: 6),
                       Text(
                         _formatTime(article['publishedAt']),
                         style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                       ),
                       const Spacer(),
                       Text(
                         'Xem chi tiết',
                         style: TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.bold,
                           decoration: TextDecoration.underline,
                           decorationColor: Colors.white,
                         ),
                       ),
                       const SizedBox(width: 4),
                       Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                     ],
                   )
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Layout thẻ thường (Vertical nhỏ)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: hasImage
              ? Image.network(
                  imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderImage(),
                )
              : _placeholderImage(),
        ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSourceTag(context),
                const SizedBox(height: 8),
                Text(
                  article['title'] ?? 'Không có tiêu đề',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.3),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(article['publishedAt']),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(BuildContext context, String? imageUrl, bool hasImage) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: hasImage
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderImage(),
                )
              : _placeholderImage(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     _buildSourceTag(context),
                    const SizedBox(height: 6),
                    Text(
                      article['title'] ?? 'Không có tiêu đề',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(article['publishedAt']),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSourceTag(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        article['source'] ?? 'Tin tức',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey.shade100,
      width: double.infinity,
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade300, size: 40),
    );
  }
}

class _SidebarLinks extends StatelessWidget {
  const _SidebarLinks();
  @override
  Widget build(BuildContext context) {
    // Giữ nguyên logic links nhưng style lại đẹp hơn
    final links = [
      {'title': 'Cổng thông tin Bộ NN&PTNT', 'url': 'https://www.mard.gov.vn', 'color': Colors.blue},
      {'title': 'Tạp chí Nông nghiệp VN', 'url': 'https://nongnghiep.vn', 'color': Colors.green},
      {'title': 'Trung tâm Khuyến nông QG', 'url': 'https://khuyennongvn.gov.vn', 'color': Colors.orange},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Liên kết hữu ích', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        ...links.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async => await launchUrl(Uri.parse(e['url'] as String), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: (e['color'] as Color).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (e['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.link, size: 18, color: e['color'] as Color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e['title'] as String, style: const TextStyle(fontWeight: FontWeight.w500))),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < size.width; i += 20) {
      for (var j = 0; j < size.height; j += 20) {
        if ((i + j) % 40 == 0) {
          canvas.drawCircle(Offset(i.toDouble(), j.toDouble()), 2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
