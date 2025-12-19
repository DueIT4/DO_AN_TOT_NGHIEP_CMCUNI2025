import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsContent extends StatefulWidget {
  const NewsContent({super.key});

  @override
  State<NewsContent> createState() => _NewsContentState();
}

class _NewsContentState extends State<NewsContent> {
  bool _loading = true; // loading "hard" (khi chưa có data nào)
  String? _banner; // thông báo dạng banner (không che list)
  List<Map<String, dynamic>> _articles = [];

  // 🔑 API KEY tin tức
  static const String _apiKey = '3f5dbba4289b4bf68dcbbdd80468c064';

  // Cache key (localStorage trên Web)
  static const String _cacheKey = 'agri_news_cache_v2';

  // ❌ Chặn BBC (cả bbc.com, bbc.co.uk, m.bbc..., bbcvietnamese...)
  static const List<String> _blockedDomains = [
    'bbc.com',
    'bbc.co.uk',
    'bbcvietnamese.com',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// ✅ Mở trang: đọc cache trước (hiện ngay), rồi mới fetch cập nhật
  Future<void> _bootstrap() async {
    final cached = await _loadCache();
    if (!mounted) return;

    if (cached.isNotEmpty) {
      setState(() {
        _articles = cached;
        _loading = false; // có tin hiện ngay
        _banner = 'Đang hiển thị tin đã lưu, đang cập nhật tin mới...';
      });
    }

    // luôn cố gắng cập nhật tin mới
    await _loadNews();
  }

  Future<void> _saveCache(List<Map<String, dynamic>> articles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(articles));
    } catch (_) {
      // ignore cache error on web storage
    }
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

  Future<void> _loadNews() async {
    // Nếu hiện đang có dữ liệu rồi thì chỉ hiện banner "đang cập nhật"
    if (mounted && _articles.isNotEmpty) {
      setState(() {
        _banner = 'Đang cập nhật tin mới...';
      });
    } else {
      setState(() {
        _loading = true;
        _banner = null;
      });
    }

    try {
      // Tier A: tin nông nghiệp tiếng Việt (hẹp)
      final a = await _fetchNews(
        query:
            '"nông nghiệp" OR "nông dân" OR "trồng trọt" OR "cây trồng" OR "nông sản"',
        language: 'vi',
        excludeDomains: _blockedDomains,
      );

      if (a.isNotEmpty) {
        await _saveCache(a);
        if (!mounted) return;
        setState(() {
          _articles = a;
          _loading = false;
          _banner = null;
        });
        return;
      }

      // Tier B: tiếng Việt (rộng hơn để đỡ rỗng)
      final b = await _fetchNews(
        query:
            '"nông nghiệp" OR "nông sản" OR "khuyến nông" OR "giá nông sản" OR "hạn mặn" OR "sâu bệnh" OR "phân bón"',
        language: 'vi',
        excludeDomains: _blockedDomains,
      );

      if (b.isNotEmpty) {
        await _saveCache(b);
        if (!mounted) return;
        setState(() {
          _articles = b;
          _loading = false;
          _banner = null;
        });
        return;
      }

      // Tier C: tiếng Anh (nông nghiệp toàn cầu)
      final c = await _fetchNews(
        query: 'agriculture OR farming OR crops OR livestock',
        language: 'en',
        excludeDomains: _blockedDomains,
      );

      if (c.isNotEmpty) {
        await _saveCache(c);
        if (!mounted) return;
        setState(() {
          _articles = c;
          _loading = false;
          _banner = null;
        });
        return;
      }

      // Tier D: query siêu rộng (vẫn chặn BBC) - để tránh rỗng
      final d = await _fetchNews(
        query:
            'agriculture OR farming OR crops OR "nông nghiệp" OR "nông sản"',
        excludeDomains: _blockedDomains,
      );

      if (d.isNotEmpty) {
        await _saveCache(d);
        if (!mounted) return;
        setState(() {
          _articles = d;
          _loading = false;
          _banner = null;
        });
        return;
      }

      // Tier E: cache
      final cached = await _loadCache();
      if (cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _articles = cached;
          _loading = false;
          _banner =
              'Nguồn hiện tại tạm thời không có bài phù hợp. Đang hiển thị tin đã lưu.';
        });
        return;
      }

