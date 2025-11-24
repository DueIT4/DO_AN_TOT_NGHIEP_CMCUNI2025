import 'package:flutter/material.dart';
import '../../core/api_base.dart';
import '../../src/routes/web_routes.dart';
import '../../core/user_service.dart';

class LoginContent extends StatefulWidget {
  final String? returnTo;
  const LoginContent({super.key, this.returnTo});

  @override
  State<LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<LoginContent> {
  final _accountCtrl = TextEditingController(); // email hoặc sđt
  final _passCtrl = TextEditingController();
  final _form = GlobalKey<FormState>();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final input = _accountCtrl.text.trim();

      Map<String, dynamic> body;

      // Có ký tự @ → login bằng email
      if (input.contains('@')) {
        body = {
          'email': input,
          'password': _passCtrl.text,
        };
      } else {
        // Không có @ → login bằng sđt
        body = {
          'phone': input,
          'password': _passCtrl.text,
        };
      }

      final res = await ApiBase.postJson(ApiBase.api('/auth/login'), body);

      // Lưu token
      ApiBase.bearer = res['access_token'] as String?;

      // Clear cache & load lại user hiện tại
      UserService.clearCache();
      await UserService.getCurrentUser(forceRefresh: true);

      if (!mounted) return;
      final next = widget.returnTo ?? WebRoutes.home;
      Navigator.pushNamedAndRemoveUntil(context, next, (r) => false);
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
                  Text(
                    'Đăng nhập',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (returnTo != null)
                    Text(
                      'Bạn cần đăng nhập để truy cập $returnTo',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  const SizedBox(height: 16),

                  // ===== Input email hoặc sđt =====
                  TextFormField(
                    controller: _accountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email hoặc Số điện thoại',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập email hoặc số điện thoại';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ===== Input mật khẩu =====
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Mật khẩu'),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // ===== Quên mật khẩu =====
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(
                            context, WebRoutes.forgotPassword);
                      },
                      style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== Hiển thị lỗi =====
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ===== Nút đăng nhập =====
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Đăng nhập'),
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
