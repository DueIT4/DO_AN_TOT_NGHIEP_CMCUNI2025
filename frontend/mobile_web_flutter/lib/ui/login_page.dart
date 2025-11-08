
// =============================
// lib/ui/login_page.dart
// =============================
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _identityCtrl = TextEditingController(); // phone/email
  final _passCtrl = TextEditingController();
  final _repassCtrl = TextEditingController();

  bool _secure1 = true;
  bool _secure2 = true;
  bool _agree = false;
  bool _isRegister = false; // chuyển giữa Đăng nhập / Đăng ký
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identityCtrl.dispose();
    _passCtrl.dispose();
    _repassCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isRegister && !_agree) {
      _showSnack('Bạn cần đồng ý Điều khoản & Chính sách.');
      return;
    }
    setState(() => _loading = true);

    if (_isRegister) {
      final (ok, msg) = await ApiClient.register(
        name: _nameCtrl.text.trim(),
        identity: _identityCtrl.text.trim(),
        password: _passCtrl.text,
      );
      setState(() => _loading = false);
      if (ok) {
        _showSnack('Đăng ký thành công! Hãy đăng nhập.');
        setState(() => _isRegister = false);
      } else {
        _showSnack(msg);
      }
    } else {
      final (ok, token) = await ApiClient.login(
        identity: _identityCtrl.text.trim(),
        password: _passCtrl.text,
      );
      setState(() => _loading = false);
      if (ok) {
        _showSnack('Đăng nhập OK, token: ${token.substring(0, token.length > 12 ? 12 : token.length)}...');
        // TODO: chuyển sang HomePage
      } else {
        _showSnack(token);
      }
    }
  }

  Future<void> _handleGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) return; // user cancel
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _showSnack('Không lấy được idToken từ Google');
        return;
      }
      setState(() => _loading = true);
      final (ok, token) = await ApiClient.loginWithGoogle(idToken);
      setState(() => _loading = false);
      _showSnack(ok ? 'Google OK: ${token.substring(0, 12)}...' : token);
    } catch (e) {
      _showSnack('Google lỗi: $e');
    }
  }

  Future<void> _handleFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
      if (result.status != LoginStatus.success) {
        _showSnack('Facebook: ${result.status.name}');
        return;
      }
      final token = result.accessToken?.tokenString;
      if (token == null) {
        _showSnack('Không lấy được accessToken từ Facebook');
        return;
      }
      setState(() => _loading = true);
      final (ok, jwt) = await ApiClient.loginWithFacebook(token);
      setState(() => _loading = false);
      _showSnack(ok ? 'Facebook OK: ${jwt.substring(0, 12)}...' : jwt);
    } catch (e) {
      _showSnack('Facebook lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? 'Đăng ký tài khoản' : 'Đăng nhập';
    final actionText = _isRegister ? 'Đăng ký' : 'Đăng nhập';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDFF0C8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.spa_rounded, size: 36, color: Color(0xFF7CCD2B)),
                        ),
                        const SizedBox(width: 10),
                        Text('ZestGuard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      _isRegister ? 'Vui lòng điền thông tin tài khoản' : 'Chào mừng bạn quay lại',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (_isRegister) ...[
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(hintText: 'Họ và tên', prefixIcon: Icon(Icons.person_outline)),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Họ tên không được trống' : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _identityCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(hintText: 'Số điện thoại hoặc email', prefixIcon: Icon(Icons.call_outlined)),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập email/điện thoại' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _secure1,
                            decoration: InputDecoration(
                              hintText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_secure1 ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _secure1 = !_secure1),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6) ? 'Ít nhất 6 ký tự' : null,
                          ),
                          if (_isRegister) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _repassCtrl,
                              obscureText: _secure2,
                              decoration: InputDecoration(
                                hintText: 'Nhập lại mật khẩu',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_secure2 ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _secure2 = !_secure2),
                                ),
                              ),
                              validator: (v) => (_isRegister && v != _passCtrl.text) ? 'Mật khẩu không khớp' : null,
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (_isRegister)
                            CheckboxListTile(
                              value: _agree,
                              dense: true,
                              onChanged: (v) => setState(() => _agree = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Wrap(
                                children: [
                                  const Text('Tôi đồng ý với '),
                                  Text('Điều khoản sử dụng', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                  const Text(' và '),
                                  Text('Chính sách bảo mật', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton(
                              onPressed: _loading ? null : _handleSubmit,
                              child: _loading ? const CircularProgressIndicator() : Text(actionText, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(children: const [Expanded(child: Divider()), SizedBox(width: 8), Text('Hoặc đăng nhập bằng'), SizedBox(width: 8), Expanded(child: Divider())]),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _handleGoogle,
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Google'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _handleFacebook,
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('Facebook'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _isRegister = !_isRegister),
                      child: Text(_isRegister ? 'Đã có tài khoản? Đăng nhập ngay' : 'Chưa có tài khoản? Đăng ký ngay'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
