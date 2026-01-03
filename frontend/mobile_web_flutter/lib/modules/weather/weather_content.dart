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
              Color(0xFFE3F2FD), 
              Color(0xFFFAFAFA), 
            ],
          ),
        ),
        child: _loading 
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _error != null
            ? _buildErrorState()
            : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadWeather,
                  color: Colors.blue,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight( // Giúp layout giãn ra hết màn hình
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Column(
                                children: [
                                  _buildHeader(),
                                  Expanded( // Đẩy nội dung chính ra giữa
                                    flex: 3,
                                    child: _buildMainWeatherCard(),
                                  ),
                                  _buildDetailedStats(),
                                  const SizedBox(height: 24),
                                  Expanded( // Forecast chiếm phần còn lại
                                    flex: 4,
                                    child: _buildForecastSection(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  _weatherData!['location'] ?? '...',
                  style: TextStyle(
                    color: Colors.blueGrey.shade800, 
                    fontSize: 20, 
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '${DateTime.now().day} tháng ${DateTime.now().month}, ${DateTime.now().year}',
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.blue.shade300),
          onPressed: _loadWeather,
        )
      ],
    );
  }

  Widget _buildMainWeatherCard() {
    final w = _weatherData!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${w['icon'] ?? '🌤️'}',
          style: const TextStyle(fontSize: 100),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${w['temperature'] ?? '--'}',
              style: const TextStyle(
                color: Color(0xFF1565C0), // Masked
                fontWeight: FontWeight.w300, 
                fontSize: 90,
                height: 1,
                letterSpacing: -4,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('°', style: TextStyle(fontSize: 40, color: Color(0xFF1565C0))),
            ),
          ],
        ),
        Text(
          '${w['description'] ?? ''}'.toUpperCase(),
          style: TextStyle(
            color: Colors.blueGrey.shade400,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedStats() {
    final w = _weatherData!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.water_drop, '${w['humidity'] ?? '--'}%', 'Độ ẩm', Colors.blue),
          _divider(),
          _statItem(Icons.air, '${w['windSpeed'] ?? '--'} km/h', 'Gió', Colors.teal),
          _divider(),
          _statItem(Icons.wb_sunny, 'Cao', 'UV', Colors.orange),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 24, width: 1, color: Colors.grey.shade200);
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: Colors.blueGrey.shade900, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11)),
      ],
    );
  }

  Widget _buildForecastSection() {
    final forecast = (_weatherData!['forecast'] as List?) ?? const [];
    // Chỉ lấy 3 ngày để fit màn hình
    final shortForecast = forecast.take(3).toList(); 
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dự báo 3 ngày',
          style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade50),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Chia đều không gian
              children: [
                for (int i = 0; i < shortForecast.length; i++) ...[
                  _forecastRow(shortForecast[i]),
                  if (i < shortForecast.length - 1)
                    const Divider(height: 1, color: Color(0xFFF5F5F5), indent: 16, endIndent: 16),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _forecastRow(dynamic day) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${day['day'] ?? ''}',
              style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Text('${day['icon'] ?? '☁️'}', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${day['desc'] ?? ''}',
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${day['high'] ?? '--'}°',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800, fontSize: 14),
          ),
          Text(
            ' / ${day['low'] ?? '--'}°',
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
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
