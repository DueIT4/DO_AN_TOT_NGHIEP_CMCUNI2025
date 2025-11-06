import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class FirebaseInit {
  static bool _ready = false;
  static Future<void> ensureInited() async {
    if (_ready) return;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    _ready = true;
  }
}