      // Tier F: default
      if (!mounted) return;
      setState(() {
        _articles = _defaultArticles();
        _loading = false;
        _banner = 'Đang hiển thị dữ liệu dự phòng.';
      });
    } catch (_) {
      // Nếu lỗi: ưu tiên cache trước, không che list
      final cached = await _loadCache();
      if (!mounted) return;

      if (cached.isNotEmpty) {
        setState(() {
          _articles = cached;
          _loading = false;
          _banner = 'Lỗi API. Đang hiển thị tin đã lưu.';
        });
      } else {
        setState(() {
          _articles = _defaultArticles();
          _loading = false;
          _banner = 'Lỗi API. Đang hiển thị dữ liệu dự phòng.';
        });
      }
    }
  }

  /// Fetch NewsAPI: encode query đúng + excludeDomains + timeout
  Future<List<Map<String, dynamic>>> _fetchNews({
    required String query,
    String? language,
    List<String>? excludeDomains,
  }) async {
    final params = <String, String>{
      'q': query,
      'pageSize': '10',
      'sortBy': 'publishedAt',
      'apiKey': _apiKey,
    };
    if (language != null) params['language'] = language;
    if (excludeDomains != null && excludeDomains.isNotEmpty) {
      params['excludeDomains'] = excludeDomains.join(',');
    }

    final uri = Uri.https('newsapi.org', '/v2/everything', params);

    final res = await http
        .get(uri)
        .timeout(const Duration(seconds: 8), onTimeout: () {
      // timeout => coi như rỗng
      return http.Response('{"status":"error"}', 408);
    });

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    if (data['status'] != 'ok') return [];

    final List items = data['articles'] ?? [];

    bool isBBC(dynamic a) {
      final url = (a['url'] ?? '').toString().toLowerCase();
      final src = (a['source']?['name'] ?? '').toString().toLowerCase();
      final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
      // chặn bằng host + từ khóa bbc
      if (src.contains('bbc')) return true;
      if (url.contains('bbc.')) return true;
      if (host.contains('bbc.')) return true;
      if (host.contains('bbcvietnamese')) return true;
      return false;
    }

    // ✅ Map + lọc BBC lần nữa cho chắc
    return items
        .where((a) => !isBBC(a))
        .map<Map<String, dynamic>>((a) {
      return {
        'title': a['title'] ?? '(Không có tiêu đề)',
        'description': a['description'] ?? '',
        'url': a['url'] ?? '',
        'imageUrl': a['urlToImage'],
        'source': a['source']?['name'] ?? '',
        'publishedAt': a['publishedAt'] ?? '',
      };
    }).toList();
  }

  List<Map<String, dynamic>> _defaultArticles() {
    return [
      {
        'title': 'Xu hướng nông nghiệp thông minh tại Việt Nam',
        'description': 'AI, IoT và chuyển đổi số đang thay đổi sản xuất nông nghiệp.',
        'url': '',
        'imageUrl': null,
        'source': 'Dữ liệu dự phòng',
        'publishedAt': '2025-01-01T08:00:00Z',
      },
      {
        'title': 'Giải pháp tiết kiệm nước mùa khô',
        'description': 'Ứng dụng tưới nhỏ giọt giúp giảm chi phí và ổn định năng suất.',
        'url': '',
        'imageUrl': null,
        'source': 'Dữ liệu dự phòng',
        'publishedAt': '2025-01-02T09:00:00Z',
      },
      {
        'title': 'Truy xuất nguồn gốc bằng QR trong nông sản',
        'description': 'Tăng minh bạch chuỗi cung ứng và niềm tin người tiêu dùng.',
        'url': '',
        'imageUrl': null,
        'source': 'Dữ liệu dự phòng',
        'publishedAt': '2025-01-03T10:00:00Z',
      },
    ];
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 20,
          vertical: isWide ? 40 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.agriculture,
                    size: 32, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Text(
                  'Tin tức nông nghiệp',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ Banner thông báo (không che list)
            if (_banner != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: Icon(Icons.info_outline,
                        color: Colors.orange.shade800),
                    title: Text(
                      _banner!,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                    trailing: TextButton.icon(
                      onPressed: _loadNews,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ),
                ),
              ),

            // ✅ Loading chỉ khi chưa có data
            if (_loading && _articles.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_articles.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có dữ liệu để hiển thị.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadNews,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tải lại'),
                    ),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _articles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _NewsCard(
                        article: _articles[i],
                        formatTime: _formatTime,
                      ),
                    ),
                  ),
                  if (isWide) const SizedBox(width: 24),
                  if (isWide) const Expanded(flex: 1, child: _SidebarLinks()),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> article;
  final String Function(String) formatTime;

  const _NewsCard({
    required this.article,
    required this.formatTime,
  });

  Future<void> _openUrl() async {
    final link = (article['url'] ?? '').toString();
    if (link.isEmpty) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = article['imageUrl'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _openUrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((article['source'] as String).isNotEmpty)
                    Text(
                      article['source'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    (article['title'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if ((article['description'] ?? '').toString().isNotEmpty)
                    Text(
                      (article['description'] ?? '').toString(),
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    formatTime((article['publishedAt'] ?? '').toString()),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SidebarLinks extends StatelessWidget {
  const _SidebarLinks();

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = [
      {
        'title': 'Cổng thông tin Bộ NN&PTNT',
        'subtitle': 'Nguồn tin chính thức',
        'url': 'https://www.mard.gov.vn',
      },
      {
        'title': 'Tạp chí Nông nghiệp VN',
        'subtitle': 'Phân tích chuyên sâu',
        'url': 'https://nongnghiep.vn',
      },
      {
        'title': 'Cẩm nang kỹ thuật',
        'subtitle': 'Kiến thức cho nông dân',
        'url': 'https://khuyennongvn.gov.vn',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Liên kết hữu ích',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...links.map(
          (e) => Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: Text(e['title']!, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                e['subtitle']!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              onTap: () => _openLink(e['url']!),
            ),
          ),
        ),
      ],
    );
  }
}
