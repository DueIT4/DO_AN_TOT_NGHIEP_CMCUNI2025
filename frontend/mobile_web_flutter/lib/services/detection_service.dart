import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/api_base_app.dart';
import '../models/detection_record.dart';
import 'api_client.dart';

class DetectionService {
  DetectionService._();

  static final List<DetectionRecord> _history = [];

  // =========================
  // Guest Key (cho khách chưa đăng nhập)
  // =========================
  static const _guestKeyPref = 'guest_client_key';
  static const _uuid = Uuid();

  static Future<String> _getOrCreateGuestKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestKeyPref);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = _uuid.v4();
    await prefs.setString(_guestKeyPref, created);
    return created;
  }

  static Map<String, String> _headersForMultipart() {
    final headers = ApiClient.authHeaders(json: false);

    // Nếu chưa có Bearer => guest => thêm X-Client-Key
    final hasBearer = ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty;
    if (!hasBearer) {
      // Sẽ gắn sau vì cần async lấy guest key
      // (xử lý trong analyzeImage)
    }
    return headers;
  }

  // =========================
  // HISTORY (tuỳ BE bạn có endpoint này hay không)
  // =========================
  static Future<List<DetectionRecord>> fetchHistory() async {
    final uri = ApiBase.uri('/detect/history');
    final resp = await http.get(uri, headers: ApiClient.authHeaders());

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Không lấy được lịch sử (${resp.statusCode}): ${resp.body}');
    }

    final raw = jsonDecode(resp.body);
    if (raw is! List) return [];

    final List<DetectionRecord> records = [];
    for (final item in raw) {
      if (item is! Map) continue;

      final map = item.cast<String, dynamic>();

      final diseaseName = (map['disease_name'] ?? 'Không xác định').toString();
      final createdAtStr = map['created_at']?.toString();
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

      final sourceTypeStr = (map['source_type'] ?? 'camera').toString().toLowerCase();
      final source = sourceTypeStr == 'camera' ? DetectionSource.camera : DetectionSource.upload;

      // Nếu BE trả img_url dạng "/media/...." thì nối host
      final imgUrlRaw = map['img_url']?.toString();
      final imageUrl = (imgUrlRaw != null && imgUrlRaw.isNotEmpty)
          ? (imgUrlRaw.startsWith('http') ? imgUrlRaw : '${ApiBase.host}$imgUrlRaw')
          : null;

      // Confidence nếu BE có trả
      final confidenceRaw = map['confidence'];
      final accuracy = _normalizeConfidence(confidenceRaw);

      final guide = _guideFor(diseaseName);

      records.add(
        DetectionRecord(
          id: (map['detection_id'] ?? '').toString(),
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

  // =========================
  // ANALYZE IMAGE (khớp routes_detect.py)
  // =========================
  static Future<DetectionRecord> analyzeImage({
    required XFile file,
    required DetectionSource source,
  }) async {
    final bytes = await file.readAsBytes();
    final uri = ApiBase.uri('/detect');

    final headers = _headersForMultipart();
    final hasBearer = ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty;
    if (!hasBearer) {
      headers['X-Client-Key'] = await _getOrCreateGuestKey();
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      // BE hiện không nhận source_type => field này có/không đều được
      ..fields['source_type'] = (source == DetectionSource.camera) ? 'camera' : 'upload'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file', // ✅ QUAN TRỌNG: BE nhận field tên "file"
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
      throw Exception('Phân tích thất bại (${response.statusCode}): ${response.body}');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Không đọc được dữ liệu phản hồi từ máy chủ.');
    }

    // ===== Khớp output của routes_detect.py =====
    // data: { file_name, saved_to_db, img, num_detections, detections, explanation, llm:{...} }
    final detections = (data['detections'] is List) ? (data['detections'] as List) : const [];
    final llm = (data['llm'] is Map) ? (data['llm'] as Map).cast<String, dynamic>() : <String, dynamic>{};

    // Lấy tên bệnh "hợp lý" từ llm hoặc detections
    final diseaseName =
        (llm['disease_summary'] ?? '').toString().trim().isNotEmpty
            ? llm['disease_summary'].toString()
            : (detections.isNotEmpty ? 'Phát hiện ${detections.length} dấu hiệu' : 'Không xác định');

    // Accuracy: BE không trả confidence => mình map theo num_detections (tuỳ bạn)
    final numDetections = (data['num_detections'] is num) ? (data['num_detections'] as num).toDouble() : 0.0;
    final accuracy = numDetections <= 0 ? 0.0 : 0.85; // bạn có thể đổi logic

    // Ảnh trả về: BE trả data['img'] = saved (img_id + file_url) khi logged in
    String? imageUrl;
    final img = data['img'];
    if (img is Map) {
      final fileUrl = img['file_url']?.toString();
      if (fileUrl != null && fileUrl.isNotEmpty) {
        imageUrl = fileUrl.startsWith('http') ? fileUrl : '${ApiBase.host}$fileUrl';
      }
    }

    final guide = _guideFor(diseaseName);

    final record = DetectionRecord(
      id: (data['file_name'] ?? 'detection_${DateTime.now().millisecondsSinceEpoch}').toString(),
      diseaseName: diseaseName,
      accuracy: double.parse(accuracy.toStringAsFixed(2)),
      detectedAt: DateTime.now(),
      cause: guide.$1,
      solution: guide.$2,
      imageUrl: imageUrl,
      imageBytes: null,
      source: source,
    );

    _history.insert(0, record);
    return record;
  }

  // =========================
  // Guides + helpers (giữ nguyên logic bạn)
  // =========================
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
}
