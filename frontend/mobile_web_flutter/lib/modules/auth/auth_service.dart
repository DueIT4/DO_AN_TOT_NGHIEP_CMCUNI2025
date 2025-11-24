// lib/modules/auth/auth_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_base.dart';

/// Key dùng để lưu access_token trong SharedPreferences / localStorage
const String _kBearerKey = 'access_token';

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
      Map<String, dynamic> res) async {
    final token = res['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Không tìm thấy access_token trong response');
    }
    ApiBase.bearer = token;
    await _saveBearer(token);
  }

  /// Kiểm tra đã đăng nhập chưa
  static bool get isLoggedIn {
    final token = ApiBase.bearer;
    return token != null && token.isNotEmpty;
  }

  // ======================= LOGIN BẰNG SĐT / EMAIL =======================

  /// Login backend bằng sđt hoặc email + password
  ///
  /// - `identifier`: người dùng nhập sđt hoặc email (1 ô input)
  /// - Backend của bạn phải chấp nhận field, ví dụ:
  ///     + nếu BE nhận "username": dùng cả phone/email vào "username"
  ///     + nếu BE nhận "login": đổi lại key ở đây.
  static Future<void> loginWithCredentials({
    required String identifier,
    required String password,
  }) async {
    // TODO: nếu BE của bạn dùng field khác (vd: "phone_or_email"),
    // thì đổi "username" thành key tương ứng.
    final body = <String, dynamic>{
      'username': identifier, // sđt hoặc email đều đưa vào đây
      'password': password,
    };

    final res = await ApiBase.postJson(
      ApiBase.api('/auth/login'),
      body,
    );

    // res là dynamic, ép sang Map
    final map = Map<String, dynamic>.from(res as Map);
    await _setBearerFromResponse(map);
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
          throw Exception('Người dùng huỷ Google Sign-In');
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
        throw Exception('Không lấy được Google ID token');
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
      rethrow;
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
          throw Exception('Người dùng huỷ Facebook Login');
        }
        fbAccessToken = fRes.accessToken!.tokenString;

        final cred = FacebookAuthProvider.credential(fbAccessToken);
        signed = await _fa.signInWithCredential(cred);
      }

      if (fbAccessToken == null) {
        throw Exception('Không lấy được Facebook access token');
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
      rethrow;
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
