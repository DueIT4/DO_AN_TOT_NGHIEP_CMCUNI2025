import 'dart:typed_data';

enum DetectionSource { camera, upload }

class DetectionRecord {
  final String id;
  final String diseaseName;
  final double accuracy; // 0..1
  final DateTime detectedAt;
  final String cause;
  final String solution;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final DetectionSource source;

  const DetectionRecord({
    required this.id,
    required this.diseaseName,
    required this.accuracy,
    required this.detectedAt,
    required this.cause,
    required this.solution,
    this.imageUrl,
    this.imageBytes,
    required this.source,
  });

  DetectionRecord copyWith({
    String? id,
    String? diseaseName,
    double? accuracy,
    DateTime? detectedAt,
    String? cause,
    String? solution,
    String? imageUrl,
    Uint8List? imageBytes,
    DetectionSource? source,
  }) {
    return DetectionRecord(
      id: id ?? this.id,
      diseaseName: diseaseName ?? this.diseaseName,
      accuracy: accuracy ?? this.accuracy,
      detectedAt: detectedAt ?? this.detectedAt,
      cause: cause ?? this.cause,
      solution: solution ?? this.solution,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBytes: imageBytes ?? this.imageBytes,
      source: source ?? this.source,
    );
  }
}

