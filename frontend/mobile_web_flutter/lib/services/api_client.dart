
// // =============================
// // lib/services/api_client.dart
// // =============================
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class ApiClient {
//   // ⚠️ Android emulator dùng 10.0.2.2, iOS simulator dùng localhost, thiết bị thật dùng IP LAN của PC
//   static const String baseUrl = String.fromEnvironment(
//     'API_BASE',
//     defaultValue: 'http://10.0.2.2:8000',
//   );

//   static Future<(bool, String)> login({required String identity, required String password}) async {
//     try {
//       final uri = Uri.parse('$baseUrl/api/v1/auth/login');
//       final res = await http.post(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'identity': identity, 'password': password}),
//       );
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         final token = data['access_token'] ?? '';
//         return (true, token);
//       }
//       return (false, 'Đăng nhập thất bại (${res.statusCode})');
//     } catch (e) {
//       return (false, 'Lỗi mạng: $e');
//     }
//   }

//   static Future<(bool, String)> register({
//     required String name,
//     required String identity, // phone hoặc email
//     required String password,
//   }) async {
//     try {
//       final uri = Uri.parse('$baseUrl/api/v1/auth/register');
//       final res = await http.post(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'full_name': name, 'identity': identity, 'password': password}),
//       );
//       if (res.statusCode == 201 || res.statusCode == 200) {
//         return (true, 'Tạo tài khoản thành công');
//       }
//       return (false, 'Đăng ký thất bại (${res.statusCode})');
//     } catch (e) {
//       return (false, 'Lỗi mạng: $e');
//     }
//   }

//   static Future<(bool, String)> loginWithGoogle(String idToken) async {
//     try {
//       final uri = Uri.parse('$baseUrl/api/v1/auth/google');
//       final res = await http.post(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'id_token': idToken}),
//       );
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         return (true, data['access_token'] ?? '');
//       }
//       return (false, 'Google login thất bại (${res.statusCode})');
//     } catch (e) {
//       return (false, 'Lỗi mạng: $e');
//     }
//   }

//   static Future<(bool, String)> loginWithFacebook(String accessToken) async {
//     try {
//       final uri = Uri.parse('$baseUrl/api/v1/auth/facebook');
//       final res = await http.post(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'access_token': accessToken}),
//       );
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         return (true, data['access_token'] ?? '');
//       }
//       return (false, 'Facebook login thất bại (${res.statusCode})');
//     } catch (e) {
//       return (false, 'Lỗi mạng: $e');
//     }
//   }
// }
// =============================
// lib/services/api_client.dart
// =============================
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // 💡 Thiết bị thật: đổi IP này thành IP LAN của PC (ví dụ 172.17.160.87)
  // Android emulator: 10.0.2.2
  // iOS simulator: localhost
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    // ĐỔI defaultValue bên dưới nếu bạn đang test trên điện thoại thật
    //defaultValue: 'http://10.0.2.2:8000',
    defaultValue: 'http://10.235.71.146:8000',

  );


  static Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
      };

  // ======================
  // ĐĂNG KÝ SỐ ĐIỆN THOẠI
  // ======================
  static Future<(bool, String)> registerPhone({
    required String username,
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/register/phone');
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          'username': username,
          'phone': phone,
          'password': password,
        }),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return (true, 'Đăng ký thành công. Vui lòng xác nhận theo hướng dẫn.');
      }
      return (false, _errMsg(res));
    } catch (e) {
      return (false, 'Lỗi mạng: $e');
    }
  }

  // ================
  // ĐĂNG NHẬP SỐ ĐT
  // ================
  static Future<(bool, String)> loginPhone({
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/login/phone');
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = (data is Map && data['access_token'] is String)
            ? data['access_token'] as String
            : '';
        if (token.isEmpty) return (false, 'Thiếu access_token từ server');
        return (true, token);
      }
      return (false, _errMsg(res));
    } catch (e) {
      return (false, 'Lỗi mạng: $e');
    }
  }

  // ===================
  // ĐĂNG NHẬP GOOGLE
  // ===================
  // FE nhận idToken từ google_sign_in → gọi BE /login/google { token: <idToken> }
  static Future<(bool, String)> loginWithGoogle(String idToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/login/google');
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'token': idToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = (data is Map && data['access_token'] is String)
            ? data['access_token'] as String
            : '';
        if (token.isEmpty) return (false, 'Thiếu access_token từ server');
        return (true, token);
      } else if (res.statusCode == 404) {
        return (false, 'Tài khoản Google chưa đăng ký');
      }
      return (false, _errMsg(res));
    } catch (e) {
      return (false, 'Lỗi mạng: $e');
    }
  }

  // (Tuỳ chọn) ĐĂNG KÝ GOOGLE khi chưa có tài khoản
  static Future<(bool, String)> registerGoogle({
    required String idToken,
    required String username,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/register/google');
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'id_token': idToken, 'username': username}),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return (true, 'Đăng ký Google thành công. Kiểm tra email nếu có xác nhận.');
      }
      return (false, _errMsg(res));
    } catch (e) {
      return (false, 'Lỗi mạng: $e');
    }
  }

  // =====================
  // ĐĂNG NHẬP FACEBOOK
  // =====================
  // FE nhận accessToken từ flutter_facebook_auth → gọi BE /login/facebook { token: <accessToken> }
  static Future<(bool, String)> loginWithFacebook(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/login/facebook');
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'token': accessToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = (data is Map && data['access_token'] is String)
            ? data['access_token'] as String
            : '';
        if (token.isEmpty) return (false, 'Thiếu access_token từ server');
        return (true, token);
      } else if (res.statusCode == 404) {
        return (false, 'Tài khoản Facebook chưa đăng ký');
      }
      return (false, _errMsg(res));
    } catch (e) {
      return (false, 'Lỗi mạng: $e');
    }
  }

  // (Tuỳ chọn) ĐĂNG KÝ FACEBOOK khi chưa có tài khoản
  static Future<(bool, String)> registerFacebook({
    required String accessToken,
    required String username,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/register/facebook');
    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'access_token': accessToken, 'username': username}),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return (true, 'Đăng ký Facebook thành công. Vui lòng xác nhận nếu có.');
      }
      return (false, _errMsg(res));
    } catch (e) {
      return (false, 'Lỗi mạng: $e');
    }
  }

  // =====================
  // Helper parse lỗi server
  // =====================
  static String _errMsg(http.Response res) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['detail'] != null) {
        return '${res.statusCode}: ${data['detail']}';
      }
    } catch (_) {}
    return 'Lỗi (${res.statusCode})';
  }
}
