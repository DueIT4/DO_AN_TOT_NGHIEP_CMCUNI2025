class ApiBase {
  static const String host = 'http://127.0.0.1:8000';
  static String api(String path) => '$host/api/v1$path';
}
