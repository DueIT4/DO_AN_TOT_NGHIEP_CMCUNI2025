import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../core/api_base.dart';
import '../../src/routes/web_routes.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  // ===== Đăng ký bằng SĐT =====
  Future<void> _registerPhone() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiBase.postJson(ApiBase.api('/auth/register/phone'), {
        'username': _username.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
      });
      
      // Đăng ký thành công - hiển thị thông báo
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Đã gửi xác nhận về số điện thoại')),
      );
      
      // Chuyển đến trang login
      Navigator.pushReplacementNamed(context, WebRoutes.login);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Đăng ký bằng Google =====
  Future<void> _registerGoogle() async {
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập username');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final firebaseAuth = FirebaseAuth.instance;
      UserCredential signed;

      if (kIsWeb) {
        // Web: dùng popup của Firebase
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        signed = await firebaseAuth.signInWithPopup(provider);
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
        signed = await firebaseAuth.signInWithCredential(cred);
      }

      final idToken = await signed.user!.getIdToken();
      final res = await ApiBase.postJson(ApiBase.api('/auth/register/google'), {
        'username': _username.text.trim(),
        'id_token': idToken,
      });

      // Đăng ký thành công - đăng nhập luôn
      final loginRes = await ApiBase.postJson(ApiBase.api('/auth/login/google'), {
        'token': idToken,
      });
      ApiBase.bearer = loginRes['access_token'] as String?;

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, WebRoutes.home, (r) => false);
    } catch (e) {
      setState(() => _error = 'Google đăng ký lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Đăng ký bằng Facebook =====
  Future<void> _registerFacebook() async {
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập username');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Dùng FacebookAuth cho cả web và mobile để lấy access_token
      final fRes = await FacebookAuth.instance.login(permissions: ['email']);
      if (fRes.accessToken == null) {
        throw Exception('Người dùng huỷ Facebook Login');
      }
      final accessToken = fRes.accessToken!.tokenString;

      final res = await ApiBase.postJson(ApiBase.api('/auth/register/facebook'), {
        'username': _username.text.trim(),
        'access_token': accessToken,
      });

      // Đăng ký thành công - đăng nhập luôn
      final loginRes = await ApiBase.postJson(ApiBase.api('/auth/login/facebook'), {
        'token': accessToken,
      });
      ApiBase.bearer = loginRes['access_token'] as String?;

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, WebRoutes.home, (r) => false);
    } catch (e) {
      setState(() => _error = 'Facebook đăng ký lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Đăng ký tài khoản',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập username' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'Số điện thoại'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập số điện thoại' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null,
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loading ? null : _registerPhone,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.green.shade700,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Đăng ký bằng SĐT'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _registerGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Google'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _registerFacebook,
                        icon: const Icon(Icons.facebook, size: 24),
                        label: const Text('Facebook'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, WebRoutes.login),
                    child: const Text('Đã có tài khoản? Đăng nhập'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}