// lib/core/admin_me_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:mobile_web_flutter/core/api_base.dart';

class AdminUserMe {
  final int userId;
  final String? username;
  final String? phone;
  final String? email;
  final String? address;
  final String? roleType;
  final String? status;

  AdminUserMe({
    required this.userId,
    this.username,
    this.phone,
    this.email,
    this.address,
    this.roleType,
    this.status,
  });

  factory AdminUserMe.fromJson(Map<String, dynamic> json) {
    return AdminUserMe(
      userId: json['user_id'] as int,
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      roleType: json['role_type'] as String?,
      status: json['status'] as String?,
    );
  }
}

class AdminMeService {
  final http.Client _client;

  AdminMeService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers() {
    final token = ApiBase.bearer; // dùng giống AdminUserService

    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/v1/me/get_me
  Future<AdminUserMe> getMe() async {
    // giống style AdminUserService: baseURL + ApiBase.api(...)
    final uri =
        Uri.parse('${ApiBase.baseURL}${ApiBase.api('/me/get_me')}');

    final res = await _client.get(uri, headers: _headers());

    if (res.statusCode != 200) {
      throw Exception('Lỗi lấy thông tin cá nhân (HTTP ${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return AdminUserMe.fromJson(data);
  }

  /// PUT /api/v1/me/update_me (form-data đơn giản, không avatar)
  Future<AdminUserMe> updateMe({
    String? username,
    String? phone,
    String? email,
    String? address,
  }) async {
    final uri =
        Uri.parse('${ApiBase.baseURL}${ApiBase.api('/me/update_me')}');

    final headers = _headers();
    headers['Content-Type'] = 'application/x-www-form-urlencoded';

    final body = <String, String>{};
    if (username != null) body['username'] = username;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;

    final res = await _client.put(uri, headers: headers, body: body);

    if (res.statusCode != 200) {
      throw Exception('Lỗi cập nhật thông tin (HTTP ${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(res.body) as Map<String, dynamic>;
    return AdminUserMe.fromJson(data);
  }
}
