import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_web_flutter/core/api_base.dart'; // Đảm bảo đúng path tới ApiBase của bạn

class NewsContent extends StatefulWidget {
  const NewsContent({super.key});

  @override
  State<NewsContent> createState() => _NewsContentState();
}

class _NewsContentState extends State<NewsContent> {
  bool _loading = true; 
  String? _banner; 
  List<Map<String, dynamic>> _articles = [];

  // Cache key (localStorage trên Web)
  static const String _cacheKey = 'agri_news_cache_v3';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Khởi tạo: Đọc cache trước để hiện nhanh, sau đó fetch từ Backend
  Future<void> _bootstrap() async {
    final cached = await _loadCache();
    if (!mounted) return;

    if (cached.isNotEmpty) {
      setState(() {
        _articles = cached;
        _loading = false;
        _banner = 'Đang hiển thị tin đã lưu, đang cập nhật tin mới...';
      });
    }

    await _loadNews();
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

  Future<void> _loadNews() async {
    if (mounted && _articles.isNotEmpty) {
      setState(() => _banner = 'Đang cập nhật tin mới...');
    } else {
      setState(() {
        _loading = true;
        _banner = null;
      });
    }

    // Gọi hàm fetch news từ Backend
    final news = await _fetchNews(
      query: '"nông nghiệp" OR "nông dân" OR "trồng trọt" OR "cây trồng" OR "nông sản"',
    );

    if (!mounted) return;

    if (news.isNotEmpty) {
      await _saveCache(news);
      setState(() {
        _articles = news;
        _loading = false;
        _banner = null;
      });
    } else {
      // Nếu BE lỗi/rỗng, giữ lại data cũ và báo lỗi nhẹ
      setState(() {
        _loading = false;
        if (_articles.isEmpty) {
          _articles = _defaultArticles();
          _banner = 'Không thể lấy tin mới. Đang hiện dữ liệu dự phòng.';
        } else {
          _banner = 'Lỗi kết nối. Đang hiển thị tin cũ.';
        }
      });
    }
  }

  /// HÀM QUAN TRỌNG NHẤT: Kết nối với FastAPI Backend thay vì NewsAPI trực tiếp
  Future<List<Map<String, dynamic>>> _fetchNews({required String query}) async {
    try {
      // 1. Lấy path từ ApiBase (đã bao gồm /api/v1)
      final String path = ApiBase.api('/news'); 
      final uri = Uri.parse('${ApiBase.baseURL}$path').replace(
        queryParameters: {
          'q': query,
          'lang': 'vi',
          'pageSize': '10',
        },
      );

      // 2. Gọi API qua HTTPS để tránh Mixed Content
      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (ApiBase.bearerToken != null) 'Authorization': 'Bearer ${ApiBase.bearerToken}',
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        // 3. Giải mã và trả về list articles (Backend đã lọc domain/keyword sạch)
        final List decoded = jsonDecode(utf8.decode(res.bodyBytes));
        return decoded.cast<Map<String, dynamic>>();
      }
      debugPrint("Backend News Error: ${res.statusCode}");
      return [];
    } catch (e) {
      debugPrint("Fetch News Exception: $e");
      return [];
    }
  }

  List<Map<String, dynamic>> _defaultArticles() {
    return [
      {
        'title': 'Xu hướng nông nghiệp thông minh tại Việt Nam',
        'description': 'AI, IoT và chuyển đổi số đang thay đổi sản xuất nông nghiệp.',
        'url': 'https://nongnghiep.vn',
        'imageUrl': null,
        'source': 'Dữ liệu dự phòng',
        'publishedAt': '2025-01-01T08:00:00Z',
      },
    ];
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return isoString; }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final scheme = Theme.of(context).colorScheme;

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
                Icon(Icons.agriculture, size: 32, color: scheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Tin tức nông nghiệp',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_banner != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.orange.shade800),
                    title: Text(_banner!, style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
                    trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _loadNews),
                  ),
                ),
              ),
            if (_loading && _articles.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
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
                      itemBuilder: (_, i) => _NewsCard(article: _articles[i], formatTime: _formatTime),
                    ),
                  ),
                  if (isWide) ...[const SizedBox(width: 24), const Expanded(flex: 1, child: _SidebarLinks())],
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
  const _NewsCard({required this.article, required this.formatTime});

  @override
  Widget build(BuildContext context) {
    final imageUrl = article['imageUrl'] as String?;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final url = Uri.parse(article['url'] ?? '');
          if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover, 
                errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey.shade200, child: const Icon(Icons.broken_image))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article['source'] ?? '', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(article['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(article['description'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Text(formatTime(article['publishedAt'] ?? ''), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
  @override
  Widget build(BuildContext context) {
    final links = [
      {'title': 'Cổng thông tin Bộ NN&PTNT', 'url': 'https://www.mard.gov.vn'},
      {'title': 'Tạp chí Nông nghiệp VN', 'url': 'https://nongnghiep.vn'},
      {'title': 'Cẩm nang kỹ thuật', 'url': 'https://khuyennongvn.gov.vn'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Liên kết hữu ích', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...links.map((e) => Card(
          child: ListTile(
            leading: const Icon(Icons.link, size: 18),
            title: Text(e['title']!, style: const TextStyle(fontSize: 12)),
            onTap: () async => await launchUrl(Uri.parse(e['url']!), mode: LaunchMode.externalApplication),
          ),
        )),
      ],
    );
  }
}