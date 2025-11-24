// 📁 lib/core/firebase_init.dart
import 'package:flutter/foundation.dart';

class FirebaseInit {
  static bool _inited = false;

  /// Hàm khởi tạo Firebase — có thể dùng bản thật hoặc giả lập
  static Future<void> ensureInited() async {
    if (_inited) return;

    // ⚙️ Nếu sau này bạn thêm Firebase Core thật, thay dòng dưới:
    // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    debugPrint('⚙️ [FirebaseInit] Firebase giả lập đã sẵn sàng.');
    _inited = true;
  }
}
