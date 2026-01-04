import 'dart:html' as html;

import 'package:http/http.dart' as http;
import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/models/admin/detection_history_models.dart';

/// Số bản ghi mỗi trang (dùng chung cho FE)
const int PAGE_SIZE = 20;

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
    final url = '${ApiBase.baseURL}'
        '${ApiBase.api('/detection-history/$detectionId/export-train')}';

    final token = ApiBase.bearer;

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await http.post(
      Uri.parse(url),
      headers: headers,
    );

    if (resp.statusCode != 200) {
      throw Exception('Lỗi export train: ${resp.statusCode} ${resp.body}');
    }
  }

  Future<void> downloadDatasetTrain() async {
    final url = '${ApiBase.baseURL}'
        '${ApiBase.api('/dataset/admin/download')}';

    final token = ApiBase.bearer;

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
