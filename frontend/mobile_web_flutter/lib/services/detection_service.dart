import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_base_app.dart';
import '../models/detection_record.dart';
import 'api_client.dart';

class DetectionService {
  DetectionService._();

  static const _uuid = Uuid();

  // Guest key (nếu chưa login)
  static const _guestKeyPref = 'guest_client_key';

  static Future<String> _getOrCreateGuestKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestKeyPref);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = _uuid.v4();
    await prefs.setString(_guestKeyPref, created);
    return created;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static double _normalizeConfidence(dynamic raw) {
    if (raw == null) return 0.0;
    var v = _toDouble(raw);

    // nếu BE trả 0..100 thì normalize
    if (v > 1.0) v = v / 100.0;

    return v.clamp(0.0, 1.0);
  }

  static DetectionSource _parseSource(String? s) {
    final t = (s ?? 'camera').toLowerCase();
    return t == 'upload' ? DetectionSource.upload : DetectionSource.camera;
  }

  static String? _resolveUrl(dynamic raw) {
    if (raw == null) return null;
    final v = raw.toString();
    if (v.isEmpty) return null;
    if (v.startsWith('http')) return v;
    return '${ApiBase.host}$v';
  }

  // =========================
  // ✅ LIST HISTORY: GET /detection-history/me
  // =========================
  static Future<List<DetectionRecord>> fetchHistory({
    int skip = 0,
    int limit = 50,
    String? search,
  }) async {
    final qp = <String, String>{
      'skip': '$skip',
      'limit': '$limit',
    };
    if (search != null && search.trim().isNotEmpty) {
      qp['search'] = search.trim();
    }

    final uri = ApiBase.uri('/detection-history/me', queryParameters: qp);

    http.Response resp;
    try {
      resp = await http.get(uri, headers: ApiClient.authHeaders()).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ.');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Không lấy được lịch sử (${resp.statusCode}): ${resp.body}');
    }

    final raw = jsonDecode(resp.body);

    List items = [];
    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      final cand = m['items'] ?? m['data'] ?? m['results'] ?? m['detections'];
      if (cand is List) items = cand;
    } else if (raw is List) {
      items = raw;
    }

    final records = <DetectionRecord>[];

    for (final it in items) {
      if (it is! Map) continue;
      final m = it.cast<String, dynamic>();

      // BE service của bạn đang trả: detection_id, file_url, disease_name, confidence, created_at
      final detId = (m['detection_id'] ?? m['id'] ?? '').toString();
      final createdAt =
          DateTime.tryParse('${m['created_at'] ?? m['createdAt'] ?? ''}') ?? DateTime.now();

      final diseaseName = (m['disease_name'] ?? m['diseaseName'] ?? 'Không xác định').toString();

      // ✅ list dùng file_url (đừng dùng img_url ở list)
      final imageUrl = _resolveUrl(m['file_url'] ?? m['img_url'] ?? m['image_url']);

      final source = _parseSource(m['source_type']?.toString());

      final acc = _normalizeConfidence(m['confidence']);

      records.add(
        DetectionRecord(
          id: detId.isNotEmpty ? detId : '0',
          diseaseName: diseaseName,
          accuracy: acc,
          detectedAt: createdAt,
          // list thường không có detail -> để trống
          cause: '',
          solution: '',
          source: source,
          imageUrl: imageUrl,
          explanation: null,
          detections: const [],
        ),
      );
    }

    records.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    return records;
  }

  // =========================
  // ✅ DETAIL: GET /detection-history/me/{detection_id}
  // (khớp endpoint BE bạn đã thêm)
  // =========================
  static Future<DetectionRecord> fetchHistoryDetail(int detectionId) async {
    if (detectionId <= 0) {
      throw Exception('ID lịch sử không hợp lệ.');
    }

    final uri = ApiBase.uri('/detection-history/me/$detectionId');

    http.Response resp;
    try {
      resp = await http.get(uri, headers: ApiClient.authHeaders()).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ.');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Không tải được chi tiết (${resp.statusCode}): ${resp.body}');
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map) throw Exception('Dữ liệu chi tiết không hợp lệ');
    final m = raw.cast<String, dynamic>();

    final createdAt = DateTime.tryParse('${m['created_at'] ?? ''}') ?? DateTime.now();
    final diseaseName = (m['disease_name'] ?? 'Không xác định').toString();
    final source = _parseSource(m['source_type']?.toString());

    // ✅ detail endpoint bạn trả img_url
    final imageUrl = _resolveUrl(m['img_url'] ?? m['file_url']);

    // ✅ detail endpoint bạn trả confidence đã là 0..1
    final acc = _normalizeConfidence(m['confidence']);

    final desc = (m['description'] ?? '').toString();
    final guide = (m['treatment_guideline'] ?? '').toString();

    final dets = <DetectionItem>[];
    final detRaw = m['detections'];
    if (detRaw is List) {
      for (final d in detRaw) {
        if (d is Map) {
          dets.add(
            DetectionItem.fromMap({
              'label': d['class_name'] ?? d['label'],
              'confidence': d['confidence'],
              'bbox': d['bbox'],
            }),
          );
        }
      }
    }

    return DetectionRecord(
      id: detectionId.toString(),
      diseaseName: diseaseName,
      accuracy: acc,
      detectedAt: createdAt,
      cause: desc.isNotEmpty ? desc : 'Đang cập nhật thông tin nguyên nhân cho bệnh này.',
      solution: guide.isNotEmpty ? guide : 'Vui lòng theo dõi và tham khảo chuyên gia.',
      source: source,
      imageUrl: imageUrl,
      explanation: desc.trim().isEmpty ? null : desc.trim(),
      detections: dets,
      requestId: null,
    );
  }

  // =========================
  // ✅ DELETE: DELETE /detection-history/{detection_id}
  // =========================
  static Future<void> deleteHistory(int detectionId) async {
    if (detectionId <= 0) throw Exception('ID lịch sử không hợp lệ.');

    final uri = ApiBase.uri('/detection-history/$detectionId');

    http.Response resp;
    try {
      resp = await http.delete(uri, headers: ApiClient.authHeaders()).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Hết thời gian kết nối máy chủ.');
    }

    if (resp.statusCode == 204) return;

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Xoá thất bại (${resp.statusCode}): ${resp.body}');
    }
  }

  // =========================
  // ✅ ANALYZE IMAGE: POST /detect
  // - Không tự tạo history "ảo" => tránh % loạn + tránh duplicate
  // - Trả record tạm để UI show SnackBar thôi
  // =========================
  static bool _detectInFlight = false;

  static Future<DetectionRecord> analyzeImage({
    required XFile file,
    required DetectionSource source,
  }) async {
    if (_detectInFlight) {
      throw Exception('Đang phân tích ảnh, vui lòng chờ...');
    }
    _detectInFlight = true;

    final requestId = _uuid.v4();
    final uri = ApiBase.uri('/detect');

    final headers = ApiClient.authHeaders(json: false);
    headers['X-Request-Id'] = requestId;

    final hasBearer = ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty;
    if (!hasBearer) {
      headers['X-Client-Key'] = await _getOrCreateGuestKey();
    }

    final bytes = await file.readAsBytes();

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['source_type'] = (source == DetectionSource.camera) ? 'camera' : 'upload'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name.isNotEmpty ? file.name : 'capture.jpg',
        ),
      );

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Phân tích thất bại (${response.statusCode}): ${response.body}');
      }

      final data = (jsonDecode(response.body) as Map).cast<String, dynamic>();

      // parse mềm vì /detect của bạn có thể khác cấu trúc
      final diseaseName = (data['disease_name'] ??
              data['disease'] ??
              (data['llm'] is Map ? (data['llm']['disease_name'] ?? data['llm']['disease_summary']) : null) ??
              'Không xác định')
          .toString();

      final acc = _normalizeConfidence(data['confidence'] ?? data['overall_confidence']);

      String? imageUrl;
      if (data['img'] is Map) {
        imageUrl = _resolveUrl((data['img'] as Map)['file_url']);
      } else {
        imageUrl = _resolveUrl(data['file_url'] ?? data['img_url']);
      }

      final explanation = data['explanation']?.toString();

      return DetectionRecord(
        // ⚠️ id tạm = requestId (uuid). UI sẽ reload history từ server để lấy detection_id thật.
        id: requestId,
        requestId: requestId,
        diseaseName: diseaseName,
        accuracy: acc,
        detectedAt: DateTime.now(),
        cause: explanation ?? '',
        solution: (data['care_instructions'] ?? '').toString(),
        source: source,
        imageUrl: imageUrl,
        explanation: explanation,
        detections: const [],
      );
    } finally {
      _detectInFlight = false;
    }
  }
}
