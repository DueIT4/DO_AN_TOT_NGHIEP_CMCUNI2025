import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:go_router/go_router.dart'; // Using Navigator for now as main_app uses basic routes map

import '../firebase_options.dart';
import '../services/api_client.dart';
import '../core/api_base_app.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _status = 'Đang khởi động...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Firebase
      setState(() => _status = 'Kết nối dịch vụ...');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // 2. Facebook (Optional)
      try {
        await FacebookAuth.instance
            .webAndDesktopInitialize(
              appId: '1884651265804315',
              cookie: true,
              xfbml: true,
              version: 'v18.0',
            )
            .timeout(const Duration(seconds: 3)); // Short timeout
      } catch (_) {
        // Find to fail
      }

      // 3. Restore Token
      setState(() => _status = 'Kiểm tra đăng nhập...');
      await ApiClient.restoreToken();
      
      // 4. Sync Global Token
      ApiBase.bearer = ApiClient.authToken;

      // 5. Navigate
      if (!mounted) return;
      
      final hasToken = ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty;
      if (hasToken) {
        Navigator.of(context).pushReplacementNamed('/home_user');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }

    } catch (e, stack) {
      debugPrint('Init Error: $e\n$stack');
      if (mounted) {
        setState(() {
          _hasError = true;
          _status = 'Lỗi khởi động:\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo placeholder
              const Icon(
                Icons.local_hospital_rounded, 
                size: 80, 
                color: Color(0xFF7CCD2B),
              ),
              const SizedBox(height: 24),
              const Text(
                'ZestGuard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 48),
              if (_hasError)
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                )
              else ...[
                const CircularProgressIndicator(
                  color: Color(0xFF7CCD2B),
                ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              if (_hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: ElevatedButton(
                    onPressed: _initializeApp,
                    child: const Text('Thử lại'),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
