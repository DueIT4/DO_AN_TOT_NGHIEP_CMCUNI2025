import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pass1Ctrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;
  bool _secure1 = true;
  bool _secure2 = true;

  @override
  void dispose() {
    _pass1Ctrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit(String resetToken) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final res = await ApiClient.resetPassword(
      token: resetToken,
      newPassword: _pass1Ctrl.text,
    );
    setState(() => _loading = false);

    if (!mounted) return;

    if (res.$1) {
      _snack('Đổi mật khẩu thành công, hãy đăng nhập lại');
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      _snack(res.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resetToken = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _pass1Ctrl,
                obscureText: _secure1,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_secure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _secure1 = !_secure1),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) return 'Ít nhất 6 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass2Ctrl,
                obscureText: _secure2,
                decoration: InputDecoration(
                  labelText: 'Nhập lại mật khẩu',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_secure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _secure2 = !_secure2),
                  ),
                ),
                validator: (v) {
                  if (v != _pass1Ctrl.text) return 'Mật khẩu không khớp';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: _loading ? null : () => _submit(resetToken),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Đổi mật khẩu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
