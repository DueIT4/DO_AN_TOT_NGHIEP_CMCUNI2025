import 'package:flutter/material.dart';
import '../../core/api_base.dart';
import '../../src/routes/web_routes.dart';
import '../../core/user_service.dart';
import 'auth_service.dart'; // ✅ thêm

class LoginContent extends StatefulWidget {
  final String? returnTo;
  const LoginContent({super.key, this.returnTo});

  @override
  State<LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<LoginContent> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // ===== Đăng nhập bằng email & mật khẩu =====
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiBase.postJson(ApiBase.api('/auth/login'), {
        'email': _email.text.trim(),
        'password': _pass.text,
      });

      ApiBase.bearer = res['access_token'] as String?;
      
      // Clear cache để load lại thông tin user
      UserService.clearCache();
      await UserService.getCurrentUser(forceRefresh: true);

      if (!mounted) return;
      final next = widget.returnTo ?? WebRoutes.home;
      Navigator.pushNamedAndRemoveUntil(context, next, (r) => false);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Đăng nhập Google =====
  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      await AuthService.loginWithGoogle();
      
      // Clear cache để load lại thông tin user
      UserService.clearCache();
      await UserService.getCurrentUser(forceRefresh: true);
      
      if (!mounted) return;
      final next = widget.returnTo ?? WebRoutes.home;
      Navigator.pushNamedAndRemoveUntil(context, next, (r) => false);
    } catch (e) {
      setState(() => _error = 'Google login lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Đăng nhập Facebook =====
  Future<void> _facebookLogin() async {
    setState(() => _loading = true);
    try {
      await AuthService.loginWithFacebook();
      
      // Clear cache để load lại thông tin user
      UserService.clearCache();
      await UserService.getCurrentUser(forceRefresh: true);
      
      if (!mounted) return;
      final next = widget.returnTo ?? WebRoutes.home;
      Navigator.pushNamedAndRemoveUntil(context, next, (r) => false);
    } catch (e) {
      setState(() => _error = 'Facebook login lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArg = ModalRoute.of(context)?.settings.arguments;
    final returnTo = widget.returnTo ?? (routeArg is String ? routeArg : null);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Đăng nhập',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  if (returnTo != null)
                    Text('Bạn cần đăng nhập để truy cập $returnTo',
                        style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Nhập email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, WebRoutes.forgotPassword);
                      },
                      child: const Text('Quên mật khẩu?'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.green.shade700,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Đăng nhập'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1, height: 30),
                  const Text('Hoặc đăng nhập bằng'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _googleLogin,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Google'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _facebookLogin,
                        icon: const Icon(Icons.facebook, size: 28),
                        label: const Text('Facebook'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                Navigator.pushNamed(context, WebRoutes.register);
                              },
                        child: const Text("Chưa có tài khoản? Đăng ký"),
                      ),
                    ],
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
