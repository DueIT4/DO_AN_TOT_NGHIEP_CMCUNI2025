import 'dart:ui';
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

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4],
            colors: [
              Color(0xFFE3F2FD), // Xanh rất nhạt ở trên
              Color(0xFFFAFAFA), // Trắng ở dưới
            ],
          ),
        ),
        child: _loading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _error != null
            ? _buildErrorState()
            : RefreshIndicator(
                onRefresh: _loadWeather,
                color: Colors.blue,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 30),
                          _buildMainWeatherCard(),
                          const SizedBox(height: 40),
                          _buildDetailedStats(),
                          const SizedBox(height: 40),
                          _buildForecastSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              _weatherData!['location'] ?? 'Đang định vị...',
              style: TextStyle(
                color: Colors.blueGrey.shade800, 
                fontSize: 20, 
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ]
          ),
          child: Text(
            'Hôm nay, ${DateTime.now().day}/${DateTime.now().month}',
            style: TextStyle(color: Colors.blue.shade700, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        )
      ],
    );
  }

  Widget _buildMainWeatherCard() {
    final w = _weatherData!;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Glow hiệu ứng nhẹ
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.blue.withOpacity(0.1), Colors.transparent],
            ),
          ),
        ),
        Column(
          children: [
             // Icon có màu sắc - ĐIỂM NHẤN
             Text(
              '${w['icon'] ?? '🌤️'}',
              style: const TextStyle(fontSize: 120),
            ),
            // Nhiệt độ - Màu đậm rõ ràng
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: Text(
                '${w['temperature'] ?? '--'}°',
                style: const TextStyle(
                  color: Colors.white, // Masked
                  fontWeight: FontWeight.w300, 
                  fontSize: 100,
                  height: 1,
                  letterSpacing: -5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${w['description'] ?? ''}'.toUpperCase(),
              style: TextStyle(
                color: Colors.blueGrey.shade400,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailedStats() {
    final w = _weatherData!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(Icons.water_drop, '${w['humidity'] ?? '--'}%', 'Độ ẩm', Colors.blue),
              _divider(),
              _statItem(Icons.air, '${w['windSpeed'] ?? '--'} km/h', 'Gió', Colors.teal),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          const SizedBox(height: 24),
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem(Icons.wb_sunny, 'Cao', 'UV Index', Colors.orange),
              _divider(),
              _statItem(Icons.compress, '1012 hPa', 'Áp suất', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade100,
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: Colors.blueGrey.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildForecastSection() {
    final forecast = (_weatherData!['forecast'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dự báo 5 ngày',
                style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.calendar_month, color: Colors.blueGrey.shade300, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
               for (int i = 0; i < forecast.take(5).length; i++) ...[
                _forecastRow(forecast[i], i),
                if (i < forecast.take(5).length - 1)
                   const Divider(height: 1, color: Color(0xFFF5F5F5)),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _forecastRow(dynamic day, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '${day['day'] ?? ''}',
              style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(width: 16),
          Text('${day['icon'] ?? '☁️'}', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              '${day['desc'] ?? ''}',
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${day['high'] ?? '--'}°',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Text(
            '${day['low'] ?? '--'}°',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 80, color: Colors.blueGrey.shade200),
            const SizedBox(height: 16),
            Text(
              _error!, 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 16)
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadWeather,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
