import 'dart:typed_data';

enum DetectionSource { camera, upload }

class DetectionItem {
  final String label;
  final double confidence;

  /// bbox optional: [x1, y1, x2, y2]
  final List<double>? bbox;

  DetectionItem({
    required this.label,
    required this.confidence,
    this.bbox,
  });

  factory DetectionItem.fromMap(Map<String, dynamic> m) {
    final label = (m['label'] ?? m['class_name'] ?? m['class'] ?? m['name'] ?? 'Unknown').toString();

    final confRaw = m['confidence'] ?? m['conf'] ?? m['score'];
    final conf = _toDouble(confRaw).clamp(0.0, 1.0);

    List<double>? bbox;
    final b = m['bbox'] ?? m['box'];
    if (b is List) {
      final temp = <double>[];
      for (final v in b) {
        final d = _toDouble(v);
        if (d.isFinite) temp.add(d);
      }
      if (temp.isNotEmpty) bbox = temp;
    }

    return DetectionItem(label: label, confidence: conf, bbox: bbox);
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class DetectionRecord {
  /// ⚠️ id của bạn đang là String (giữ nguyên để không hỏng code cũ)
  final String id;

  final String diseaseName;
  final double accuracy; // 0..1
  final DateTime detectedAt;

  final String cause;
  final String solution;

  final String? imageUrl;
  final Uint8List? imageBytes;

  final DetectionSource source;

  final String? explanation;
  final List<DetectionItem> detections;

  /// requestId (uuid) chỉ để client tracking, không dùng để gọi detail
  final String? requestId;

  DetectionRecord({
    required this.id,
    required this.diseaseName,
    required this.accuracy,
    required this.detectedAt,
    required this.cause,
    required this.solution,
    required this.source,
    this.imageUrl,
    this.imageBytes,
    this.explanation,
    this.detections = const [],
    this.requestId,
  });

  /// ✅ Getter tiện để gọi BE detail/delete
  /// Nếu id không phải số (uuid) thì trả null
  int? get detectionId => int.tryParse(id);
}
