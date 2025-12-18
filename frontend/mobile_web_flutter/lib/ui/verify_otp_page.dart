import 'package:flutter/material.dart';
import '../services/api_client.dart';

class VerifyOtpPage extends StatefulWidget {
  const VerifyOtpPage({super.key});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _verify(String contact) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final res = await ApiClient.verifyResetOtp(
      contact: contact,
      otp: _otpCtrl.text.trim(),
    );
    setState(() => _loading = false);

    if (!mounted) return;

    if (res.$1) {
      final resetToken = res.$2;
      Navigator.pushReplacementNamed(
        context,
        '/reset_password',
        arguments: resetToken, // truyền reset_token sang màn đặt mật khẩu mới
      );
    } else {
      _snack(res.$2);
    }
  }

  Future<void> _resend(String contact) async {
    // Gửi lại OTP: gọi lại endpoint forgot-password-otp
    setState(() => _loading = true);
    final res = await ApiClient.forgotPasswordOtp(
      email: contact.contains('@') ? contact : null,
      phone: contact.contains('@') ? null : contact,
    );
    setState(() => _loading = false);

    if (!mounted) return;
    _snack(res.$1 ? 'Đã gửi lại OTP' : res.$2);
  }

  @override
  Widget build(BuildContext context) {
    final contact = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('OTP đã gửi tới: $contact'),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nhập OTP (6 số)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.length != 6) return 'OTP phải đủ 6 số';
                  if (!RegExp(r'^\d{6}$').hasMatch(s)) return 'OTP không hợp lệ';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _loading ? null : () => _verify(contact),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Xác nhận'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => _resend(contact),
              child: const Text('Gửi lại OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
