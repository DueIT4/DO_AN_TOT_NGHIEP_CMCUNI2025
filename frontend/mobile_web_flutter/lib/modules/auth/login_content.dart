import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../src/routes/web_routes.dart';
import '../../core/user_service.dart';
import '../auth/auth_service.dart';

/// Gradient chủ đạo cho login (đồng bộ với màu seed 0xFF2F6D3A)
const List<Color> _primaryGradient = [
  Color(0xFF2F6D3A), // xanh đậm
  Color(0xFF4CAF50), // xanh nhạt hơn chút
];

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

  bool _obscurePassword = true; // ẩn/hiện mật khẩu

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _safeNext(String? raw) {
    // ✅ đảm bảo không bị null/rỗng, và tránh open redirect bậy bạ
    if (raw == null || raw.trim().isEmpty) return WebRoutes.home;
    final v = raw.trim();

    // chỉ cho phép internal path (bắt đầu bằng "/")
    if (!v.startsWith('/')) return WebRoutes.home;

    // nếu bạn muốn khóa chỉ cho phép vài route nhất định, có thể check tại đây
    return v;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final input = _accountCtrl.text.trim();

      await AuthService.loginWithCredentials(
        identifier: input,
        password: _passCtrl.text,
      );

      UserService.clearCache();
      await UserService.getCurrentUser(forceRefresh: true);

      if (!mounted) return;

      final next = _safeNext(widget.returnTo);
      // ✅ go_router điều hướng chuẩn web
      context.go(next);
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
    final returnTo = widget.returnTo;
    final primary = Theme.of(context).colorScheme.primary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.eco,
                        color: primary,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ZestGuard',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome Admin',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ZestGuard - Hệ thống AI phát hiện bệnh cây trồng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (returnTo != null && returnTo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Bạn cần đăng nhập để truy cập $returnTo',
                        style: const TextStyle(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  TextFormField(
                    controller: _accountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email hoặc Số điện thoại',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập email hoặc số điện thoại';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        context.go(WebRoutes.forgotPassword);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: _primaryGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _loading ? null : _submit,
                          child: Center(
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.login_rounded,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Đăng nhập',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
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
