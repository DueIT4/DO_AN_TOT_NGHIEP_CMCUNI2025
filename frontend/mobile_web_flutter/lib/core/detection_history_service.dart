// lib/core/detection_history_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_base.dart';

/// Số bản ghi mỗi trang (dùng chung cho FE)
const int PAGE_SIZE = 20;

/// 1 item trong lịch sử dự đoán
class DetectionHistoryItem {
  final int detectionId;
  final int imgId;
  final String fileUrl;
  final String? diseaseName;
  final double? confidence;
  final DateTime createdAt;

  DetectionHistoryItem({
    required this.detectionId,
    required this.imgId,
    required this.fileUrl,
    this.diseaseName,
    this.confidence,
    required this.createdAt,
  });

  factory DetectionHistoryItem.fromJson(Map<String, dynamic> json) {
    return DetectionHistoryItem(
      detectionId: json['detection_id'] as int,
      imgId: json['img_id'] as int,
      fileUrl: json['file_url'] as String,
      diseaseName: json['disease_name'] as String?,
      confidence: json['confidence'] == null
          ? null
          : (json['confidence'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DetectionHistoryList {
  final List<DetectionHistoryItem> items;
  final int total;

  DetectionHistoryList({
    required this.items,
    required this.total,
  });

  factory DetectionHistoryList.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>)
        .map((e) => DetectionHistoryItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();

    return DetectionHistoryList(
      items: list,
      total: json['total'] as int? ?? 0,
    );
  }
}

/// Service gọi API lịch sử dự đoán – dạng instance, giống DeviceService/AdminUserService
class DetectionHistoryService {
  final http.Client _client;

  DetectionHistoryService({http.Client? client})
      : _client = client ?? http.Client();

  /// GET /api/v1/detection-history/me?skip=&limit=&search=
  Future<DetectionHistoryList> getMyHistory({
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

    // Giống AdminUserService: dùng ApiBase.api + ApiBase.getJson
    final res = await ApiBase.getJson(
      ApiBase.api('/detection-history/me?$query'),
    );

    final map = Map<String, dynamic>.from(res as Map);
    return DetectionHistoryList.fromJson(map);
  }

  /// DELETE /api/v1/detection-history/{detection_id}
  Future<void> deleteDetection(int detectionId) async {
    // URL đầy đủ: baseURL + apiPrefix + path
    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/detection-history/$detectionId')}',
    );

    // Header: giống AdminUserService.deleteUser – kèm Bearer nếu có
    final token = ApiBase.bearer;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await _client.delete(uri, headers: headers);

    if (resp.statusCode != 204 && (resp.statusCode ~/ 100) != 2) {
      throw Exception(
        'Xoá lịch sử thất bại (${resp.statusCode}): ${resp.body}',
      );
    }
  }
}
