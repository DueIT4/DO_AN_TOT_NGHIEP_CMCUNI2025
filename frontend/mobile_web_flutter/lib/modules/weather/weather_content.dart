// lib/modules/weather/weather_content.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherContent extends StatefulWidget {
  const WeatherContent({super.key});

  @override
  State<WeatherContent> createState() => _WeatherContentState();
}

class _WeatherContentState extends State<WeatherContent>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  Map<String, dynamic>? _weatherData;
  String? _error;

  // 🔑 API key OpenWeatherMap
  static const String _apiKey = '1d1e807aeedfd968685c10f19bcc52ff';

  @override
  bool get wantKeepAlive => true; // 🔁 giữ state khi đổi tab

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Lấy vị trí hiện tại (GPS)
      final position = await _determinePosition();

      final lat = position.latitude;
      final lon = position.longitude;

      // 2. API current weather
      final currentUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$lat&lon=$lon'
        '&appid=$_apiKey'
        '&units=metric'
        '&lang=vi',
      );

      // 3. API forecast 5 ngày
      final forecastUrl = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast'
        '?lat=$lat&lon=$lon'
        '&appid=$_apiKey'
        '&units=metric'
        '&lang=vi',
      );

      final currentRes = await http.get(currentUrl);
      final forecastRes = await http.get(forecastUrl);

      if (currentRes.statusCode != 200) {
        throw Exception(
            'Lỗi current weather: ${currentRes.statusCode} ${currentRes.body}');
      }
      if (forecastRes.statusCode != 200) {
        throw Exception(
            'Lỗi forecast: ${forecastRes.statusCode} ${forecastRes.body}');
      }

      final currentJson = jsonDecode(currentRes.body);
      final forecastJson = jsonDecode(forecastRes.body);

      final mapped = _mapWeatherFromApi(currentJson, forecastJson);

      if (!mounted) return;
      setState(() {
        _weatherData = mapped;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải dữ liệu thời tiết: $e';
        _loading = false;
      });
    }
  }

  /// Hàm xin quyền & lấy vị trí hiện tại (GPS)
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Kiểm tra dịch vụ định vị đã bật chưa
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Dịch vụ định vị đang tắt. Vui lòng bật GPS.');
    }

    // Kiểm tra quyền
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Bạn đã từ chối quyền truy cập vị trí.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng bật lại trong cài đặt.');
    }

    // Lấy vị trí hiện tại
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Map dữ liệu từ OpenWeatherMap về đúng format UI đang dùng
  Map<String, dynamic> _mapWeatherFromApi(
      Map<String, dynamic> current, Map<String, dynamic> forecast) {
    // --- Current weather ---
    final location =
        '${current['name'] ?? 'Không rõ'}, ${current['sys']?['country'] ?? ''}';
    final temp = (current['main']?['temp'] ?? 0).round();
    final feelsLike = (current['main']?['feels_like'] ?? temp).round();
    final description = (current['weather']?[0]?['description'] ?? '')
        .toString()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    final humidity = (current['main']?['humidity'] ?? 0).round();
    final windSpeed = (current['wind']?['speed'] ?? 0).toDouble();
    final pressure = (current['main']?['pressure'] ?? 0).round();
    final uvIndex = 7; // Free API không có UV -> mock nhẹ
    final visibility = ((current['visibility'] ?? 0) / 1000).toStringAsFixed(1);

    final weatherMain = (current['weather']?[0]?['main'] ?? '').toString();
    final icon = _mapIcon(weatherMain);

    // --- Forecast 5 ngày đơn giản ---
    final List<dynamic> list = forecast['list'] ?? [];
    final Map<String, Map<String, dynamic>> daily = {};

    for (final item in list) {
      final dtTxt = item['dt_txt']?.toString() ?? '';
      if (dtTxt.isEmpty) continue;

      final date = dtTxt.split(' ').first; // yyyy-mm-dd
      final tempMax = (item['main']?['temp_max'] ?? 0).toDouble();
      final tempMin = (item['main']?['temp_min'] ?? 0).toDouble();
      final main = (item['weather']?[0]?['main'] ?? '').toString();
      final desc = (item['weather']?[0]?['description'] ?? '').toString();

      if (!daily.containsKey(date)) {
        daily[date] = {
          'high': tempMax,
          'low': tempMin,
          'main': main,
          'desc': desc,
        };
      } else {
        if (tempMax > daily[date]!['high']) {
          daily[date]!['high'] = tempMax;
        }
        if (tempMin < daily[date]!['low']) {
          daily[date]!['low'] = tempMin;
        }
      }
    }

    final now = DateTime.now();
    final days = <Map<String, dynamic>>[];

    // Ngày 0: Hôm nay (dùng current)
    days.add({
      'day': 'Hôm nay',
      'high': temp,
      'low': temp,
      'icon': icon,
      'desc': description,
    });

    // Các ngày tiếp theo
    final weekdayNames = ['CN', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];

    final sortedDates = daily.keys.toList()..sort();
    for (final date in sortedDates) {
      final dt = DateTime.tryParse(date);
      if (dt == null) continue;
      if (dt.day == now.day &&
          dt.month == now.month &&
          dt.year == now.year) {
        // đã có "Hôm nay"
        continue;
      }

      final diff = dt.difference(now).inDays;
      if (diff == 1) {
        final d = daily[date]!;
        days.add({
          'day': 'Ngày mai',
          'high': (d['high'] as double).round(),
          'low': (d['low'] as double).round(),
          'icon': _mapIcon(d['main']),
          'desc': d['desc'],
        });
      } else if (diff > 1 && days.length < 5) {
        final d = daily[date]!;
        final wName = weekdayNames[dt.weekday % 7];
        days.add({
          'day': wName,
          'high': (d['high'] as double).round(),
          'low': (d['low'] as double).round(),
          'icon': _mapIcon(d['main']),
          'desc': d['desc'],
        });
      }

      if (days.length >= 5) break;
    }

    return {
      'location': location,
      'temperature': temp,
      'feelsLike': feelsLike,
      'description': description,
      'humidity': humidity,
      'windSpeed': windSpeed.toStringAsFixed(1),
      'pressure': pressure,
      'uvIndex': uvIndex,
      'visibility': visibility,
      'icon': icon,
      'forecast': days,
    };
  }

  String _mapIcon(String main) {
    switch (main.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '⛅';
      case 'rain':
      case 'drizzle':
        return '🌧️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
      case 'haze':
        return '🌫️';
      default:
        return '☁️';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ⚠️ bắt buộc khi dùng AutomaticKeepAliveClientMixin

    final isWide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 20,
          vertical: isWide ? 40 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.wb_sunny, size: 32, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Text(
                  'Thông tin thời tiết',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadWeather,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_weatherData != null)
              Column(
                children: [
                  // Current Weather Card
                  Card(
                    elevation: 4,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade400,
                            Colors.blue.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _weatherData!['location'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _weatherData!['description'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _weatherData!['icon'],
                                style: const TextStyle(fontSize: 64),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_weatherData!['temperature']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 72,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  '°C',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Cảm giác như ${_weatherData!['feelsLike']}°C',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Weather Details Grid
                  GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _WeatherDetailCard(
                        icon: Icons.water_drop,
                        label: 'Độ ẩm',
                        value: '${_weatherData!['humidity']}%',
                        color: Colors.blue,
                      ),
                      _WeatherDetailCard(
                        icon: Icons.air,
                        label: 'Gió',
                        value: '${_weatherData!['windSpeed']} km/h',
                        color: Colors.grey,
                      ),
                      _WeatherDetailCard(
                        icon: Icons.compress,
                        label: 'Áp suất',
                        value: '${_weatherData!['pressure']} hPa',
                        color: Colors.orange,
                      ),
                      _WeatherDetailCard(
                        icon: Icons.wb_sunny,
                        label: 'Chỉ số UV',
                        value: '${_weatherData!['uvIndex']}',
                        color: Colors.yellow.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Forecast
                  Text(
                    'Dự báo 5 ngày',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ...(_weatherData!['forecast'] as List).map((day) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      day['day'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    day['icon'],
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      day['desc'],
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${day['high']}°',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${day['low']}°',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Agricultural Tips
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.eco,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lời khuyên cho nông nghiệp',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTip('Nhiệt độ hiện tại phù hợp cho cây trồng'),
                          _buildTip('Độ ẩm ở mức tốt, không cần tưới nhiều'),
                          _buildTip('Thời tiết nắng, phù hợp để phơi nắng cây'),
                          _buildTip(
                              'Nếu dự báo có mưa, chuẩn bị che chắn kịp thời'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 20, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.green.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherDetailCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _WeatherDetailCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
