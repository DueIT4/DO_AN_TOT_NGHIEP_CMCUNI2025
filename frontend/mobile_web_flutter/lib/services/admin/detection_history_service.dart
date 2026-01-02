// lib/services/admin/detection_history_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html; // Lưu ý: Chỉ dùng được trên Flutter Web

import 'package:http/http.dart' as http;
import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/models/admin/detection_history_models.dart';

/// Số bản ghi mỗi trang (dùng chung cho FE)
const int PAGE_SIZE = 20;

/// Service chỉ dùng cho ADMIN quản lý lịch sử nhận diện toàn hệ thống
class DetectionHistoryService {
  final http.Client _client;

  DetectionHistoryService({http.Client? client})
      : _client = client ?? http.Client();

  /// ADMIN: Lấy toàn bộ lịch sử nhận diện của tất cả người dùng
  /// Backend mới trả về URL Cloudinary trực tiếp trong trường file_url
  Future<DetectionHistoryList> getAllHistoryAdmin({
    required int page,
    String? search,
    int pageSize = PAGE_SIZE,
  }) async {
    final skip = (page - 1) * pageSize;

    final params = <String, String>{
      'skip': '$skip',
      'limit': '$pageSize',
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    final query = Uri(queryParameters: params).query;

    final res = await ApiBase.getJson(
      ApiBase.api('/detection-history/admin?$query'),
    );

    final map = Map<String, dynamic>.from(res as Map);
    return DetectionHistoryList.fromJson(map);
  }

  /// ADMIN: Xoá một bản ghi lịch sử bất kỳ
  Future<void> deleteDetectionAdmin(int detectionId) async {
    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/detection-history/admin/$detectionId')}',
    );

    final token = ApiBase.bearer;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await _client.delete(uri, headers: headers);

    if (resp.statusCode != 204 && (resp.statusCode ~/ 100) != 2) {
      throw Exception(
        'Xoá lịch sử (admin) thất bại (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  /// ⭐ Xuất dữ liệu nhận diện vào tập dữ liệu Training (Dataset)
  /// Backend sẽ tải ảnh từ Cloudinary về, crop theo bbox và lưu vào thư mục dataset
  Future<void> exportToTrainData(int detectionId) async {
    final url = '${ApiBase.baseURL}'
        '${ApiBase.api('/detection-history/$detectionId/export-train')}';

    final token = ApiBase.bearer;

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await _client.post(
      Uri.parse(url),
      headers: headers,
    );

    if (resp.statusCode != 200) {
      throw Exception('Lỗi export train: ${resp.statusCode} ${resp.body}');
    }
  }

  /// Tải về toàn bộ Dataset dạng ZIP từ server
  Future<void> downloadDatasetTrain() async {
    final url = '${ApiBase.baseURL}'
        '${ApiBase.api('/dataset/admin/download')}';

    final token = ApiBase.bearer;

    final headers = <String, String>{
      'Accept': 'application/zip',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await _client.get(
      Uri.parse(url),
      headers: headers,
    );

    if (resp.statusCode != 200) {
      throw Exception('Lỗi tải dataset: ${resp.statusCode} ${resp.body}');
    }

    // Xử lý tải file cho môi trường Flutter Web
    try {
      final bytes = resp.bodyBytes;
      final blob = html.Blob([bytes], 'application/zip');
      final urlBlob = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: urlBlob)
        ..download = "zestguard_dataset_${DateTime.now().millisecondsSinceEpoch}.zip"
        ..click();

      html.Url.revokeObjectUrl(urlBlob);
    } catch (e) {
      throw Exception('Trình duyệt không hỗ trợ tải file trực tiếp: $e');
    }
  }
}