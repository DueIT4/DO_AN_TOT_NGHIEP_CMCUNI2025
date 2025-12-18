import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _contactCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _contactCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isEmail(String s) => s.contains('@');

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final contact = _contactCtrl.text.trim();
    setState(() => _loading = true);

    final res = await ApiClient.forgotPasswordOtp(
      email: _isEmail(contact) ? contact : null,
      phone: _isEmail(contact) ? null : contact,
    );

    setState(() => _loading = false);

    if (!mounted) return;
    if (res.$1) {
      _snack('Đã gửi OTP');
      Navigator.pushNamed(
        context,
        '/verify_otp',
        arguments: contact, // truyền contact sang màn xác nhận
      );
    } else {
      _snack(res.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text('Nhập Email hoặc Số điện thoại để nhận OTP'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email / Số điện thoại',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Không được để trống';
                  if (v.trim().length < 6) return 'Không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gửi OTP'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
