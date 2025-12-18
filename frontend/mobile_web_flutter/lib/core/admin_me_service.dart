// lib/core/admin_me_service.dart
import 'dart:convert';
import 'dart:typed_data';
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

  // ✅ avatar
  final String? avtUrl;

  AdminUserMe({
    required this.userId,
    this.username,
    this.phone,
    this.email,
    this.address,
    this.roleType,
    this.status,
    this.avtUrl,
  });

  factory AdminUserMe.fromJson(Map<String, dynamic> json) {
    return AdminUserMe(
      userId: (json['user_id'] as num).toInt(),
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      roleType: json['role_type'] as String?,
      status: json['status'] as String?,
      avtUrl: json['avt_url'] as String?, // ✅ parse đúng key backend
    );
  }
}

class AdminMeService {
  final http.Client _client;

  AdminMeService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers({String? contentType}) {
    final token = ApiBase.bearer;
    return <String, String>{
      'Accept': 'application/json',
      if (contentType != null) 'Content-Type': contentType,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/v1/me/get_me
  Future<AdminUserMe> getMe() async {
    final uri = Uri.parse('${ApiBase.baseURL}${ApiBase.api('/me/get_me')}');
    final res = await _client.get(uri, headers: _headers());

    if (res.statusCode ~/ 100 != 2) {
      throw Exception('Lỗi lấy thông tin cá nhân (HTTP ${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return AdminUserMe.fromJson(data);
  }

  /// PUT /api/v1/me/update_me (x-www-form-urlencoded)
  Future<AdminUserMe> updateMe({
    String? username,
    String? phone,
    String? email,
    String? address,
  }) async {
    final uri = Uri.parse('${ApiBase.baseURL}${ApiBase.api('/me/update_me')}');

    final body = <String, String>{};
    if (username != null) body['username'] = username;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;

    final res = await _client.put(
      uri,
      headers: _headers(contentType: 'application/x-www-form-urlencoded'),
      body: body,
    );

    if (res.statusCode ~/ 100 != 2) {
      throw Exception('Lỗi cập nhật thông tin (HTTP ${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return AdminUserMe.fromJson(data);
  }

  /// POST /api/v1/me/update_avatar (multipart/form-data)
  Future<AdminUserMe> updateAvatar({
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('${ApiBase.baseURL}${ApiBase.api('/me/update_avatar')}');

    final req = http.MultipartRequest('POST', uri);

    final token = ApiBase.bearer;
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.headers['Accept'] = 'application/json';

    req.files.add(
      http.MultipartFile.fromBytes(
        'avatar', // ✅ khớp backend param avatar: UploadFile = File(...)
        bytes,
        filename: filename,
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode ~/ 100 != 2) {
      throw Exception('Lỗi cập nhật avatar (HTTP ${res.statusCode}): ${res.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return AdminUserMe.fromJson(data);
  }

  /// ✅ ĐỔI MẬT KHẨU (FE) - yêu cầu backend phải có endpoint tương ứng
  ///
  /// Gợi ý endpoint: PUT /api/v1/me/change_password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final uri =
        Uri.parse('${ApiBase.baseURL}${ApiBase.api('/me/change_password')}');

    final payload = <String, dynamic>{
      'old_password': oldPassword,
      'new_password': newPassword,
    };

    final res = await _client.put(
      uri,
      headers: _headers(contentType: 'application/json'),
      body: jsonEncode(payload),
    );

    if (res.statusCode ~/ 100 != 2) {
      throw Exception('Lỗi đổi mật khẩu (HTTP ${res.statusCode}): ${res.body}');
    }
  }
}
