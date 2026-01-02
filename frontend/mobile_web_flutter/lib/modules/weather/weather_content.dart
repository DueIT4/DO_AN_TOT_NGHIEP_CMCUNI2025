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

  // Bảng màu Xanh lá chuyên nghiệp (Emerald/Forest Green)
  final Color primaryGreen = const Color(0xFF1B5E20); // Xanh đậm chuyên nghiệp
  final Color lightGreen = const Color(0xFFE8F5E9);    // Nền xanh nhạt
  final Color accentGreen = const Color(0xFF43A047);   // Xanh lá tươi làm điểm nhấn

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
        _error = 'Không thể tải dữ liệu: $e';
        _loading = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw 'Vui lòng bật GPS.';
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'Quyền vị trí bị từ chối.';
    }
    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: accentGreen));
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final w = _weatherData!;
    final forecast = (w['forecast'] as List?) ?? const [];

    return Scaffold(
      backgroundColor: lightGreen,
      body: RefreshIndicator(
        onRefresh: _loadWeather,
        color: primaryGreen,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildMainWeatherCard(w),
              const SizedBox(height: 20),
              _buildDetailedStats(w),
              const SizedBox(height: 24),
              _buildForecastSection(forecast),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dự báo thời tiết',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cập nhật dựa trên vị trí của bạn',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMainWeatherCard(Map<String, dynamic> w) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentGreen, primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${w['location'] ?? 'Vị trí hiện tại'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${w['description'] ?? ''}'.toUpperCase(),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              Text(
                '${w['icon'] ?? '☁️'}',
                style: const TextStyle(fontSize: 56),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '${w['temperature'] ?? '--'}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w200,
                  fontSize: 64,
                ),
              ),
              const Spacer(),
              const Icon(Icons.info_outline, color: Colors.white54, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(Map<String, dynamic> w) {
    return Row(
      children: [
        _statItem(Icons.water_drop_outlined, 'Độ ẩm', '${w['humidity'] ?? '--'}%'),
        const SizedBox(width: 15),
        _statItem(Icons.air_rounded, 'Tốc độ gió', '${w['windSpeed'] ?? '--'} km/h'),
      ],
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: lightGreen,
              child: Icon(icon, color: accentGreen, size: 20),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastSection(List forecast) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            'Dự báo trong tuần',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              for (int i = 0; i < forecast.take(5).length; i++) ...[
                _forecastRow(forecast[i]),
                if (i < forecast.take(5).length - 1)
                  Divider(height: 1, color: Colors.grey.shade100, indent: 20, endIndent: 20),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _forecastRow(dynamic day) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '${day['day'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text('${day['icon'] ?? '☁️'}', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${day['desc'] ?? ''}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Text(
            '${day['high'] ?? '--'}°',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          const SizedBox(width: 10),
          Text(
            '${day['low'] ?? '--'}°',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadWeather,
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}