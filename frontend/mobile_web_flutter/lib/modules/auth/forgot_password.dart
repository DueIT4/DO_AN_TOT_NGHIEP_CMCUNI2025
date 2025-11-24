import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/src/routes/web_routes.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController(); // email hoặc phone

  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final input = _identifierCtrl.text.trim();
      Map<String, dynamic> body;

      if (input.contains('@')) {
        // Email
        body = {'email': input};
      } else {
        // SĐT
        body = {'phone': input};
      }

      final res = await ApiBase.postJson(
        ApiBase.api('/auth/forgot-password'),
        body,
      );

      if (!mounted) return;

      setState(() {
        _info = (res['message'] as String?) ??
            'Nếu tài khoản tồn tại, hệ thống đã gửi hướng dẫn đặt lại mật khẩu.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // e ở đây thường là message từ BE ("Số điện thoại này chưa được đăng ký.", ...)
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Quên mật khẩu',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nhập email hoặc số điện thoại đã đăng ký để nhận link đặt lại mật khẩu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (_info != null) ...[
                    Text(
                      _info!,
                      style: const TextStyle(color: Colors.green, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                  ],

                  TextFormField(
                    controller: _identifierCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email hoặc Số điện thoại',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập email hoặc số điện thoại';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
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
                        : const Text('Gửi hướng dẫn đặt lại'),
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.pushNamed(context, WebRoutes.login);
                          },
                    child: const Text('Quay lại đăng nhập'),
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
