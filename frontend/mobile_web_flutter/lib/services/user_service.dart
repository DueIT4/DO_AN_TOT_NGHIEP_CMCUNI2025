import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../core/api_base_app.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

class UserService {
  UserService._();

  // -------------------------
  // Helpers
  // -------------------------
  static Map<String, dynamic> _decodeJsonMap(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Không đọc được dữ liệu phản hồi từ máy chủ.');
    }
  }

  // ✅ CẬP NHẬT: Xử lý thông minh cho Cloudinary URL
  static String _resolveUrl(dynamic raw) {
    if (raw == null) return '';
    final v = raw.toString();
    if (v.isEmpty) return '';
    
    // Nếu là link tuyệt đối (Cloudinary), trả về luôn
    if (v.startsWith('http')) return v;

    // Nếu là link tương đối cũ, ghép với host
    return '${ApiBase.host}$v';
  }

  static UserProfile _mapProfile(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['avt_url'] = _resolveUrl(data['avt_url']);
    return UserProfile.fromJson(normalized);
  }

  static void _requireAuth() {
    final token = ApiClient.authToken;
    if (token == null || token.isEmpty) {
      throw Exception('NOT_AUTHENTICATED');
    }
  }

  // -------------------------
  // GET /me/get_me
  // -------------------------
  static Future<UserProfile> fetchProfile() async {
    _requireAuth();
    final uri = ApiBase.uri('/me/get_me');

    try {
      final resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Lỗi lấy thông tin: ${resp.statusCode}');
      }

      final data = _decodeJsonMap(resp.body);
      return _mapProfile(data);
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  // -------------------------
  // PUT /me/update_me
  // -------------------------
  static Future<UserProfile> updateProfile({
    String? username,
    String? phone,
    String? email,
    String? address,
  }) async {
    _requireAuth();
    final uri = ApiBase.uri('/me/update_me');

    final body = <String, String>{};
    if (username != null) body['username'] = username;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;

    final resp = await http.put(
      uri,
      headers: ApiClient.authHeaders(
        json: false,
        extra: const {'Content-Type': 'application/x-www-form-urlencoded'},
      ),
      body: body,
    ).timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Cập nhật thất bại');
    }

    final data = _decodeJsonMap(resp.body);
    return _mapProfile(data);
  }

  // -------------------------
  // POST /me/update_avatar
  // BE: Đẩy bytes trực tiếp lên Cloudinary
  // -------------------------
  static Future<UserProfile> uploadAvatar(XFile file) async {
    _requireAuth();
    final uri = ApiBase.uri('/me/update_avatar');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(ApiClient.authHeaders(json: false));

    var filename = file.name.isEmpty ? 'avatar.jpg' : file.name;
    final mimeType = lookupMimeType(filename) ?? 'image/jpeg';
    final mediaType = MediaType.parse(mimeType);

    // Xử lý upload cho cả Web và Mobile
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'avatar', 
        bytes,
        filename: filename,
        contentType: mediaType,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        file.path,
        filename: filename,
        contentType: mediaType,
      ));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Upload avatar thất bại');
    }

    final data = _decodeJsonMap(resp.body);
    return _mapProfile(data);
  }

  // -------------------------
  // PUT /me/change_password
  // -------------------------
  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _requireAuth();
    final uri = ApiBase.uri('/me/change_password');

    final resp = await http.put(
      uri,
      headers: ApiClient.authHeaders(),
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    ).timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Đổi mật khẩu thất bại');
    }
  }
}