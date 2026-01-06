// lib/modules/detect/detect_content.dart

import 'dart:convert';
import 'dart:typed_data';

// *** chỉ dùng được trên Web, nếu app mobile dùng chung file này thì nên tách riêng
// *** chỉ dùng được trên Web, nếu app mobile dùng chung file này thì nên tách riêng
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:url_launcher/url_launcher.dart';

// *** nhớ thêm trong pubspec: uuid: ^4.2.2
import 'package:uuid/uuid.dart';

import 'package:mobile_web_flutter/core/api_base.dart';

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

  String? _clientKeyCache;
  static final String _detectPath = ApiBase.api('/detect');

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _ensureClientKey() async {
    if (_clientKeyCache != null && _clientKeyCache!.isNotEmpty) {
      return _clientKeyCache!;
    }
    final prefs = await SharedPreferences.getInstance();
    var key = prefs.getString('client_key');
    if (key == null || key.isEmpty) {
      key = const Uuid().v4();
      await prefs.setString('client_key', key);
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

      final clientKey = await _ensureClientKey();
      req.headers['X-Client-Key'] = clientKey;

      if (ApiBase.bearerToken != null && ApiBase.bearerToken!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer ${ApiBase.bearerToken}';
      }

      // *** Thêm tham số bật LLM ***
      req.fields['enable_llm'] = 'true';
      req.fields['language'] = 'vi'; 

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

      if (resp.statusCode == 429) {
        final bodyStr = utf8.decode(resp.bodyBytes);
        String message = "Bạn đã dùng hết lượt miễn phí hôm nay.";

        try {
          final decoded = jsonDecode(bodyStr);
          if (decoded is Map &&
              decoded['detail'] is Map &&
              (decoded['detail']['message'] is String)) {
            message = decoded['detail']['message'] as String;
          } else if (decoded is Map && decoded['detail'] is String) {
            message = decoded['detail'] as String;
          }
        } catch (_) {}

        if (!mounted) return;
        _showLimitDialog(message);
        return;
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          if (!mounted) return;
          setState(() => _apiJson = decoded);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              );
            }
          });
        } else {
          if (!mounted) return;
          setState(() => _error = "Phản hồi không hợp lệ.");
        }
      } else {
        if (!mounted) return;
        setState(() => _error = "Lỗi server (${resp.statusCode})");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Không thể kết nối máy chủ");
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showLimitDialog(String message) async {
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
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openDownloadLink();
            },
            child: const Text('TẢI APP'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDownloadLink() async {
    const url = "https://github.com/DueIT4/DO_AN_TOT_NGHIEP_CMCUNI2025/actions/runs/20697966778/artifacts/5018813027";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Màu chủ đạo
    final primaryColor = Colors.green.shade700;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Header
              Column(
                children: [
                  Text(
                    "Chẩn đoán bệnh cây trồng",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Sử dụng công nghệ AI tiên tiến để phát hiện bệnh sớm\nvà nhận tư vấn xử lý kịp thời.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Action Buttons (Restored Original Style)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Chọn ảnh từ thư viện"),
                     style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
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
              
              const SizedBox(height: 32),

              // Image Picker Area
              Center( // Căn giữa
                child: Container(
                  width: 500, // Giới hạn chiều ngang
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: _imageBytes == null 
                        ? Border.all(color: Colors.grey.shade300, width: 2)
                        : null,
                  ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                          height: 300,
                          width: double.infinity,
                        ),
                      )
                    : Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: Text("Chưa có ảnh được chọn", style: TextStyle(color: Colors.grey.shade400)),
                    ),
                  ),
              ),

              const SizedBox(height: 32),

              // Analyze Button (Original Style)
              FilledButton.icon(
                onPressed: _loading ? null : _analyze,
                icon: _loading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.analytics_outlined),
                label: Text(_loading ? "Đang phân tích..." : "Phân tích bệnh"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 48),

              // Error Message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade900))),
                    ],
                  ),
                ),

              // Result Section
              if (_apiJson != null) _buildResultCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade700),
              ),
              const SizedBox(width: 16),
              const Text(
                "Kết quả phân tích",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildAnalysisContent(context),
        ],
      ),
    );
  }

  Widget _buildAnalysisContent(BuildContext context) {
    final root = Map<String, dynamic>.from(_apiJson ?? const {});
    final detections = (root['detections'] as List?) ?? [];
    
    if (detections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text("Hình ảnh không hỗ trợ phân tích bệnh.", style: TextStyle(fontSize: 16)),
        ),
      );
    }

    // Sort confidence
    final validDetections = detections.map((e) => Map<String, dynamic>.from(e)).toList();
    validDetections.sort((a, b) {
      final ca = ((a['confidence'] ?? a['conf']) as num?)?.toDouble() ?? 0.0;
      final cb = ((b['confidence'] ?? b['conf']) as num?)?.toDouble() ?? 0.0;
      return cb.compareTo(ca);
    });

    final best = validDetections.first;
    final diseaseName = best['class_name'] ?? 'Không xác định';
    final confidence = ((best['confidence'] ?? best['conf']) as num?)?.toDouble() ?? 0.0;

    final llm = root['llm'] as Map<String, dynamic>?;
    final summary = llm?['disease_summary']?.toString();
    final instructions = llm?['care_instructions']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Result
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Bệnh được chẩn đoán", style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '$diseaseName'.toUpperCase(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${(confidence * 100).toStringAsFixed(1)}% tin cậy",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 13),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Info Sections
        if (summary != null)
          _buildInfoSection(Icons.info_outline, "Thông tin bệnh", summary),
        if (instructions != null)
          _buildInfoSection(Icons.medical_services_outlined, "Biện pháp xử lý", instructions),
      ],
    );
  }

  Widget _buildInfoSection(IconData icon, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(content, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
