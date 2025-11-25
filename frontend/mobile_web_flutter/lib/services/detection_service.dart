import 'dart:math';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../models/detection_record.dart';

/// Tạm thời mô phỏng API detections/img/diseases.
/// Khi backend sẵn sàng, thay thế các hàm bên dưới bằng HTTP call thật.
class DetectionService {
  DetectionService._();

  static final _rand = Random();
  static final List<DetectionRecord> _history = [
    DetectionRecord(
      id: 'detection_001',
      diseaseName: 'Bệnh đốm lá',
      accuracy: 0.84,
      detectedAt: DateTime.now().subtract(const Duration(hours: 6)),
      cause: 'Nấm Cercospora gây ra trong điều kiện ẩm ướt kéo dài.',
      solution:
          'Tỉa bớt lá, giữ khoảng cách thông thoáng và phun thuốc gốc đồng.',
      imageUrl:
          'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?w=800',
      source: DetectionSource.camera,
      imageBytes: null,
    ),
    DetectionRecord(
      id: 'detection_002',
      diseaseName: 'Thối rễ',
      accuracy: 0.77,
      detectedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      cause: 'Tưới quá nhiều nước khiến rễ bị úng và nhiễm nấm Phytophthora.',
      solution:
          'Giảm tưới, thay đất thông thoáng và dùng thuốc nấm đặc trị trong 7 ngày.',
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800',
      source: DetectionSource.upload,
      imageBytes: null,
    ),
  ];

  static Future<List<DetectionRecord>> fetchHistory() async {
    await Future.delayed(const Duration(milliseconds: 350));
    return List.unmodifiable(_history);
  }

  static Future<DetectionRecord> analyzeImage({
    required XFile file,
    required DetectionSource source,
  }) async {
    final bytes = await file.readAsBytes();
    await Future.delayed(const Duration(seconds: 1));

    final diseaseSamples = [
      (
        'Phấn trắng',
        'Bào tử nấm Erysiphe phát triển khi độ ẩm cao nhưng ít mưa.',
        'Loại bỏ phần lá bệnh, phun lưu huỳnh dạng bột và tăng cường thông gió.'
      ),
      (
        'Bệnh rỉ sắt',
        'Vi khuẩn Puccinia tấn công khi lá ướt liên tục.',
        'Cắt bỏ lá bị bệnh, giữ vườn khô ráo và phun thuốc gốc đồng.'
      ),
      (
        'Cháy lá vi khuẩn',
        'Vi khuẩn Pseudomonas lan nhanh qua nước tưới và dụng cụ chưa khử trùng.',
        'Khử trùng dụng cụ, hạn chế tưới phun và dùng thuốc kháng khuẩn sinh học.'
      ),
    ];

    final pick = diseaseSamples[_rand.nextInt(diseaseSamples.length)];
    final accuracy = 0.7 + _rand.nextDouble() * 0.25;

    final record = DetectionRecord(
      id: 'detection_${DateTime.now().millisecondsSinceEpoch}',
      diseaseName: pick.$1,
      accuracy: double.parse(accuracy.toStringAsFixed(2)),
      detectedAt: DateTime.now(),
      cause: pick.$2,
      solution: pick.$3,
      imageUrl: null,
      imageBytes: Uint8List.fromList(bytes),
      source: source,
    );

    _history.insert(0, record);
    return record;
  }
}

