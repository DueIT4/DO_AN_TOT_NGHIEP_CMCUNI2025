// lib/core/admin_user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/models/admin/admin_user_search_result.dart'; // <- thêm dòng này

class AdminUserService {
  static final http.Client _client = http.Client();

  static Future<List<Map<String, dynamic>>> listUsers() async {
    final res = await ApiBase.getJson(ApiBase.api('/users'));
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<AdminUserSearchResult> searchUsers({
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    final params = <String, String>{
      'q': keyword,
      'page': '$page',
      'size': '$size',
    };
    final query = Uri(queryParameters: params).query;

    final res = await ApiBase.getJson(ApiBase.api('/users/search?$query'));
    final map = Map<String, dynamic>.from(res as Map);
    return AdminUserSearchResult.fromJson(map);
  }

  static Future<Map<String, dynamic>> createUser({
    required String username,
    required String phone,
    required String password,
    String? email,
    String? address,
    int? roleId,
    String? status, // active / inactive
  }) async {
    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/users/create')}',
    );

    final token = ApiBase.bearer;
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      });

    request.fields['username'] = username;
    request.fields['phone'] = phone;
    request.fields['password'] = password;

    if (email != null) request.fields['email'] = email;
    if (address != null) request.fields['address'] = address;
    if (roleId != null) {
      request.fields['role_id'] = roleId.toString();
    }
    if (status != null) {
      request.fields['status'] = status;
    }

    final resp = await _client.send(request);
    final body = await resp.stream.bytesToString();

    if (resp.statusCode ~/ 100 != 2) {
      throw Exception(
        'Tạo user thất bại (${resp.statusCode}): $body',
      );
    }

    final json = jsonDecode(body);
    return Map<String, dynamic>.from(json as Map);
  }

  static Future<Map<String, dynamic>> updateUser({
    required int userId,
    String? username,
    String? phone,
    String? password,
    String? email,
    String? address,
    int? roleId,
    String? status, // active / inactive
  }) async {
    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/users/update/$userId')}',
    );

    final token = ApiBase.bearer;
    final request = http.MultipartRequest('PUT', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      });

    if (username != null) request.fields['username'] = username;
    if (phone != null) request.fields['phone'] = phone;
    if (password != null) request.fields['password'] = password;
    if (email != null) request.fields['email'] = email;
    if (address != null) request.fields['address'] = address;
    if (roleId != null) {
      request.fields['role_id'] = roleId.toString();
    }
    if (status != null) {
      request.fields['status'] = status;
    }

    final resp = await _client.send(request);
    final body = await resp.stream.bytesToString();

    if (resp.statusCode ~/ 100 != 2) {
      throw Exception(
        'Cập nhật user thất bại (${resp.statusCode}): $body',
      );
    }

    final json = jsonDecode(body);
    return Map<String, dynamic>.from(json as Map);
  }

  /// vẫn giữ hàm deleteUser (gọi /delete) – BE đã đổi qua set inactive
  static Future<void> deleteUser(int userId) async {
    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/users/delete/$userId')}',
    );

    final token = ApiBase.bearer;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };

    final resp = await _client.delete(uri, headers: headers);

    if (resp.statusCode != 204 &&
        (resp.statusCode ~/ 100) != 2) {
      throw Exception(
        'Xoá user thất bại (${resp.statusCode}): ${resp.body}',
      );
    }
  }
}
