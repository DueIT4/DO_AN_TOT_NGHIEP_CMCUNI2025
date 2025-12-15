import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_base.dart';
import '../../src/routes/web_routes.dart';

class ConfirmPage extends StatefulWidget {
  const ConfirmPage({super.key});

  @override
  State<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> {
  String? _message;
  bool _loading = true;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    // an toàn vì GoRouterState có sẵn trong build context sau frame đầu
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
  }

  Future<void> _confirm() async {
    // ✅ Lấy token từ URL: /auth/confirm?token=...
    final token = GoRouterState.of(context).uri.queryParameters['token'];

    if (token == null || token.isEmpty) {
      setState(() {
        _message = 'Thiếu token xác nhận';
        _loading = false;
        _success = false;
      });
      return;
    }

    try {
      final res = await ApiBase.getJson(
        ApiBase.api('/auth/confirm?token=$token'),
      );

      if (!mounted) return;
      setState(() {
        _message = res['message']?.toString() ?? 'Xác nhận thành công';
        _loading = false;
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Xác nhận thất bại: $e';
        _loading = false;
        _success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const CircularProgressIndicator()
                else
                  Icon(
                    _success ? Icons.check_circle : Icons.error,
                    size: 64,
                    color: _success ? Colors.green : Colors.red,
                  ),
                const SizedBox(height: 16),
                Text(
                  _message ?? 'Đang xác nhận...',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!_loading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_success) ...[
                        FilledButton.icon(
                          onPressed: () {
                            // ✅ go_router: đổi URL chuẩn web
                            context.go(WebRoutes.login);
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Đăng nhập'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: () {
                          context.go(WebRoutes.home);
                        },
                        icon: const Icon(Icons.home),
                        label: const Text('Về trang chủ'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
