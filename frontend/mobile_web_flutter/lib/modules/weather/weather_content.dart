import 'package:flutter/material.dart';

class WeatherContent extends StatefulWidget {
  const WeatherContent({super.key});

  @override
  State<WeatherContent> createState() => _WeatherContentState();
}

class _WeatherContentState extends State<WeatherContent> {
  bool _loading = true;
  Map<String, dynamic>? _weatherData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Mock data cho thời tiết
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _weatherData = {
          'location': 'Hà Nội, Việt Nam',
          'temperature': 28,
          'feelsLike': 30,
          'description': 'Nắng',
          'humidity': 65,
          'windSpeed': 12,
          'pressure': 1013,
          'uvIndex': 7,
          'visibility': 10,
          'icon': '☀️',
          'forecast': [
            {'day': 'Hôm nay', 'high': 32, 'low': 24, 'icon': '☀️', 'desc': 'Nắng'},
            {'day': 'Ngày mai', 'high': 30, 'low': 23, 'icon': '⛅', 'desc': 'Nhiều mây'},
            {'day': 'Thứ 3', 'high': 29, 'low': 22, 'icon': '🌧️', 'desc': 'Mưa nhẹ'},
            {'day': 'Thứ 4', 'high': 31, 'low': 24, 'icon': '☀️', 'desc': 'Nắng'},
            {'day': 'Thứ 5', 'high': 30, 'low': 23, 'icon': '⛅', 'desc': 'Nhiều mây'},
          ],
        };
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Không thể tải dữ liệu thời tiết: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.red.shade700)),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                          _buildTip('Dự báo có mưa vào Thứ 3, chuẩn bị che chắn'),
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

