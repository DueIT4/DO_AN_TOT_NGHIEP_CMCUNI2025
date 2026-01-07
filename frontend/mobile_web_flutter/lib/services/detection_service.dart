// lib/services/detection_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const _guestKeyPref = 'guest_client_key';

  static Future<String> _getOrCreateGuestKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestKeyPref);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = _uuid.v4();
    await prefs.setString(_guestKeyPref, created);
    return created;
  }

  // ✅ CẬP NHẬT: Xử lý URL thông minh cho Cloudinary
  static String? _resolveUrl(dynamic raw) {
    if (raw == null) return null;
    final v = raw.toString();
    if (v.isEmpty) return null;
    
    // Nếu URL bắt đầu bằng http (Cloudinary), dùng trực tiếp
    if (v.startsWith('http')) return v;
    
    // Nếu là đường dẫn cục bộ cũ, ghép với host
    return '${ApiBase.host}$v';
  }

  static double _normalizeConfidence(dynamic raw) {
    if (raw == null) return 0.0;
    double v = 0.0;
    if (raw is num) v = raw.toDouble();
    else v = double.tryParse(raw.toString()) ?? 0.0;

    if (v > 1.0) v = v / 100.0;
    return v.clamp(0.0, 1.0);
  }

  // ✅ Helper: Parse UTC date correctly even if 'Z' is missing
  static DateTime _parseUtcDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    String s = raw.toString();
    if (s.isEmpty) return DateTime.now();
    // Assuming backend sends UTC but might miss 'Z'
    if (!s.endsWith('Z') && !s.contains('+')) {
       s += 'Z';
    }
    return DateTime.tryParse(s)?.toLocal() ?? DateTime.now();
  }

  // =========================
  // ✅ LIST HISTORY: GET /detection-history/me
  // =========================
  static Future<List<DetectionRecord>> fetchHistory({
    int skip = 0,
    int limit = 50,
    String? search,
  }) async {
    if (ApiClient.authToken == null || ApiClient.authToken!.isEmpty) return [];

    final qp = <String, String>{
      'skip': '$skip',
      'limit': '$limit',
    };
    if (search != null && search.trim().isNotEmpty) {
      qp['search'] = search.trim();
    }

    final uri = ApiBase.uri('/detection-history/me', queryParameters: qp);

    try {
      final resp = await http.get(uri, headers: ApiClient.authHeaders()).timeout(const Duration(seconds: 20));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Lỗi lấy lịch sử: ${resp.statusCode}');
      }

      final raw = jsonDecode(resp.body);
      List items = [];
      if (raw is Map) {
        items = raw['items'] ?? raw['data'] ?? [];
      } else if (raw is List) {
        items = raw;
      }
      debugPrint('[DetectionService] fetchHistory: Received ${items.length} items');

      return items.map((it) {
        final m = Map<String, dynamic>.from(it);
        return DetectionRecord(
          id: (m['detection_id'] ?? m['id'] ?? '0').toString(),
          diseaseName: (m['disease_name'] ?? 'Không xác định').toString(),
          accuracy: _normalizeConfidence(m['confidence']),
          detectedAt: _parseUtcDate(m['created_at']),
          cause: '',
          solution: '',
          source: (m['source_type']?.toString() == 'upload') ? DetectionSource.upload : DetectionSource.camera,
          imageUrl: _resolveUrl(m['file_url'] ?? m['img_url']),
          detections: const [],
        );
      }).toList()..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (e) {
      debugPrint('Error fetchHistory: $e');
      return [];
    }
  }

  // =========================
  // ✅ DETAIL: Lấy chi tiết tư vấn từ Gemini AI
  // =========================
  static Future<DetectionRecord> fetchHistoryDetail(int detectionId) async {
    final uri = ApiBase.uri('/detection-history/me/$detectionId');

    final resp = await http.get(uri, headers: ApiClient.authHeaders()).timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) throw Exception('Lỗi tải chi tiết');

    final m = jsonDecode(resp.body) as Map<String, dynamic>;

    return DetectionRecord(
      id: detectionId.toString(),
      diseaseName: (m['disease_name'] ?? 'Không xác định').toString(),
      accuracy: _normalizeConfidence(m['confidence']),
      detectedAt: _parseUtcDate(m['created_at']),
      // Lấy summary và guideline từ LLM Gemini
      cause: m['description'] ?? 'Đang phân tích...',
      solution: m['treatment_guideline'] ?? 'Vui lòng kiểm tra lại sau.',
      source: (m['source_type']?.toString() == 'upload') ? DetectionSource.upload : DetectionSource.camera,
      imageUrl: _resolveUrl(m['img_url'] ?? m['file_url']),
      explanation: m['description'],
      detections: (m['detections'] as List?)?.map((d) => DetectionItem.fromMap({
        'label': d['class_name'],
        'confidence': d['confidence'],
        'bbox': d['bbox'],
      })).toList() ?? [],
    );
  }

  // =========================
  // ✅ ANALYZE IMAGE: Gửi ảnh lên Cloud Run để nhận diện
  // =========================
  static bool _detectInFlight = false;

  static Future<DetectionRecord> analyzeImage({
    required XFile file,
    required DetectionSource source,
  }) async {
    if (_detectInFlight) throw Exception('Đang xử lý ảnh, vui lòng đợi...');
    _detectInFlight = true;

    final requestId = _uuid.v4();
    final uri = ApiBase.uri('/detect');

    final headers = ApiClient.authHeaders(json: false);
    headers['X-Request-Id'] = requestId;

    if (ApiClient.authToken == null) {
      headers['X-Client-Key'] = await _getOrCreateGuestKey();
    }

    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['source_type'] = (source == DetectionSource.camera) ? 'camera' : 'upload'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) throw Exception('Lỗi hệ thống (${response.statusCode})');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Xử lý dữ liệu trả về từ tổ hợp YOLO + Gemini
      return DetectionRecord(
        id: requestId,
        diseaseName: (data['disease_name'] ?? 'Không xác định').toString(),
        accuracy: _normalizeConfidence(data['confidence']),
        detectedAt: DateTime.now(),
        cause: data['explanation'] ?? data['disease_summary'] ?? '',
        solution: data['care_instructions'] ?? '',
        source: source,
        imageUrl: _resolveUrl(data['file_url'] ?? (data['img'] != null ? data['img']['file_url'] : null)),
        explanation: data['explanation'],
        detections: const [],
      );
    } finally {
      _detectInFlight = false;
    }
  }

  static Future<void> deleteHistory(int detectionId) async {
    final uri = ApiBase.uri('/detection-history/$detectionId');
    final resp = await http.delete(uri, headers: ApiClient.authHeaders()).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 204 && resp.statusCode != 200) throw Exception('Không thể xóa');
  }
}