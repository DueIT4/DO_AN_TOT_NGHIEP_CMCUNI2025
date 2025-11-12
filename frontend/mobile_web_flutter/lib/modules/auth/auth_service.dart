import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../core/api_base.dart';

class AuthService {
  static final _fa = FirebaseAuth.instance;

  /// ----- GOOGLE -----
  static Future<void> loginWithGoogle() async {
    try {
      UserCredential signed;

      if (kIsWeb) {
        // Web: dùng popup của Firebase, KHÔNG cần meta clientId
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        signed = await _fa.signInWithPopup(provider);
      } else {
        // Mobile: dùng google_sign_in -> credential -> FirebaseAuth
        final g = GoogleSignIn(scopes: const ['email', 'profile']);
        final gUser = await g.signIn();
        if (gUser == null) {
          throw Exception('Người dùng huỷ Google Sign-In');
        }
        final gAuth = await gUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: gAuth.accessToken,
          idToken: gAuth.idToken,
        );
        signed = await _fa.signInWithCredential(cred);
      }

      final idToken = await signed.user!.getIdToken();
      final res = await ApiBase.postJson(ApiBase.api('/auth/firebase'), {
        'id_token': idToken,
      });
      ApiBase.bearer = res['access_token'] as String?;
    } catch (e) {
      rethrow;
    }
  }

  /// ----- FACEBOOK -----
  static Future<void> loginWithFacebook() async {
    try {
      UserCredential signed;

      if (kIsWeb) {
        // Web: dùng popup Firebase cho Facebook
        final provider = FacebookAuthProvider();
        signed = await _fa.signInWithPopup(provider);
      } else {
        // Mobile: dùng flutter_facebook_auth -> credential -> FirebaseAuth
        final fRes = await FacebookAuth.instance.login(permissions: ['email']);
        if (fRes.accessToken == null) {
          throw Exception('Người dùng huỷ Facebook Login');
        }
        final cred =
            FacebookAuthProvider.credential(fRes.accessToken!.tokenString);
        signed = await _fa.signInWithCredential(cred);
      }

      final idToken = await signed.user!.getIdToken();
      final res = await ApiBase.postJson(ApiBase.api('/auth/firebase'), {
        'id_token': idToken,
      });
      ApiBase.bearer = res['access_token'] as String?;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    try {
      await _fa.signOut();
    } finally {
      ApiBase.bearer = null;
    }
  }
}
