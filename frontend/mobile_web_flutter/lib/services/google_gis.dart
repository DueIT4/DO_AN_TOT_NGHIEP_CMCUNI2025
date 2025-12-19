import 'google_gis_stub.dart'
    if (dart.library.html) 'google_gis_web.dart';

class GoogleGis {
  static Future<String?> getIdToken({required String webClientId}) {
    return GoogleGisImpl.getIdToken(webClientId: webClientId);
  }
}
