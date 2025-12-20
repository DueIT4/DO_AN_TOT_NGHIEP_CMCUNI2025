import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/weather_api.dart';
import '../core/camera_provider.dart';
import '../core/api_base_app.dart';
import '../l10n/app_localizations.dart';
import '../models/notification.dart' as models;
import '../services/api_client.dart';
import '../services/camera_stream_service.dart';
import 'ai_chat_page.dart';
import 'notifications_list_page.dart';
import 'user_settings_page.dart';
import 'widgets/camera_stream_player.dart' as camera_widgets;
import 'home_shell.dart';

class HomeUserPage extends StatefulWidget {
  const HomeUserPage({super.key});

  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  String? _droicamUrl; // lưu địa chỉ Droicam đã nhập
  final TextEditingController _droicamCtrl = TextEditingController();

  // Camera Stream
  int? _selectedCameraId;
  String? _selectedCameraName;
  bool _cameraLoading = false;
  String? _selectedCameraStreamUrl;

  // Thông báo
  List<models.AppNotification> _notifications = [];
  bool _notificationsLoading = false;

  // Thời tiết
  Map<String, dynamic>? _weather;
  bool _weatherLoading = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadWeather();
    _loadSelectedCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload camera when CameraProvider changes (e.g., user selected new camera on Devices page)
    _loadSelectedCamera();
  }

  @override
  void dispose() {
    _droicamCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _notificationsLoading = true;
    });

    final (success, data, _) = await ApiClient.getMyNotifications();

    if (success) {
      try {
        final notifications = (data)
            .map((json) =>
                models.AppNotification.fromJson(json as Map<String, dynamic>))
            .toList();
        setState(() {
          _notifications = notifications;
          _notificationsLoading = false;
        });
      } catch (e) {
        setState(() {
          _notificationsLoading = false;
        });
      }
    } else {
      setState(() {
        _notificationsLoading = false;
      });
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get _hasUnread => _unreadCount > 0;

  Future<void> _loadWeather() async {
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });

    try {
      Position? pos;
      try {
        pos = await _determinePosition();
      } catch (e) {
        // Web không hỗ trợ location - dùng location mặc định (Hà Nội)
        if (!mounted) return;
        final data = await WeatherApi.getWeather(
          lat: 21.0285,
          lon: 105.8542,
          lang: 'vi',
        );
        setState(() {
          _weather = data;
          _weatherLoading = false;
        });
        return;
      }

      final data = await WeatherApi.getWeather(
        lat: pos.latitude,
        lon: pos.longitude,
        lang: 'vi',
      );

      if (!mounted) return;
      setState(() {
        _weather = data;
        _weatherLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherError = '$e';
        _weatherLoading = false;
      });
    }
  }

  Future<void> _loadSelectedCamera() async {
    setState(() => _cameraLoading = true);

    try {
      final cameraData = await CameraStreamService.getSelectedCamera();

      if (!mounted) return;

      final deviceId = cameraData['device_id'];
      if (deviceId == null) {
        setState(() => _cameraLoading = false);
        return;
      }

      // Update provider
      final provider = context.read<CameraProvider>();
      await provider.setSelectedCamera(
        deviceId: deviceId as int,
        deviceName: cameraData['name']?.toString() ?? 'Camera',
        streamUrl: cameraData['stream_url']?.toString() ?? '',
      );

      setState(() {
        _selectedCameraId = deviceId as int;
        _selectedCameraName = cameraData['name']?.toString() ?? 'Camera';
        _selectedCameraStreamUrl = cameraData['stream_url']?.toString() ?? '';
        _cameraLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraLoading = false);
    }
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Vui lòng bật GPS');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Bạn đã từ chối quyền vị trí');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền vị trí bị từ chối vĩnh viễn');
    }

    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _showDroicamDialog() async {
    _droicamCtrl.text = _droicamUrl ?? '';

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Kết nối Droicam'),
          content: TextField(
            controller: _droicamCtrl,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ Droicam / URL stream',
              hintText: 'vd: http://192.168.1.11:4747/video',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final url = _droicamCtrl.text.trim();
                if (url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Vui lòng nhập địa chỉ Droicam')),
                  );
                  return;
                }
                setState(() {
                  _droicamUrl = url;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Kết nối'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final humidityText = _weatherLoading
        ? '...'
        : (_weather == null || _weatherError != null)
            ? '--'
            : '${_weather!['humidity'] ?? '--'}%';

    final tempText = _weatherLoading
        ? '...'
        : (_weather == null || _weatherError != null)
            ? '--'
            : '${_weather!['temperature'] ?? '--'} °C';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= HEADER =================
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF0C8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: Color(0xFF7CCD2B),
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                l10n.translate('greeting'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                l10n.translate('monitoring'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // ========== 2 CARD ĐỘ ẨM / NHIỆT ĐỘ (từ API thời tiết) ==========
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: l10n.translate('humidity'),
                      value: humidityText,
                      icon: Icons.water_drop_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: l10n.translate('temperature'),
                      value: tempText,
                      icon: Icons.thermostat_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ========== DỰ BÁO 3 NGÀY (gọn cho nông dân) ==========
              if (_weatherError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Không lấy được thời tiết: $_weatherError',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadWeather,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              else if (_weather != null)
                Column(
                  children: [
                    _WeatherForecast3DaysCard(weather: _weather!),
                    const SizedBox(height: 16),
                  ],
                )
              else if (_weatherLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 6),
                ),

              // ========== CAMERA STREAM ==========
              const SizedBox(height: 16),
              Builder(builder: (context) {
                final cam = context.watch<CameraProvider>();
                // Ưu tiên giá trị từ Provider (cập nhật ngay sau khi đổi camera),
                // fallback sang state đã load từ server nếu Provider chưa có.
                final camId = cam.selectedCameraId ?? _selectedCameraId;
                final camName = cam.selectedCameraName ?? _selectedCameraName;
                final camUrl =
                    cam.selectedCameraStreamUrl ?? _selectedCameraStreamUrl;

                if (camId != null && camName != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nếu URL là MJPEG (DroidCam) → dùng DroicamView để convert thành HLS
                      if (camUrl != null && _looksLikeMjpeg(camUrl))
                        DroicamView(url: camUrl!)
                      else
                        camera_widgets.CameraStreamPlayer(
                          deviceId: camId,
                          deviceName: camName,
                          hlsUrl: camUrl ??
                              CameraStreamService.buildFullHlsUrl(camId),
                          onCameraChanged: _loadSelectedCamera,
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Camera đang sử dụng',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  camName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () =>
                                HomeShell.maybeOf(context)?.goToTab(2),
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Đổi camera'),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                if (_cameraLoading) {
                  return Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Đang tải camera...'),
                    ],
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD700)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFF57C00)),
                          SizedBox(width: 8),
                          Text(
                            'Chưa có camera nào được chọn',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng chọn camera trong trang Devices để xem live stream',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      // Dẫn sang tab Devices để chọn camera
                      ElevatedButton.icon(
                        onPressed: () => HomeShell.maybeOf(context)?.goToTab(2),
                        icon: const Icon(Icons.sensors, size: 18),
                        label: const Text('Đi tới trang Devices'),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              // ========== AI CHATBOT ==========
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7CCD2B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('ai_chatbot'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.translate('ai_helper'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7CCD2B),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AIChatPage(),
                          ),
                        );
                      },
                      child: Text(l10n.translate('ask_now')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ========== 2 Ô BÊN DƯỚI ==========
              Row(
                children: [
                  Expanded(
                    child: _SmallCard(
                      icon: Icons.insert_chart_outlined,
                      title: l10n.translate('report'),
                      subtitle: l10n.translate('view_analytics'),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NotificationCard(
                      notifications: _notifications,
                      unreadCount: _unreadCount,
                      hasUnread: _hasUnread,
                      isLoading: _notificationsLoading,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsListPage(),
                          ),
                        ).then((_) {
                          _loadNotifications();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= DROICAM VIEW - Sử dụng HLS stream =================
/// Hiển thị DroidCam video stream.
/// Trên web, MJPEG (Image.network) có vấn đề liên tục reconnect.
/// Giải pháp: Dùng HLS (HTTP Live Streaming) thông qua ffmpeg conversion
/// hoặc phát trực tiếp qua CameraStreamPlayer với VideoPlayer plugin.
class DroicamView extends StatefulWidget {
  final String url; // URL MJPEG của DroidCam

  const DroicamView({super.key, required this.url});

  @override
  State<DroicamView> createState() => _DroicamViewState();
}

class _DroicamViewState extends State<DroicamView> {
  String _hlsUrl = ''; // Initialize with empty string
  String? _errorMsg;
  bool _isLoading = true;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeHls();
  }

  Future<void> _initializeHls() async {
    // Tạo HLS URL từ MJPEG URL bằng cách gọi backend API
    // Backend sẽ convert MJPEG -> HLS bằng ffmpeg
    try {
      final mjpegUrl = Uri.encodeComponent(widget.url);
      final uri =
          Uri.parse('${ApiBase.host}/api/v1/stream/hls?mjpeg_url=$mjpegUrl');

      final resp = await http
          .get(uri, headers: ApiClient.authHeaders())
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final hlsUrl = data['hls_url']?.toString();
        if (hlsUrl != null && hlsUrl.isNotEmpty) {
          setState(() {
            _hlsUrl = hlsUrl;
            _isLoading = false;
          });
          return;
        }
      }
      // Nếu backend đang khởi tạo (503) → thử lại vài lần
      if (resp.statusCode == 503 && _retryCount < 5) {
        _retryCount += 1;
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        setState(() {
          _isLoading = true;
          _errorMsg = null;
        });
        return _initializeHls();
      }
      setState(() {
        _errorMsg = 'Không thể tạo HLS stream (${resp.statusCode})';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Lỗi khởi tạo stream: $e';
        _isLoading = false;
      });
    }
  }

  bool _isValidUrl(String s) {
    final u = Uri.tryParse(s);
    return u != null && u.hasScheme && u.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValidUrl(widget.url)) {
      return Container(
        height: 160,
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 32),
              const SizedBox(height: 12),
              const Text(
                'URL DroidCam không hợp lệ',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.url,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || _hlsUrl.isEmpty) {
      return Container(
        height: 160,
        color: Colors.grey[800],
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(0xFF7CCD2B),
            ),
          ),
        ),
      );
    }

    if (_errorMsg != null) {
      return Container(
        height: 160,
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 32),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _errorMsg ?? 'Lỗi kết nối camera',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Dùng CameraStreamPlayer với HLS URL để phát video
    // Tránh vấn đề setState() trong errorBuilder của Image.network
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: camera_widgets.CameraStreamPlayer(
        deviceId: 0, // Dummy ID cho DroidCam
        deviceName: 'DroidCam',
        hlsUrl: _hlsUrl,
      ),
    );
  }
}

// Nhận diện nhanh URL MJPEG (ví dụ DroidCam: :4747/video)
bool _looksLikeMjpeg(String url) {
  final s = url.toLowerCase();
  return s.contains(":4747/video") ||
      s.endsWith("/video") ||
      s.contains("mjpeg") ||
      s.contains("mjpg");
}

// ======================= WIDGET PHỤ =======================
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4D9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7CCD2B)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: 0.7,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SmallCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F4D9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF7CCD2B)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final List<models.AppNotification> notifications;
  final int unreadCount;
  final bool hasUnread;
  final bool isLoading;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notifications,
    required this.unreadCount,
    required this.hasUnread,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalCount = notifications.length;
    final subtitle = isLoading
        ? 'Đang tải...'
        : totalCount == 0
            ? 'Chưa có thông báo'
            : '$totalCount thông báo';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F4D9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: Color(0xFF7CCD2B)),
                    if (hasUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.translate('alerts'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========== WIDGET DỰ BÁO 3 NGÀY ==========
class _WeatherForecast3DaysCard extends StatelessWidget {
  final Map<String, dynamic> weather;
  const _WeatherForecast3DaysCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final forecast = (weather['forecast'] as List?) ?? const [];
    final days = forecast.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4D9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dự báo 3 ngày tới',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${d['day'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('${d['icon'] ?? '☁️'}',
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${d['desc'] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  Text('${d['high'] ?? '--'}°',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text('${d['low'] ?? '--'}°',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
