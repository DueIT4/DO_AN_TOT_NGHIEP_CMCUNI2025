import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile_web_flutter/core/api_base.dart'; // Import ApiBase của bạn

class WeatherApi {
  // ✅ Sửa: Sử dụng trực tiếp baseURL từ ApiBase để đảm bảo luôn dùng HTTPS
  static String get baseUrl => ApiBase.baseURL;

  static Future<Map<String, dynamic>> getWeather({
    required double lat,
    required double lon,
    String lang = 'vi',
  }) async {
    // ✅ Sửa: Dùng ApiBase.api để tự động thêm /api/v1
    final String path = ApiBase.api('/weather');
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'lang': lang,
      },
    );

    // ✅ Sửa: Sử dụng Header có chứa Token từ ApiBase để tránh lỗi 401
    final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (ApiBase.bearerToken != null) 'Authorization': 'Bearer ${ApiBase.bearerToken}',
    });

    if (res.statusCode != 200) {
      throw Exception('Backend weather error: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    return data as Map<String, dynamic>;
  }
}