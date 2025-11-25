import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../core/api_base.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class UserService {
  static Future<UserProfile> fetchProfile() async {
    final token = ApiClient.authToken;
    if (token == null || token.isEmpty) {
      return UserProfile.placeholder();
    }

    final uri = Uri.parse(ApiBase.api('/me/get_me'));
    try {
      final resp = await http.get(
        uri,
        headers: ApiClient.authHeaders(),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return _mapProfile(data);
      }
    } catch (e, s) {
      debugPrint('fetchProfile error: $e\n$s');
    }
    return UserProfile.placeholder();
  }

  static Future<UserProfile> updateProfile({
    String? username,
    String? phone,
    String? email,
    String? address,
  }) async {
    final token = ApiClient.authToken;
    if (token == null || token.isEmpty) {
      return UserProfile.placeholder();
    }

    final uri = Uri.parse(ApiBase.api('/me/update_me'));
    final body = <String, String>{};
    if (username != null) body['username'] = username;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;

    try {
      final resp = await http.put(
        uri,
        headers: ApiClient.authHeaders(json: false, extra: {
          'Content-Type': 'application/x-www-form-urlencoded',
        }),
        body: body,
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return _mapProfile(data);
      } else {
        debugPrint('updateProfile failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e, s) {
      debugPrint('updateProfile error: $e\n$s');
    }
    return UserProfile.placeholder();
  }

  static Future<UserProfile> uploadAvatar(XFile file) async {
    final token = ApiClient.authToken;
    if (token == null || token.isEmpty) {
      throw Exception('NOT_AUTHENTICATED');
    }

    final uri = Uri.parse(ApiBase.api('/me/avatar'));
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    String filename = file.name;
    if (filename.isEmpty) {
      final segments = file.path.split('/');
      filename = segments.isNotEmpty && segments.last.isNotEmpty
          ? segments.last
          : 'avatar.png';
    }

    // === ĐOÁN MIME TYPE & TẠO MediaType (RẤT QUAN TRỌNG) ===
    final mimeType = lookupMimeType(filename) ?? 'image/jpeg';
    final parts = mimeType.split('/'); // ví dụ: ['image', 'jpeg']
    final mediaType = MediaType(parts[0], parts[1]); // image/jpeg

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', // tên field phải trùng với FastAPI: file: UploadFile = File(...)
          bytes,
          filename: filename,
          contentType: mediaType, // <-- bắt buộc
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: filename,
          contentType: mediaType, // <-- bắt buộc
        ),
      );
    }

    try {
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return _mapProfile(data);
      }
      throw Exception(
        'Upload avatar failed (${resp.statusCode}): ${resp.body}',
      );
    } catch (e, s) {
      debugPrint('uploadAvatar error: $e\n$s');
      rethrow;
    }
  }

  static UserProfile _mapProfile(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['avt_url'] = _resolveAvatarUrl(data['avt_url']);
    return UserProfile.fromJson(normalized);
  }

  static String _resolveAvatarUrl(dynamic raw) {
    if (raw == null) return '';
    final value = raw.toString();
    if (value.isEmpty) return '';
    if (value.startsWith('http')) return value;
    return '${ApiBase.host}$value';
  }
}
