// lib/services/admin/dashboard_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/models/admin/dashboard_models.dart';

class DashboardService {
  static final http.Client _client = http.Client();

  /// Range: '7d' | '30d' | '90d'
  /// Lấy dữ liệu tổng quan cho biểu đồ và thống kê
  static Future<DashboardSummary> fetchSummary({String range = '7d'}) async {
    final params = <String, String>{'range': range};
    final query = Uri(queryParameters: params).query;

    // Sử dụng ApiBase.getJson để tự động xử lý Token và BaseURL
    final res = await ApiBase.getJson(ApiBase.api('/admin/dashboard?$query'));
    
    // Đảm bảo map dữ liệu an toàn
    final map = Map<String, dynamic>.from(res as Map);
    return DashboardSummary.fromJson(map);
  }

  /// Xuất báo cáo Dashboard dưới dạng CSV
  static Future<String> exportDashboardCsv({String range = '7d'}) async {
    final params = <String, String>{'range': range};
    final query = Uri(queryParameters: params).query;

    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/admin/dashboard/export?$query')}',
    );

    final token = ApiBase.bearer;
    final headers = <String, String>{
      'Accept': 'text/csv',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await _client.get(uri, headers: headers);

    if ((resp.statusCode ~/ 100) != 2) {
      throw Exception(
        'Xuất báo cáo dashboard (CSV) thất bại (${resp.statusCode}): ${resp.body}',
      );
    }

    // Decode bằng utf8 để tránh lỗi font tiếng Việt
    return utf8.decode(resp.bodyBytes);
  }

  /// Xuất báo cáo tóm tắt dưới dạng PDF (Trả về bytes để FE hiển thị/tải về)
  static Future<Uint8List> exportSummaryPdf({String range = '7d'}) async {
    final params = <String, String>{'range': range};
    final query = Uri(queryParameters: params).query;

    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/admin/reports/summary?$query')}',
    );

    final token = ApiBase.bearer;
    final headers = <String, String>{
      'Accept': 'application/pdf',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await _client.get(uri, headers: headers);

    if ((resp.statusCode ~/ 100) != 2) {
      throw Exception(
        'Xuất báo cáo PDF thất bại (${resp.statusCode}): ${resp.body}',
      );
    }

    return resp.bodyBytes;
  }
}