import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/api_base.dart';
import '../models/detection_record.dart';
import 'api_client.dart';

class DetectionService {
  DetectionService._();

  static final List<DetectionRecord> _history = [
    // Bắt đầu trống, sẽ nạp từ backend
  ];

  static Future<List<DetectionRecord>> fetchHistory() async {
    final uri = Uri.parse(ApiBase.api('/detect/history'));
    final resp = await http.get(
      uri,
      headers: ApiClient.authHeaders(),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'Không lấy được lịch sử (${resp.statusCode}): ${resp.body}');
    }

    final raw = jsonDecode(resp.body);
    if (raw is! List) return [];

    final List<DetectionRecord> records = [];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final diseaseName = (item['disease_name'] ?? 'Không xác định').toString();
      final accuracy = _normalizeConfidence(item['confidence']);
      final createdAtStr = item['created_at']?.toString();
      final createdAt =
          createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
      final guide = _guideFor(diseaseName);

      // Parse source_type từ backend
      final sourceTypeStr =
          (item['source_type'] ?? 'camera').toString().toLowerCase();
      final source = sourceTypeStr == 'camera'
          ? DetectionSource.camera
          : DetectionSource.upload;

      // Build full URL cho ảnh
      final imgUrlRaw = item['img_url']?.toString();
      final imageUrl = imgUrlRaw != null && imgUrlRaw.isNotEmpty
          ? '${ApiBase.host}$imgUrlRaw'
          : null;

      records.add(
        DetectionRecord(
          id: (item['detection_id'] ?? '').toString(),
          diseaseName: diseaseName,
          accuracy: double.parse(accuracy.toStringAsFixed(2)),
          detectedAt: createdAt,
          cause: guide.$1,
          solution: guide.$2,
          imageUrl: imageUrl,
          imageBytes: null,
          source: source,
        ),
      );
    }

    _history
      ..clear()
      ..addAll(records);
    return List.unmodifiable(_history);
  }

  static const Map<String, (String cause, String solution)> _diseaseGuides = {
    'Phấn trắng': (
      'Bào tử nấm phát triển mạnh khi độ ẩm cao nhưng ít mưa.',
      'Tỉa bớt lá, cải thiện thông gió và phun thuốc lưu huỳnh định kỳ.'
    ),
    'Bệnh đốm lá': (
      'Nấm Cercospora tấn công khi lá ướt kéo dài.',
      'Giữ lá khô, phun thuốc gốc đồng và loại bỏ lá bệnh.'
    ),
    'Rỉ sắt': (
      'Bào tử Puccinia lan qua gió và nước tưới.',
      'Khử trùng dụng cụ, hạn chế tưới phun và phun thuốc đặc trị.'
    ),
    'Thối rễ': (
      'Đất úng nước tạo điều kiện cho nấm Phytophthora.',
      'Cải tạo giá thể thoát nước tốt và dùng thuốc trị nấm toàn thân.'
    ),
  };

  static const (String cause, String solution) _defaultGuide = (
    'Đang cập nhật thông tin nguyên nhân cho bệnh này.',
    'Vui lòng theo dõi và tham khảo chuyên gia để có hướng xử lý chính xác.'
  );

  static (String cause, String solution) _guideFor(String disease) {
    return _diseaseGuides[disease] ?? _defaultGuide;
  }

  static double _normalizeConfidence(dynamic raw) {
    if (raw == null) return 0.0;
    final numValue = raw is num ? raw : double.tryParse(raw.toString()) ?? 0.0;
    final d = numValue.toDouble();
    if (!d.isFinite) return 0.0;
    return d.clamp(0.0, 1.0).toDouble();
  }

  static Future<DetectionRecord> analyzeImage({
    required XFile file,
    required DetectionSource source,
  }) async {
    final bytes = await file.readAsBytes();

    final uri = Uri.parse(ApiBase.api('/detect/analyze'));
    final sourceTypeValue =
        source == DetectionSource.camera ? 'camera' : 'upload';
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(ApiClient.authHeaders(json: false))
      ..fields['source_type'] = sourceTypeValue
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: file.name.isNotEmpty ? file.name : 'capture.jpg',
        ),
      );

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ phát hiện bệnh.');
    } catch (e) {
      throw Exception('Không thể kết nối máy chủ: $e');
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Phân tích thất bại (${response.statusCode}): ${response.body}');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Không đọc được dữ liệu phản hồi từ máy chủ.');
    }

    final diseaseName = (data['disease'] ?? 'Không xác định').toString();
    final accuracy = _normalizeConfidence(data['confidence']);
    final guide = _guideFor(diseaseName);

    // Build full URL cho ảnh từ backend
    final imgUrlRaw = data['img_url']?.toString();
    final imageUrl = imgUrlRaw != null && imgUrlRaw.isNotEmpty
        ? '${ApiBase.host}$imgUrlRaw'
        : null;

    final record = DetectionRecord(
      id: (data['detection_id'] ??
              'detection_${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      diseaseName: diseaseName,
      accuracy: double.parse(accuracy.toStringAsFixed(2)),
      detectedAt: DateTime.now(),
      cause: guide.$1,
      solution: guide.$2,
      imageUrl: imageUrl,
      imageBytes: null, // Không cần lưu bytes nữa, dùng URL
      source: source,
    );

    _history.insert(0, record);
    return record;
  }
}
