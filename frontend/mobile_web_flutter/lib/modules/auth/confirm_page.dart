import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // chỉ web
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confirm();
    });
  }

  Future<void> _confirm() async {
    String? token;
    
    if (kIsWeb) {
      // Web: lấy token từ URL query parameters
      final url = html.window.location.href;
      final uri = Uri.parse(url);
      token = uri.queryParameters['token'];
    } else {
      // Mobile: có thể lấy từ route arguments hoặc deep link
      // Tạm thời lấy từ route arguments nếu có
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        token = args['token'] as String?;
      }
      // Hoặc từ URL nếu có (deep linking)
      // Có thể dùng go_router hoặc flutter_native_splash để xử lý deep links
    }

    if (token == null || token.isEmpty) {
      setState(() {
        _message = 'Thiếu token xác nhận';
        _loading = false;
        _success = false;
      });
      return;
    }

    try {
      final res = await ApiBase.getJson(ApiBase.api('/auth/confirm?token=$token'));
      setState(() {
        _message = res['message']?.toString() ?? 'Xác nhận thành công';
        _loading = false;
        _success = true;
      });
    } catch (e) {
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
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              WebRoutes.login,
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Đăng nhập'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            WebRoutes.home,
                            (route) => false,
                          );
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
