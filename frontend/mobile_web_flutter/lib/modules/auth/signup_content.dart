import 'package:flutter/material.dart';
import '../../core/api_base.dart';
import '../../src/routes/web_routes.dart';
import 'auth_service.dart';

class SignupContent extends StatefulWidget {
  const SignupContent({super.key});
  @override
  State<SignupContent> createState() => _SignupContentState();
}

class _SignupContentState extends State<SignupContent> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _pass2 = TextEditingController();
  final _name  = TextEditingController();
  final _form  = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_form.currentState!.validate()) return;
    if (_pass.text != _pass2.text) {
      setState(() => _error = 'Mật khẩu nhập lại không khớp');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Gọi API đăng ký (chọn 1 trong 2 – tuỳ backend bạn đang expose)
      // a) Nếu bạn đã có /auth/register:
      final _ = await ApiBase.postJson(ApiBase.api('/auth/register'), {
        'email': _email.text.trim(),
        'password': _pass.text,
        'username': _name.text.trim().isEmpty ? null : _name.text.trim(),
      });

      // b) Hoặc nếu bạn chỉ có /users/ (tạo user) thì dùng:
      // final _ = await ApiBase.postJson(ApiBase.api('/users/'), {
      //   'email': _email.text.trim(),
      //   'password': _pass.text,
      //   'username': _name.text.trim().isEmpty ? null : _name.text.trim(),
      // });

      // Sau đăng ký → tự đăng nhập
      final resLogin = await ApiBase.postJson(ApiBase.api('/auth/login'), {
        'email': _email.text.trim(),
        'password': _pass.text,
      });
      ApiBase.bearer = resLogin['access_token'] as String?;

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, WebRoutes.home, (r) => false);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.loginWithGoogle();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, WebRoutes.home, (r) => false);
    } catch (e) {
      setState(() => _error = 'Google đăng ký/đăng nhập lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _facebook() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.loginWithFacebook();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, WebRoutes.home, (r) => false);
    } catch (e) {
      setState(() => _error = 'Facebook đăng ký/đăng nhập lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Tên hiển thị (tuỳ chọn)'),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập email' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mật khẩu tối thiểu 6 ký tự' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _pass2,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập lại mật khẩu' : null,
                  ),

                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),

                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loading ? null : _signup,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.green.shade700,
                    ),
                    child: _loading
                        ? const SizedBox(height:18, width:18, child: CircularProgressIndicator(strokeWidth:2))
                        : const Text('Đăng ký'),
                  ),

                  const SizedBox(height: 16),
                  const Divider(thickness: 1, height: 30),
                  const Text('Hoặc dùng Google / Facebook'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _google,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Google'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _facebook,
                        icon: const Icon(Icons.facebook, size: 28),
                        label: const Text('Facebook'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _loading ? null : () {
                      Navigator.pushNamed(context, WebRoutes.login);
                    },
                    child: const Text("Đã có tài khoản? Đăng nhập"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
