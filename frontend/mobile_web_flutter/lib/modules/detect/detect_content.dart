// lib/modules/detect/detect_content.dart

import 'dart:convert';
import 'dart:typed_data';

// *** chỉ dùng được trên Web, nếu app mobile dùng chung file này thì nên tách riêng
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:url_launcher/url_launcher.dart';

// *** nhớ thêm trong pubspec: uuid: ^4.2.2
import 'package:uuid/uuid.dart';

import '../../core/api_base.dart';

class DetectContent extends StatefulWidget {
  const DetectContent({super.key});

  @override
  State<DetectContent> createState() => _DetectContentState();
}

class _DetectContentState extends State<DetectContent>
    with AutomaticKeepAliveClientMixin {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;
  Map<String, dynamic>? _apiJson;
  String? _error;

  // *** cache client key trong state
  String? _clientKeyCache;

  // Đường dẫn detect (ApiBase.api thường trả về path như /api/v1/detect)
  static final String _detectPath = ApiBase.api('/detect');

  @override
  bool get wantKeepAlive => true; // nếu sau này dùng trong IndexedStack thì giữ state

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ===========================================================
  // *** HÀM TẠO / LẤY CLIENT KEY (lưu trong localStorage)
  // ===========================================================
  String _ensureClientKey() {
    if (_clientKeyCache != null && _clientKeyCache!.isNotEmpty) {
      return _clientKeyCache!;
    }

    final storage = html.window.localStorage;
    var key = storage['client_key'];

    if (key == null || key.isEmpty) {
      key = const Uuid().v4();
      storage['client_key'] = key;
    }

    _clientKeyCache = key;
    return key;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _imageName = file.name;
        _error = null;
        _apiJson = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể chọn ảnh: $e';
      });
    }
  }

  Future<void> _analyze() async {
    if (_imageBytes == null) {
      setState(() => _error = "Vui lòng chọn ảnh trước.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _apiJson = null;
    });

    try {
      final uri = Uri.parse('${ApiBase.baseURL}$_detectPath');

      final req = http.MultipartRequest("POST", uri);

      // *** Lấy client_key và gắn vào header
      final clientKey = _ensureClientKey();
      req.headers['X-Client-Key'] = clientKey;

      if (ApiBase.bearerToken != null && ApiBase.bearerToken!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer ${ApiBase.bearerToken}';
      }

      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _imageBytes!,
          filename: _imageName ?? 'upload.jpg',
          contentType: http_parser.MediaType('image', 'jpeg'),
        ),
      );

      final streamedResp = await req.send();
      final resp = await http.Response.fromStream(streamedResp);

      // *** Hết lượt miễn phí (429)
      if (resp.statusCode == 429) {
        final bodyStr = utf8.decode(resp.bodyBytes);
        String message = "Bạn đã dùng hết lượt miễn phí hôm nay. Vui lòng tải ứng dụng để tiếp tục.";

        try {
          final decoded = jsonDecode(bodyStr);
          // kiểu {"detail": {"code": "LIMIT_REACHED", "message": "..."}}
          if (decoded is Map &&
              decoded['detail'] is Map &&
              (decoded['detail']['message'] is String)) {
            message = decoded['detail']['message'] as String;
          } else if (decoded is Map && decoded['detail'] is String) {
            message = decoded['detail'] as String;
          }
        } catch (_) {
          // ignore parse error, dùng message mặc định
        }

        // Hiện dialog buộc tải app
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Hết lượt miễn phí'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ĐÓNG'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openDownloadLink();
                },
                child: const Text('TẢI APP'),
              ),
            ],
          ),
        );

        // không set _apiJson, chỉ dừng lại
        return;
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          if (!mounted) return;
          setState(() => _apiJson = decoded);

          // scroll xuống kết quả
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            }
          });
        } else {
          if (!mounted) return;
          setState(() => _error = "Phản hồi không giống JSON Object.");
        }
      } else {
        if (!mounted) return;
        setState(() {
          _error = "Lỗi server (${resp.statusCode}): ${resp.body}";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Không thể kết nối: $e");
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openDownloadLink() async {
    // *** nhớ đổi sang link CH Play thật của bạn
    const url = "https://your-download-link.com/app.apk";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      setState(() {
        _error = 'Không mở được link tải ứng dụng.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // bắt buộc khi dùng AutomaticKeepAliveClientMixin

    final theme = Theme.of(context);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              const Text(
                "🧠 Hệ thống chẩn đoán bệnh hại cây trồng ZestGuard",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "Tải ảnh lá hoặc quả — hệ thống AI sẽ phân tích bệnh và gợi ý cách xử lý.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Chọn ảnh từ thư viện"),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _openDownloadLink,
                    icon: const Icon(Icons.download),
                    label: const Text("Tải App Ngay"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              if (_imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _imageBytes!,
                    width: 430,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: _loading ? null : _analyze,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text("Phân tích bệnh"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 14,
                  ),
                ),
              ),

              const SizedBox(height: 35),

              if (_loading)
                const CircularProgressIndicator()
              else if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                )
              else if (_apiJson != null)
                _buildResultCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Hiển thị kết quả: chỉ bệnh chính + độ tin cậy + tóm tắt & hướng dẫn từ LLM
  Widget _buildResultCard(ThemeData theme) {
    final root = Map<String, dynamic>.from(_apiJson ?? const {});

    final detectionsRaw = root['detections'] ?? [];
    final List<Map<String, dynamic>> detections = [
      for (final d in (detectionsRaw as List))
        Map<String, dynamic>.from(d as Map),
    ];

    final explanation = root['explanation']?.toString();
    final llm = root['llm'] as Map<String, dynamic>?;

    final diseaseSummary = llm?['disease_summary']?.toString();
    final careInstructions = llm?['care_instructions']?.toString();

    if (detections.isEmpty) {
      return Container(
        width: 760,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Text("Không phát hiện bệnh trên ảnh này."),
      );
    }

    // chọn detection có confidence cao nhất
    detections.sort((a, b) {
      final ca = ((a['confidence'] ?? a['conf']) as num?)?.toDouble() ?? 0.0;
      final cb = ((b['confidence'] ?? b['conf']) as num?)?.toDouble() ?? 0.0;
      return cb.compareTo(ca);
    });

    final best = detections.first;
    final mainDisease = (best['class_name'] ?? 'Không xác định').toString();
    final rawConf =
        ((best['confidence'] ?? best['conf']) as num?)?.toDouble() ?? 0.0;
    final confPercent = (rawConf * 100).toStringAsFixed(2);

    return Container(
      width: 760,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("🔎 Kết quả chẩn đoán", style: theme.textTheme.titleLarge),
          const Divider(),

          Text(
            "🌿 Bệnh chẩn đoán: $mainDisease",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text("📈 Độ tin cậy: $confPercent%"),
          const SizedBox(height: 16),

          if (diseaseSummary != null && diseaseSummary.isNotEmpty) ...[
            Text(
              "🧠 Tình trạng:",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              diseaseSummary,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
          ],

          if (careInstructions != null && careInstructions.isNotEmpty) ...[
            Text(
              "💊 Hướng dẫn chăm sóc:",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              careInstructions,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
          ],

          if (explanation != null && explanation.isNotEmpty) ...[
            Text(
              "📌 Ghi chú kỹ thuật:",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              explanation,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}
