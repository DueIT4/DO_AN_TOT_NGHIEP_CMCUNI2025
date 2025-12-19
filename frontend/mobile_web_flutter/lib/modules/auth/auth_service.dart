// lib/modules/auth/auth_service.dart
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_base.dart';

/// Key dùng để lưu access_token trong SharedPreferences / localStorage
const String _kBearerKey = 'access_token';

/// Exception chuẩn hoá lỗi auth để UI hiển thị rõ ràng (không lòi lỗi API)
class AuthException implements Exception {
  final String message;
  final int? statusCode;
  final String? code; // code từ backend nếu có
  final Object? original;

  AuthException(
    this.message, {
    this.statusCode,
    this.code,
    this.original,
  });

  @override
  String toString() => message; // ✅ UI dùng '$e' sẽ ra message sạch
}

class AuthService {
  static final _fa = FirebaseAuth.instance;

  // ================== QUẢN LÝ TOKEN (LƯU / KHÔI PHỤC) ==================

  /// Lưu bearer token xuống storage (SharedPreferences)
  static Future<void> _saveBearer(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_kBearerKey);
    } else {
      await prefs.setString(_kBearerKey, token);
    }
  }

  /// Gọi ở main() để khôi phục token khi app khởi động / F5
  static Future<void> restoreBearer() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kBearerKey);
    ApiBase.bearer = token;
  }

  /// Nếu ở chỗ khác bạn đã gán ApiBase.bearer rồi, dùng hàm này để lưu lại
  static Future<void> persistCurrentBearer() async {
    await _saveBearer(ApiBase.bearer);
  }

  /// Đọc access_token từ response backend, gán vào ApiBase.bearer và lưu
  static Future<void> _setBearerFromResponse(
    Map<String, dynamic> res,
  ) async {
    final token = res['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw AuthException('Không tìm thấy access_token trong response');
    }
    ApiBase.bearer = token;
    await _saveBearer(token);
  }

  /// Kiểm tra đã đăng nhập chưa
  static bool get isLoggedIn {
    final token = ApiBase.bearer;
    return token != null && token.isNotEmpty;
  }

  // ================== CHUẨN HOÁ LỖI (KHÔNG LÒI API) ==================

  /// Cố gắng rút statusCode + payload message/code từ mọi kiểu error (Dio/http/custom)
  static AuthException _mapAuthError(Object e) {
    if (e is AuthException) return e;

    int? status;
    String? backendMessage;
    String? backendCode;

    // ✅ Tránh phụ thuộc Dio bằng cách đọc "dynamic" (nếu e là DioException thì vẫn có response/statusCode/data)
    try {
      final dynamic err = e;

      // status code
      status = err?.response?.statusCode as int?;

      // response data (thường là Map hoặc String)
      final dynamic data = err?.response?.data;

      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        backendMessage = (map['message'] ?? map['error'] ?? map['detail'])?.toString();
        backendCode = (map['code'] ?? map['error_code'])?.toString();
      } else if (data is String) {
        backendMessage = data;
      }
    } catch (_) {
      // ignore parsing errors
    }

    // ✅ Nếu backend đã trả message rõ -> ưu tiên dùng
    if (backendMessage != null && backendMessage.trim().isNotEmpty) {
      return AuthException(
        backendMessage.trim(),
        statusCode: status,
        code: backendCode,
        original: e,
      );
    }

    // ✅ Nếu chưa lấy được payload -> map theo status hoặc text
    final lower = e.toString().toLowerCase();

    // Mạng / timeout
    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return AuthException('Không có kết nối mạng. Vui lòng thử lại.', statusCode: status, original: e);
    }

    // Map theo HTTP status phổ biến
    switch (status) {
      case 400:
        return AuthException('Dữ liệu gửi lên không hợp lệ.', statusCode: status, original: e);
      case 401:
        // Nếu BE không phân biệt, dùng message chung cho chắc
        return AuthException('Sai mật khẩu hoặc tài khoản không tồn tại.', statusCode: status, original: e);
      case 403:
        return AuthException('Tài khoản không có quyền truy cập.', statusCode: status, original: e);
      case 404:
        return AuthException('Tài khoản chưa đăng ký.', statusCode: status, original: e);
      case 409:
        return AuthException('Tài khoản đã tồn tại hoặc xung đột dữ liệu.', statusCode: status, original: e);
      case 422:
        return AuthException('Thông tin đăng nhập không hợp lệ.', statusCode: status, original: e);
      case 500:
      case 502:
      case 503:
      case 504:
        return AuthException('Máy chủ đang bận. Vui lòng thử lại sau.', statusCode: status, original: e);
    }

    // Nếu error string có chứa 401/404... nhưng không parse được status
    if (lower.contains('401')) {
      return AuthException('Sai mật khẩu hoặc tài khoản không tồn tại.', statusCode: 401, original: e);
    }
    if (lower.contains('404')) {
      return AuthException('Tài khoản chưa đăng ký.', statusCode: 404, original: e);
    }
    if (lower.contains('422')) {
      return AuthException('Thông tin đăng nhập không hợp lệ.', statusCode: 422, original: e);
    }

    return AuthException('Đăng nhập thất bại. Vui lòng thử lại.', statusCode: status, original: e);
  }

  // ======================= LOGIN BẰNG SĐT / EMAIL =======================

  /// Login backend bằng sđt hoặc email + password
  ///
  /// - `identifier`: người dùng nhập sđt hoặc email (1 ô input)
  /// - Backend đang mong:
  ///     + nếu là email  -> field "email"
  ///     + nếu là sđt    -> field "phone"
  static Future<void> loginWithCredentials({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    final isEmail = trimmed.contains('@');

    final body = <String, dynamic>{
      if (isEmail) 'email': trimmed else 'phone': trimmed,
      'password': password,
    };

    try {
      final res = await ApiBase.postJson(
        ApiBase.api('/auth/login'),
        body,
      );

      // res là dynamic, ép sang Map
      final map = Map<String, dynamic>.from(res as Map);
      await _setBearerFromResponse(map);
    } catch (e) {
      if (kDebugMode) {
        // log dev để debug, nhưng UI vẫn hiển thị message sạch
        // ignore: avoid_print
        print('[AuthService] loginWithCredentials error: $e');
      }
      throw _mapAuthError(e);
    }
  }

  // ============================ GOOGLE LOGIN ============================

  /// GOOGLE LOGIN -> gọi BE /auth/login/google, nhận access_token và lưu
  static Future<void> loginWithGoogle() async {
    try {
      UserCredential signed;
      String? idToken;

      if (kIsWeb) {
        // Web: dùng popup Firebase, lấy idToken từ OAuthCredential
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        signed = await _fa.signInWithPopup(provider);

        final cred = signed.credential as OAuthCredential?;
        idToken = cred?.idToken;
      } else {
        // Mobile: google_sign_in -> credential -> FirebaseAuth
        final g = GoogleSignIn(scopes: const ['email', 'profile']);
        final gUser = await g.signIn();
        if (gUser == null) {
          throw AuthException('Bạn đã huỷ đăng nhập Google.');
        }
        final gAuth = await gUser.authentication;
        idToken = gAuth.idToken;

        final cred = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        await _fa.signInWithCredential(cred);
      }

      if (idToken == null) {
        throw AuthException('Không lấy được Google ID token.');
      }

      // Gửi token lên backend để verify & tạo JWT
      final res = await ApiBase.postJson(
        ApiBase.api('/auth/login/google'),
        {
          'token': idToken, // SocialLoginIn.token
        },
      );

      final map = Map<String, dynamic>.from(res as Map);
      await _setBearerFromResponse(map);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AuthService] loginWithGoogle error: $e');
      }
      throw _mapAuthError(e);
    }
  }

  // =========================== FACEBOOK LOGIN ===========================

  /// FACEBOOK LOGIN -> /auth/login/facebook
  static Future<void> loginWithFacebook() async {
    try {
      UserCredential signed;
      String? fbAccessToken;

      if (kIsWeb) {
        // Web: dùng popup Firebase cho Facebook
        final provider = FacebookAuthProvider();
        signed = await _fa.signInWithPopup(provider);
        final cred = signed.credential as OAuthCredential?;
        fbAccessToken = cred?.accessToken;
      } else {
        // Mobile: flutter_facebook_auth -> credential -> FirebaseAuth
        final fRes = await FacebookAuth.instance.login(
          permissions: ['email'],
        );
        if (fRes.accessToken == null) {
          throw AuthException('Bạn đã huỷ đăng nhập Facebook.');
        }
        fbAccessToken = fRes.accessToken!.tokenString;

        final cred = FacebookAuthProvider.credential(fbAccessToken);
        signed = await _fa.signInWithCredential(cred);
      }

      if (fbAccessToken == null) {
        throw AuthException('Không lấy được Facebook access token.');
      }

      // Gửi token lên backend để verify & tạo JWT
      final res = await ApiBase.postJson(
        ApiBase.api('/auth/login/facebook'),
        {
          'token': fbAccessToken, // SocialLoginIn.token
        },
      );

      final map = Map<String, dynamic>.from(res as Map);
      await _setBearerFromResponse(map);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AuthService] loginWithFacebook error: $e');
      }
      throw _mapAuthError(e);
    }
  }

  // =============================== LOGOUT ===============================

  static Future<void> logout() async {
    try {
      // Nếu bạn cần signOut Firebase (khi dùng social login) thì giữ lại
      await _fa.signOut();
    } finally {
      ApiBase.bearer = null;
      await _saveBearer(null); // xoá token trong storage
    }
  }
}
