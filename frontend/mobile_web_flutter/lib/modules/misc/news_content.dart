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
  static const String _cacheKey = 'agri_news_cache_v4';

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
        'title': 'Nông nghiệp công nghệ cao: Hướng đi tất yếu',
        'description': 'Ứng dụng IoT và AI giúp tối ưu năng suất và giảm thiểu rủi ro cho nhà nông. Các mô hình nhà kính thông minh đang được nhân rộng.',
        'url': 'https://nongnghiep.vn',
        // Ảnh ruộng bậc thang/nông nghiệp Việt Nam
        'imageUrl': 'https://images.unsplash.com/photo-1536617637075-2d3279b6b22b?w=800&q=80', 
        'source': 'Gợi ý',
        'publishedAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'Giải pháp tưới tiêu thông minh tiết kiệm nước',
        'description': 'Hệ thống tưới nhỏ giọt tự động đang được áp dụng rộng rãi tại ĐBSCL, giúp tiết kiệm đến 40% lượng nước tưới.',
        'url': 'https://khuyennongvn.gov.vn',
        // Ảnh tưới tiêu
        'imageUrl': 'https://images.unsplash.com/photo-1622383563227-0440114a8520?w=800&q=80',
        'source': 'Gợi ý',
        'publishedAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'title': 'Xuất khẩu gạo Việt Nam lập kỷ lục mới',
        'description': 'Giá gạo xuất khẩu của Việt Nam tiếp tục tăng cao, khẳng định vị thế trên thị trường quốc tế.',
        'url': 'https://vtv.vn',
        // Ảnh gạo
        'imageUrl': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800&q=80',
        'source': 'Gợi ý',
        'publishedAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'title': 'Mô hình trồng rau sạch thủy canh tại nhà phố',
        'description': 'Xu hướng tự trồng rau sạch bằng phương pháp thủy canh đang thu hút nhiều hộ gia đình ở đô thị.',
        'url': 'https://dantri.com.vn',
        // Ảnh thủy canh
        'imageUrl': 'https://images.unsplash.com/photo-1556910103-1c02745a30bf?w=800&q=80',
        'source': 'Gợi ý',
        'publishedAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
       {
        'title': 'Cảnh báo sâu bệnh hại lúa mùa mưa',
        'description': 'Các chuyên gia khuyến cáo bà con nông dân cần chủ động phòng trừ rầy nâu và bệnh đạo ôn trong mùa mưa bão.',
        'url': 'https://baocantho.com.vn',
        // Ảnh cánh đồng lúa xanh
        'imageUrl': 'https://images.unsplash.com/photo-1611735341450-74d61e66ee62?w=800&q=80',
        'source': 'Gợi ý',
        'publishedAt': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      },
       {
        'title': 'Phát triển bền vững cây ăn trái đặc sản',
        'description': 'Nâng cao chất lượng và xây dựng thương hiệu cho trái cây đặc sản vùng miền để mở rộng thị trường tiêu thụ.',
        'url': 'https://nongnghiep.vn',
        // Ảnh trái cây
        'imageUrl': 'https://images.unsplash.com/photo-1601493700631-2b16ec4b4716?w=800&q=80',
        'source': 'Gợi ý',
        'publishedAt': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
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
                      child: crossAxisCount == 1 
                        ? ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _articles.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 24),
                            itemBuilder: (_, i) => _NewsCard(article: _articles[i], isHorizontal: true),
                          )
                        : GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _articles.length,
                            itemBuilder: (_, i) => _NewsCard(article: _articles[i]),
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
                    'Tin tức nông nghiệp',
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
  
  const _NewsCard({required this.article, this.isHorizontal = false});

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
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final url = Uri.tryParse(article['url'] ?? '');
          if (url != null && await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: isHorizontal ? _buildHorizontalLayout(context, imageUrl, hasImage) : _buildVerticalLayout(context, imageUrl, hasImage),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context, String? imageUrl, bool hasImage) {
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
