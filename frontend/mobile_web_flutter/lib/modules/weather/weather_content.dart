import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/weather_api.dart';

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

  @override
  bool get wantKeepAlive => true;

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
      final position = await _determinePosition();

      final mapped = await WeatherApi.getWeather(
        lat: position.latitude,
        lon: position.longitude,
      );

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

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Dịch vụ định vị đang tắt. Vui lòng bật GPS.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Bạn đã từ chối quyền truy cập vị trí.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền vị trí bị từ chối vĩnh viễn. Vui lòng bật lại trong cài đặt.');
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadWeather,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final w = _weatherData!;
    final forecast = (w['forecast'] as List?) ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thời tiết',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Card hiện tại
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '${w['icon'] ?? '☁️'}',
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${w['location'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text('${w['description'] ?? ''}', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  Text(
                    '${w['temperature'] ?? '--'}°C',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Thông số gọn
          Row(
            children: [
              Expanded(
                child: _WeatherDetailCard(
                  icon: Icons.water_drop,
                  label: 'Độ ẩm',
                  value: '${w['humidity'] ?? '--'}%',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeatherDetailCard(
                  icon: Icons.air,
                  label: 'Gió',
                  value: '${w['windSpeed'] ?? '--'} km/h',
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Dự báo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final day in forecast.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${day['day'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('${day['icon'] ?? '☁️'}', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${day['desc'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                          Text('${day['high'] ?? '--'}°', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('${day['low'] ?? '--'}°', style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                ],
              ),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
