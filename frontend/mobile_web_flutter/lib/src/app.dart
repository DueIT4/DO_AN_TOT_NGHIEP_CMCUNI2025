import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class PredictionResult {
  final String disease;
  final double confidence;
  const PredictionResult({required this.disease, required this.confidence});
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Plant Health',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
        textTheme: Typography.englishLike2021.apply(fontSizeFactor: 1.02),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  bool _loading = false;
  PredictionResult? _result;
  Map<String, dynamic>? _rawJson;
  String? _error;

  static const String _apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8000',
  );

  Future<void> _pickImage() async {
    setState(() { _error = null; _result = null; });
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() { _imageBytes = bytes; });
  }

  Future<void> _predict() async {
    if (_imageBytes == null) return;
    setState(() { _loading = true; _error = null; _result = null; _rawJson = null; });
    try {
      final uri = Uri.parse('$_apiBase/v1/detect');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('image', _imageBytes!, filename: 'upload.jpg'));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(resp.body) as Map<String, dynamic>;
        final disease = (data['disease'] ?? '').toString();
        final confidence = (data['confidence'] is num) 
            ? (data['confidence'] as num).toDouble() 
            : double.tryParse(data['confidence']?.toString() ?? '0') ?? 0.0;
        setState(() { _result = PredictionResult(disease: disease, confidence: confidence); _rawJson = data; });
      } else {
        setState(() { _error = 'Lỗi máy chủ (${resp.statusCode})'; });
      }
    } catch (e) {
      setState(() { _error = 'Không thể gọi API: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxBodyWidth = 1100;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Plant Health')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBodyWidth),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth >= 900;
                final leftPane = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Chọn ảnh'),
                                onPressed: _loading ? null : _pickImage,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.search),
                                label: _loading ? const Text('Đang dự đoán...') : const Text('Dự đoán'),
                                onPressed: (_imageBytes != null && !_loading) ? _predict : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                                  )
                                : const Center(child: Text('Chưa có ảnh được chọn')),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                );

                final rightPane = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kết quả', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (_result == null)
                          Text('Chưa có kết quả', style: Theme.of(context).textTheme.bodyMedium)
                        else ...[
                          _ResultRow(label: 'Bệnh', value: _result!.disease),
                          _ResultRow(label: 'Độ tin cậy', value: '${(_result!.confidence * 100).toStringAsFixed(2)}%'),
                          const Divider(height: 24),
                          Text('API JSON', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SelectableText(const JsonEncoder.withIndent('  ').convert(_rawJson)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: leftPane),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: rightPane),
                    ],
                  );
                }
                return Column(
                  children: [
                    leftPane,
                    const SizedBox(height: 18),
                    rightPane,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),
    );
  }
}
