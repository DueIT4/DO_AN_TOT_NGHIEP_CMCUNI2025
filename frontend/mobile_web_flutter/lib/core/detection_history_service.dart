// lib/core/detection_history_service.dart
import 'package:http/http.dart' as http;

import 'api_base.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_web_flutter/core/api_base.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:mobile_web_flutter/core/api_base.dart';
/// Số bản ghi mỗi trang (dùng chung cho FE)
const int PAGE_SIZE = 20;

/// 1 item trong lịch sử dự đoán (admin thấy được cả thông tin user)
class DetectionHistoryItem {
  final int detectionId;
  final int imgId;
  final String fileUrl;
  final String? diseaseName;
  final double? confidence;
  final DateTime createdAt;

  // Thông tin user – chỉ có trong API admin
  final int? userId;
  final String? username;
  final String? email;
  final String? phone;

  DetectionHistoryItem({
    required this.detectionId,
    required this.imgId,
    required this.fileUrl,
    this.diseaseName,
    this.confidence,
    required this.createdAt,
    this.userId,
    this.username,
    this.email,
    this.phone,
  });

  factory DetectionHistoryItem.fromJson(Map<String, dynamic> json) {
    return DetectionHistoryItem(
      detectionId: json['detection_id'] as int,
      imgId: json['img_id'] as int,
      fileUrl: (json['file_url'] ?? '') as String,
      diseaseName: json['disease_name'] as String?,
      confidence: json['confidence'] == null
          ? null
          : (json['confidence'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id'] as int?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
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

/// Service chỉ dùng cho ADMIN
class DetectionHistoryService {
  final http.Client _client;

  DetectionHistoryService({http.Client? client})
      : _client = client ?? http.Client();

  /// ADMIN: GET /api/v1/detection-history/admin?skip=&limit=&search=
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

  /// ADMIN: DELETE /api/v1/detection-history/admin/{detection_id}
  Future<void> deleteDetectionAdmin(int detectionId) async {
    final uri = Uri.parse(
      // 👇 SỬA 'admi' → 'admin'
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
    /// ⭐ Gọi API: POST /detection-history/{detection_id}/export-train
 Future<void> exportToTrainData(int detectionId) async {
  // Tạo URL
  final url = '${ApiBase.baseURL}'
      '${ApiBase.api('/detection-history/$detectionId/export-train')}';

  // Lấy token
  final token = ApiBase.bearer;

  // Headers cho request
  final headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // Gửi request POST
  final resp = await http.post(
    Uri.parse(url),
    headers: headers,
  );

  // Kiểm tra response
  if (resp.statusCode != 200) {
    throw Exception('Lỗi export train: ${resp.statusCode} ${resp.body}');
  }
  


}

Future<void> downloadDatasetTrain() async {
  // URL giống pattern các API khác
  final url = '${ApiBase.baseURL}'
      '${ApiBase.api('/dataset/admin/download')}';

  // Lấy token như bạn đang làm
  final token = ApiBase.bearer;

  // Header giống hệt exportToTrainData
  final headers = <String, String>{
    'Accept': 'application/zip',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  final resp = await http.get(
    Uri.parse(url),
    headers: headers,
  );

  if (resp.statusCode != 200) {
    throw Exception('Lỗi tải dataset: ${resp.statusCode} ${resp.body}');
  }

  // Tạo file download (Flutter Web)
  final bytes = resp.bodyBytes;
  final blob = html.Blob([bytes], 'application/zip');
  final urlBlob = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: urlBlob)
    ..download = "dataset_train.zip"
    ..click();

  html.Url.revokeObjectUrl(urlBlob);
}


}
