import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WeatherApi {
  static String get baseUrl {
    // Web (Chrome): backend chạy local
    if (kIsWeb) return 'http://localhost:8000';

    // Android emulator:
    return 'http://10.0.2.2:8080';

    // Máy thật Android: đổi sang IP LAN của máy chạy backend
    // return 'http://192.168.1.5:8080';
  }

  static Future<Map<String, dynamic>> getWeather({
    required double lat,
    required double lon,
    String lang = 'vi',
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/weather').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'lang': lang,
      },
    );

    final res = await http.get(uri, headers: const {'Accept': 'application/json'});

    if (res.statusCode != 200) {
      throw Exception('Backend weather error: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response format: expected JSON object');
    }

    return data;
  }
}
