import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});
  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;
  Map<String, dynamic>? _apiJson;
  String? _error;

  // ===== Backend config =====
  // ⚠️ Mobile emulator:
  //   - Android emulator: http://10.0.2.2:8000
  //   - iOS simulator:   http://127.0.0.1:8000
  //   - Device thật:     http://<IP_LAN_PC>:8000
  static const String baseURL = 'http://127.0.0.1:8000';
  static const String detectEndpoint = '/api/v1/detect/upload';

  // ===== Upload =====
  Future<void> _pickImage(bool fromCamera) async {
    final XFile? file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 95,
    );
    if (file == null) return;
    setState(() {
      _apiJson = null;
      _error = null;
      _imageName = file.name;
    });
    _imageBytes = await file.readAsBytes();
    setState(() {});
  }

  Future<void> _analyze() async {
    if (_imageBytes == null) {
      setState(() => _error = 'Vui lòng chọn ảnh trước.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _apiJson = null;
    });

    try {
      final uri = Uri.parse('$baseURL$detectEndpoint');
      final req = http.MultipartRequest('POST', uri);

      // ✅ TÊN FIELD KHỚP ROUTER: image (detect_image(image: UploadFile = File(...)))
      req.files.add(http.MultipartFile.fromBytes(
        'image',
        _imageBytes!,
        filename: _imageName ?? 'upload.jpg',
        contentType: http_parser.MediaType('image', 'jpeg'),
      ));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        setState(() => _apiJson = jsonDecode(utf8.decode(resp.bodyBytes)));
      } else {
        setState(() => _error = 'Lỗi server (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      setState(() => _error = 'Không thể kết nối: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildNavbar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "🧠 Hệ thống chẩn đoán bệnh hại cây trồng PlantGuard",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Tải hoặc chụp ảnh lá/trái cây — hệ thống AI sẽ phân tích bệnh và gợi ý cách xử lý.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 40),

                  // ===== chọn ảnh / chụp ảnh =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(false),
                        icon: const Icon(Icons.photo),
                        label: const Text("Chọn ảnh từ thư viện"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(true),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Chụp ảnh"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // ===== hiển thị ảnh =====
                  if (_imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _imageBytes!,
                        width: 400,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ===== nút dự đoán =====
                  FilledButton.icon(
                    onPressed: _loading ? null : _analyze,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text("Phân tích bệnh"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ===== kết quả =====
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
          _buildFooter(), // 🔥 footer rộng full-width + padding lớn
        ],
      ),
    );
  }

  Widget _buildNavbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: Colors.green, size: 32),
              const SizedBox(width: 8),
              Text(
                'PlantGuard',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _navItem('Trang chủ', onTap: () {}),
              _navItem('Thư viện'),
              _navItem('Tin tức'),
              _navItem('Liên hệ'),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Tải ứng dụng', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    // Footer full-bleed, rộng hơn + padding lớn cho cảm giác “đủ lực”
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Container(
      width: double.infinity,
      color: Colors.green.shade50,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 120 : 24, // 👉 rộng hơn
        vertical: 36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: const [
              Text('Liên hệ: support@plantguard.com | 0123-456-789',
                  style: TextStyle(fontSize: 16)),
              Text('© 2025 PlantGuard AI – All rights reserved',
                  style: TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    // 🔎 JSON lồng: { success, result: { success, result: { ...fields } } }
    final inner = (_apiJson?['result']?['result'] ?? {}) as Map<String, dynamic>;

    final disease = (inner['disease'] ?? "Không xác định").toString();
    final confidenceVal = inner['confidence'];
    final conf = confidenceVal is num
        ? confidenceVal.toDouble()
        : double.tryParse(confidenceVal?.toString() ?? '0') ?? 0.0;
    final llm = (inner['llm_explanation'] ?? "").toString();

    return Container(
      width: 680,
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
          Text("🌿 Bệnh: $disease", style: const TextStyle(fontWeight: FontWeight.w600)),
          Text("📈 Độ tin cậy: ${(conf * 100).toStringAsFixed(2)}%"),
          const SizedBox(height: 12),
          if (llm.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: SelectableText(llm),
            ),
        ],
      ),
    );
  }
}
