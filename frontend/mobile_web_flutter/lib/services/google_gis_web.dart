// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:async';

class GoogleGisImpl {
  static Future<String?> getIdToken({required String webClientId}) async {
    final completer = Completer<String?>();

    void handler(html.Event event) {
      final e = event as html.CustomEvent;
      final idToken = (e.detail as dynamic)['idToken'] as String?;
      html.window.removeEventListener('google_id_token', handler);
      completer.complete(idToken);
    }

    html.window.addEventListener('google_id_token', handler);

    try {
      js.context.callMethod('gisGetIdToken', [webClientId]);
    } catch (_) {
      html.window.removeEventListener('google_id_token', handler);
      return null;
    }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        html.window.removeEventListener('google_id_token', handler);
        return null;
      },
    );
  }
}
