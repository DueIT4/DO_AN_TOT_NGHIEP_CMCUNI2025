// ==============================================
// 📄 File: frontend/mobile_web_flutter/lib/modules/detect/detect_content.dart
// ==============================================
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
  Uint8List? _imageBytes;
  String? _imageName;
  bool _loading = false;
  Map<String, dynamic>? _apiJson;
  String? _error;

  // Endpoint chuẩn (có prefix /api/v1)
  static final String _detectPath = ApiBase.api('/detect');

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
      final uri = Uri.parse('${ApiBase.baseURL}$_detectPath');
      final req = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          _imageBytes!,
          filename: _imageName ?? 'upload.jpg',
          contentType: http_parser.MediaType('image', 'jpeg'),
        ));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final raw = utf8.decode(resp.bodyBytes);
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          setState(() => _apiJson = Map<String, dynamic>.from(decoded));
        } else {
          setState(() => _error = 'Phản hồi không phải JSON object: ${decoded.runtimeType}');
        }
      } else {
        setState(() => _error = 'Lỗi server (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      setState(() => _error = 'Không thể kết nối: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: wide ? 60 : 20, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "🧠 Hệ thống chẩn đoán bệnh hại cây trồng PlantGuard",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            "Tải hoặc chụp ảnh lá/trái cây — hệ thống AI sẽ phân tích bệnh và gợi ý cách xử lý.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 40),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickImage(false),
                icon: const Icon(Icons.photo),
                label: const Text("Chọn ảnh từ thư viện"),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickImage(true),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Chụp ảnh"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
              ),
            ],
          ),
          const SizedBox(height: 40),

          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_imageBytes!, width: 400, height: 300, fit: BoxFit.cover),
            ),
          const SizedBox(height: 20),

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

          if (_loading)
            const CircularProgressIndicator()
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_apiJson != null)
            _buildResultCard(theme),
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    final Map<String, dynamic> root =
        Map<String, dynamic>.from(_apiJson ?? const {});
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(root['data'] ?? const {});

    // Nếu backend đã trả đủ keys chuẩn → dùng trực tiếp
    // Nếu không, dữ liệu sẽ nằm trong 'payload' (hoặc 'items' cho list)
    final Map<String, dynamic> inner =
        (data.containsKey('disease') || data.containsKey('confidence') || data.containsKey('llm_explanation'))
            ? data
            : Map<String, dynamic>.from(data['payload'] ?? const {});

    final disease = (inner['disease'] ?? "Không xác định").toString();

    final confVal = inner['confidence'];
    final conf = confVal is num
        ? confVal.toDouble()
        : double.tryParse(confVal?.toString() ?? '0') ?? 0.0;

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
          if (inner.isEmpty && data.containsKey('items'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("📦 Model trả về danh sách (items), đã hiển thị rút gọn."),
            ),
        ],
      ),
    );
  }
}
