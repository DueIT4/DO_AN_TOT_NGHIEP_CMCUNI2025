import 'package:flutter/material.dart';
import 'package:mobile_web_flutter/core/api_base.dart';
import 'package:mobile_web_flutter/src/routes/web_routes.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // Bước 1: nhập email / phone
  final _identifierCtrl = TextEditingController();

  // Bước 2: nhập mã + mật khẩu mới
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _info;

  /// step = 1: nhập email/phone
  /// step = 2: nhập mã + mật khẩu mới
  int _step = 1;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ================== BƯỚC 1: GỬI YÊU CẦU QUÊN MẬT KHẨU ==================
  Future<void> _submitStep1() async {
    if (!_formKeyStep1.currentState!.validate()) return;

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
        _step = 2; // chuyển sang bước nhập mã + mật khẩu
        _info = (res['message'] as String?) ??
            'Đã gửi mã xác thực. Vui lòng kiểm tra email / tin nhắn của bạn.';
      });
    } catch (e) {
      if (!mounted) return;
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
Future<void> _submitStep2() async {
  if (!_formKeyStep2.currentState!.validate()) return;

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final code = _codeCtrl.text.trim();        // chính là token
    final newPassword = _passwordCtrl.text.trim();

    // 👇 body đúng theo backend: cần "token"
    final body = {
      'token': code,
      'new_password': newPassword,
    };

    final res = await ApiBase.postJson(
      ApiBase.api('/auth/reset-password'),
      body,
    );

    if (!mounted) return;
    setState(() {
      _info = (res['message'] as String?) ??
          'Đổi mật khẩu thành công. Bạn có thể đăng nhập bằng mật khẩu mới.';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, WebRoutes.login);
    });
  } catch (e) {
    if (!mounted) return;
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
    final isStep1 = _step == 1;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Quên mật khẩu',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isStep1
                        ? 'Nhập email hoặc số điện thoại đã đăng ký để nhận mã xác thực đặt lại mật khẩu.'
                        : 'Nhập mã xác thực bạn nhận được và tạo mật khẩu mới.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
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
                      style:
                          const TextStyle(color: Colors.green, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ================== FORM BƯỚC 1 ==================
                  if (isStep1)
                    Form(
                      key: _formKeyStep1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                            onPressed: _loading ? null : _submitStep1,
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
                                : const Text('Gửi mã xác thực'),
                          ),
                        ],
                      ),
                    ),

                  // ================== FORM BƯỚC 2 ==================
                  if (!isStep1)
                    Form(
                      key: _formKeyStep2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Hiển thị lại email/phone để user biết đang reset cho tài khoản nào
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Tài khoản: ${_identifierCtrl.text}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _codeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Mã xác thực',
                              hintText: 'Nhập mã nhận được qua email / SMS',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng nhập mã xác thực';
                              }
                              // Nếu BE quy định độ dài, bạn có thể check thêm ở đây
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Mật khẩu mới',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng nhập mật khẩu mới';
                              }
                              if (v.trim().length < 6) {
                                return 'Mật khẩu phải có ít nhất 6 ký tự';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Xác nhận mật khẩu mới',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng nhập lại mật khẩu';
                              }
                              if (v.trim() != _passwordCtrl.text.trim()) {
                                return 'Mật khẩu xác nhận không khớp';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loading ? null : _submitStep2,
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
                                : const Text('Đổi mật khẩu'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _step = 1;
                                      _error = null;
                                      _info = null;
                                    });
                                  },
                            child: const Text('Nhập lại email / số điện thoại'),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.pushReplacementNamed(
                                context, WebRoutes.login);
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
