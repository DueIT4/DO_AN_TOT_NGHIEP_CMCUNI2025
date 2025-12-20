// lib/modules/misc/news_content.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class NewsContent extends StatefulWidget {
  const NewsContent({super.key});

  @override
  State<NewsContent> createState() => _NewsContentState();
}

class _NewsContentState extends State<NewsContent> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _articles = [];

  // 🔑 API KEY tin tức
  static const String _apiKey = '3f5dbba4289b4bf68dcbbdd80468c064';

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Ưu tiên tìm tin nông nghiệp tiếng Việt
      final agriVi = await _fetchNews(
        query:
            '"nông nghiệp" OR "nông dân" OR "trồng trọt" OR "cây trồng" OR "nông sản"',
        language: 'vi',
      );
      if (agriVi.isNotEmpty) {
        setState(() {
          _articles = agriVi;
          _loading = false;
        });
        return;
      }

      // Nếu không có → tìm toàn cầu
      final agriGlobal =
          await _fetchNews(query: 'agriculture OR farming OR crops');
      if (agriGlobal.isNotEmpty) {
        setState(() {
          _articles = agriGlobal;
          _loading = false;
        });
        return;
      }

      // Nếu không có gì → fallback
      setState(() {
        _articles = _defaultArticles();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _articles = _defaultArticles();
        _loading = false;
        _error = 'Đang hiển thị dữ liệu dự phòng do lỗi API.';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchNews({
    required String query,
    String? language,
  }) async {
    final url =
        'https://newsapi.org/v2/everything?q=$query&pageSize=10&sortBy=publishedAt&apiKey=$_apiKey'
        '${language != null ? '&language=$language' : ''}';

    final res = await http.get(Uri.parse(url));

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    if (data['status'] != 'ok') return [];

    final List items = data['articles'] ?? [];

    return items.map<Map<String, dynamic>>((a) {
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
        'title': 'Xu hướng nông nghiệp thông minh tại Việt Nam 2025',
        'description':
            'AI, IoT và chuyển đổi số đang thay đổi hệ thống sản xuất nông nghiệp.',
        'url': '',
        'imageUrl': null,
        'source': 'Tổng hợp',
        'publishedAt': '2025-01-01T08:00:00Z',
      },
      {
        'title': 'Giải pháp tiết kiệm nước mùa khô',
        'description': 'Ứng dụng kỹ thuật tưới nhỏ giọt giúp giảm chi phí 30%.',
        'url': '',
        'imageUrl': null,
        'source': 'Khuyến Nông',
        'publishedAt': '2025-01-02T09:00:00Z',
      },
      {
        'title': 'Ứng dụng QR & blockchain trong truy xuất nguồn gốc',
        'description': 'Nâng cao sự minh bạch của chuỗi cung ứng nông sản.',
        'url': '',
        'imageUrl': null,
        'source': 'Nông Nghiệp Số',
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
                Icon(Icons.agriculture, size: 32, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Text(
                  'Tin tức nông nghiệp',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.orange.shade400),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadNews,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
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
                          article: _articles[i], formatTime: _formatTime),
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
    final link = article['url'] ?? '';
    if (link.isEmpty) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  imageUrl,
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
                    article['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article['description'] ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatTime(article['publishedAt']),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
