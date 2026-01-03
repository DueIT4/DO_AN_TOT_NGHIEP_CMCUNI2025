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
                      // Bố cục chia đôi màn hình (Split Screen Dashboard)
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 20, // Trừ padding
                          ),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column( // Dùng Column để bọc Header riêng
                                children: [
                                  _buildHeader(), // Header ở trên cùng
                                  const SizedBox(height: 20),
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // CỘT TRÁI: Thông tin hiện tại (Temp + Stats)
                                        Expanded(
                                          flex: 6,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Expanded(child: Center(child: _buildMainWeatherCard())),
                                              _buildDetailedStats(),
                                              const SizedBox(height: 20),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        // CỘT PHẢI: Dự báo 5 ngày (Full height)
                                        Expanded(
                                          flex: 4,
                                          child: _buildForecastSection(),
                                        ),
                                      ],
                                    ),
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
                Icon(Icons.location_on, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  _weatherData!['location'] ?? '...',
                  style: TextStyle(
                    color: Colors.blueGrey.shade800, 
                    fontSize: 22, 
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
        // Layout ngang cho Temp và Icon để tiết kiệm chiều cao
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${w['icon'] ?? '🌤️'}',
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${w['temperature'] ?? '--'}',
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w300, 
                        fontSize: 80,
                        height: 1,
                        letterSpacing: -4,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
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
                    letterSpacing: 1,
                  ),
                ),
              ],
            )
          ],
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
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: Colors.blueGrey.shade900, fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 12)),
      ],
    );
  }

  Widget _buildForecastSection() {
    final forecast = (_weatherData!['forecast'] as List?) ?? const [];
    // Lấy lại 5 ngày vì giờ đã có cột riêng
    final fullForecast = forecast.take(5).toList(); 
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dự báo 5 ngày',
                style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.calendar_month_outlined, color: Colors.blueGrey.shade300, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < fullForecast.length; i++) ...[
                  Expanded(child: _forecastRow(fullForecast[i])),
                  if (i < fullForecast.length - 1)
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _forecastRow(dynamic day) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            '${day['day'] ?? ''}',
            style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Text('${day['icon'] ?? '☁️'}', style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${day['desc'] ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '${day['high'] ?? '--'}°',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800, fontSize: 14),
        ),
        Text(
          ' /${day['low'] ?? '--'}°',
          style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 12),
        ),
      ],
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
