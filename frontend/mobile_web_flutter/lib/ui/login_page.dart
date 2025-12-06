
// =============================
// lib/ui/login_page.dart
// =============================
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_client.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _identityCtrl = TextEditingController(); // phone/email
  final _passCtrl = TextEditingController();
  final _repassCtrl = TextEditingController();

  bool _secure1 = true;
  bool _secure2 = true;
  bool _agree = false;
  bool _isRegister = false; // chuyển giữa Đăng nhập / Đăng ký
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identityCtrl.dispose();
    _passCtrl.dispose();
    _repassCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    if (_isRegister && !_agree) {
      _showSnack(l10n.translate('agree_terms_message'));
      return;
    }
    setState(() => _loading = true);

    if (_isRegister) {
      final (ok, msg) = await ApiClient.register(
        name: _nameCtrl.text.trim(),
        identity: _identityCtrl.text.trim(),
        password: _passCtrl.text,
      );
      setState(() => _loading = false);
      if (ok) {
        _showSnack(l10n.translate('register_success'));
        // 👉 Sau khi đăng ký thành công, chuyển luôn sang home_user
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home_user');
      } else {
        _showSnack(msg);
      }
    } else {
      final (ok, token) = await ApiClient.login(
        identity: _identityCtrl.text.trim(),
        password: _passCtrl.text,
      );
      setState(() => _loading = false);
      if (ok) {
        _showSnack(
            'Đăng nhập OK, token: ${token.substring(0, token.length > 12 ? 12 : token.length)}...');
        // 👉 Sau khi đăng nhập thành công, chuyển sang home_user
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home_user');
      } else {
        _showSnack(token);
      }
    }
  }
  Future<void> _handleGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile', 'openid']);
      final account = await googleSignIn.signIn();
      if (account == null) return; // user cancel

      final auth = await account.authentication;
      final idToken = auth.idToken;                        // 🔁 dùng idToken
      if (idToken == null) {
        _showSnack('Không lấy được idToken từ Google');
        return;
      }

      setState(() => _loading = true);
      final res = await ApiClient.loginWithGoogle(idToken); // 🔁 truyền idToken
      setState(() => _loading = false);

      final bool ok = res.$1;
      final String tokenOrMsg = res.$2;

      if (ok) {
        _showSnack(
            'Google OK: ${tokenOrMsg.substring(0, tokenOrMsg.length > 12 ? 12 : tokenOrMsg.length)}...');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home_user'); // 👈
      } else {
        _showSnack(tokenOrMsg);
      }
    } catch (e) {
      _showSnack('Google lỗi: $e');
    }
  }


  Future<void> _handleFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
      if (result.status != LoginStatus.success) {
        _showSnack('Facebook: ${result.status.name}');
        return;
      }
      final token = result.accessToken?.tokenString;
      if (token == null) {
        _showSnack('Không lấy được accessToken từ Facebook');
        return;
      }
      setState(() => _loading = true);
      final (ok, jwt) = await ApiClient.loginWithFacebook(token);
      setState(() => _loading = false);
      if (ok) {
        _showSnack('Facebook OK: ${jwt.substring(0, 12)}...');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home_user'); // 👈
      } else {
        _showSnack(jwt);
      }
    } catch (e) {
      _showSnack('Facebook lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _isRegister
        ? l10n.translate('register_title')
        : l10n.translate('login_title');
    final actionText = _isRegister
        ? l10n.translate('submit_register')
        : l10n.translate('submit_login');
    final subtitle = _isRegister
        ? l10n.translate('register_subtitle')
        : l10n.translate('login_subtitle');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // Logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDFF0C8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.spa_rounded, size: 36, color: Color(0xFF7CCD2B)),
                        ),
                        const SizedBox(width: 10),
                        Text('ZestGuard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (_isRegister) ...[
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(hintText: l10n.translate('name'), prefixIcon: const Icon(Icons.person_outline)),
                              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.translate('field_required') : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _identityCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(hintText: l10n.translate('phone_email'), prefixIcon: const Icon(Icons.call_outlined)),
                            validator: (v) => (v == null || v.trim().isEmpty) ? l10n.translate('field_required') : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _secure1,
                            decoration: InputDecoration(
                              hintText: l10n.translate('password'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_secure1 ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _secure1 = !_secure1),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6) ? 'Ít nhất 6 ký tự' : null,
                          ),
                          if (_isRegister) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _repassCtrl,
                              obscureText: _secure2,
                              decoration: InputDecoration(
                                hintText: l10n.translate('confirm_password'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_secure2 ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _secure2 = !_secure2),
                                ),
                              ),
                              validator: (v) => (_isRegister && v != _passCtrl.text)
                                  ? l10n.translate('password_mismatch')
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (_isRegister)
                            CheckboxListTile(
                              value: _agree,
                              dense: true,
                              onChanged: (v) => setState(() => _agree = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Wrap(
                                children: [
                                  Text('${l10n.translate('agree_prefix')} '),
                                  Text(l10n.translate('terms'), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                  Text(' ${l10n.translate('and')} '),
                                  Text(l10n.translate('privacy'), style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton(
                              onPressed: _loading ? null : _handleSubmit,
                              child: _loading ? const CircularProgressIndicator() : Text(actionText, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(child: Divider()),
                      const SizedBox(width: 8),
                      Text(l10n.translate('login_with')),
                      const SizedBox(width: 8),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _handleGoogle,
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text(l10n.translate('google')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _handleFacebook,
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text(l10n.translate('facebook')),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _isRegister = !_isRegister),
                      child: Text(_isRegister ? l10n.translate('toggle_to_login') : l10n.translate('toggle_to_register')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}