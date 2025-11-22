// lib/core/admin_user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile_web_flutter/core/api_base.dart';

/// Kết quả trả về khi search có phân trang
class UserSearchResult {
  final int total;
  final List<Map<String, dynamic>> items;

  UserSearchResult({
    required this.total,
    required this.items,
  });
}

class AdminUserService {
  /// Lấy danh sách user (simple list – không phân trang)
  /// Backend: GET /users  (→ /api/v1/.../users tuỳ prefix trong main.py)
  static Future<List<Map<String, dynamic>>> listUsers() async {
    final res = await ApiBase.getJson(ApiBase.api('/users'));
    final list = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return list;
  }

  /// Lấy chi tiết 1 user để đổ vào form sửa
  /// Backend: GET /users/get/{user_id}
  static Future<Map<String, dynamic>> getUser(int userId) async {
    final res = await ApiBase.getJson(ApiBase.api('/users/get/$userId'));
    return Map<String, dynamic>.from(res as Map);
  }

  /// Tìm kiếm + phân trang user
  /// Backend: GET /users/search?q=&page=&size=&order_by=&order_dir=
  static Future<UserSearchResult> searchUsers({
    String? keyword,
    int page = 1,
    int size = 20,
    String orderBy = 'created_at',
    bool desc = true,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      'order_by': orderBy,
      'order_dir': desc ? 'desc' : 'asc',
    };

    if (keyword != null && keyword.trim().isNotEmpty) {
      params['q'] = keyword.trim();
    }

    final query = Uri(queryParameters: params).query;

    final res = await ApiBase.getJson(
      ApiBase.api('/users/search?$query'),
    );

    final map = Map<String, dynamic>.from(res as Map);
    final total = (map['total'] ?? 0) as int;
    final items = (map['items'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return UserSearchResult(total: total, items: items);
  }

  /// Xoá user theo ID
  /// Backend: DELETE /users/delete/{user_id}
    /// Xoá user theo ID
  /// Backend: DELETE /users/delete/{user_id}
  static Future<void> deleteUser(int userId) async {
    // URL đầy đủ: http://.../api/v1/users/delete/{id}
    final uri = Uri.parse(
      '${ApiBase.baseURL}${ApiBase.api('/users/delete/$userId')}',
    );

    // Header: kèm Bearer nếu có
    final token = ApiBase.bearer;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final resp = await http.delete(uri, headers: headers);

    if (resp.statusCode ~/ 100 != 2) {
      // Ném lỗi ra cho UI hiển thị
      throw Exception(
        'Xoá user thất bại (${resp.statusCode}): ${resp.body}',
      );
    }
    // 204/200 thì coi như xoá OK, không trả body
  }


  /// Tạo user mới (admin/support đăng ký user)
  /// Backend: POST /users/create (multipart/form-data)
  ///
  /// avatarPath: đường dẫn file ảnh local, nếu không upload thì để null.
   /// Tạo user mới (admin/support đăng ký user)
  /// Backend: POST /users/create (multipart/form-data)
  ///
    /// Tạo user mới (admin/support đăng ký user)
  static Future<Map<String, dynamic>> createUser({
    required String username,
    required String phone,
    required String password,
    String? email,
    String? address,
    int? roleId,
    String? avatarPath,
  }) async {
    // URL đầy đủ: baseURL + apiPrefix + path
    final uri = Uri.parse('${ApiBase.baseURL}${ApiBase.api('/users/create')}');

    final request = http.MultipartRequest('POST', uri);

    // 🔐 Gửi kèm Bearer token nếu có
    final token = ApiBase.bearer;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';

    request.fields['username'] = username;
    request.fields['phone'] = phone;
    request.fields['password'] = password;
    if (email != null) request.fields['email'] = email;
    if (address != null) request.fields['address'] = address;
    if (roleId != null) request.fields['role_id'] = roleId.toString();

    if (avatarPath != null && avatarPath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('file', avatarPath));
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json;
    } else {
      throw Exception(
        'Tạo user thất bại (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  /// Cập nhật user (sửa thông tin + avatar)
  static Future<Map<String, dynamic>> updateUser({
    required int userId,
    String? username,
    String? phone,
    String? password,
    String? email,
    String? address,
    int? roleId,
    String? avatarPath,
  }) async {
    final uri =
        Uri.parse('${ApiBase.baseURL}${ApiBase.api('/users/update/$userId')}');

    final request = http.MultipartRequest('PUT', uri);

    final token = ApiBase.bearer;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';

    if (username != null) request.fields['username'] = username;
    if (phone != null) request.fields['phone'] = phone;
    if (password != null) request.fields['password'] = password;
    if (email != null) request.fields['email'] = email;
    if (address != null) request.fields['address'] = address;
    if (roleId != null) request.fields['role_id'] = roleId.toString();

    if (avatarPath != null && avatarPath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('file', avatarPath));
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json;
    } else {
      throw Exception(
        'Cập nhật user thất bại (${resp.statusCode}): ${resp.body}',
      );
    }
  }


  /// Lọc danh sách user đã load sẵn ở FE theo role/status
  /// (dùng cho lọc đơn giản trên UI, không gọi lại API)
  static List<Map<String, dynamic>> filterByRoleStatus(
    List<Map<String, dynamic>> users, {
    String? roleType, // 'admin', 'support_admin', 'viewer'
    String? status,   // 'active', 'inactive'
  }) {
    return users.where((u) {
      final r = (u['role_type'] ?? '').toString().toLowerCase();
      final s = (u['status'] ?? '').toString().toLowerCase();

      final okRole =
          roleType == null || roleType.isEmpty || r == roleType.toLowerCase();
      final okStatus =
          status == null || status.isEmpty || s == status.toLowerCase();

      return okRole && okStatus;
    }).toList();
  }
}
