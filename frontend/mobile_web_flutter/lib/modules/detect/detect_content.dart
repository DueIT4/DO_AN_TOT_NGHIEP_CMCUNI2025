import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import '../../core/api_base.dart';

class DetectContent extends StatefulWidget {
  const DetectContent({super.key});

  @override
  State<DetectContent> createState() => _DetectContentState();
}

class _DetectContentState extends State<DetectContent> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;
  Map<String, dynamic>? _apiJson;
  String? _error;

  static final String _detectPath = ApiBase.api('/detect');

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (file == null) return;

    _imageBytes = await file.readAsBytes();
    setState(() {
      _imageName = file.name;
      _error = null;
      _apiJson = null;
    });
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
      // VD: http://127.0.0.1:8000/api/v1/detect
      final uri = Uri.parse("${ApiBase.baseURL}${_detectPath}");

      final req = http.MultipartRequest("POST", uri);

      // Chỉ thêm header cần thiết (KHÔNG set Content-Type thủ công)
      if (ApiBase.bearerToken != null && ApiBase.bearerToken!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer ${ApiBase.bearerToken}';
      }

      // field "file" phải trùng với UploadFile = File(...)
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

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) {
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
          setState(() => _error = "Phản hồi không giống JSON Object.");
        }
      } else {
        setState(() {
          _error = "Lỗi server (${resp.statusCode}): ${resp.body}";
        });
      }
    } catch (e) {
      setState(() => _error = "Không thể kết nối: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                "🧠 Hệ thống chẩn đoán bệnh hại cây trồng PlantGuard",
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

              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text("Chọn ảnh từ thư viện"),
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
                Text(_error!, style: const TextStyle(color: Colors.red))
              else if (_apiJson != null)
                _buildResultCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Hiển thị kết quả: chỉ bệnh chính + độ tin cậy
  Widget _buildResultCard(ThemeData theme) {
    final root = Map<String, dynamic>.from(_apiJson ?? const {});

    final detectionsRaw = root['detections'] ?? [];
    final List<Map<String, dynamic>> detections = [
      for (final d in (detectionsRaw as List))
        Map<String, dynamic>.from(d as Map),
    ];

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
      final ca =
          ((a['confidence'] ?? a['conf']) as num?)?.toDouble() ?? 0.0;
      final cb =
          ((b['confidence'] ?? b['conf']) as num?)?.toDouble() ?? 0.0;
      return cb.compareTo(ca);
    });

    final best = detections.first;
    final mainDisease =
        (best['class_name'] ?? 'Không xác định').toString();
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
        ],
      ),
    );
  }
}
