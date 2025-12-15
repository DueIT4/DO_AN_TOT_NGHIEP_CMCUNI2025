import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../core/api_base_app.dart';
import '../services/api_client.dart';
import '../services/device_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceCategory { camera, sensor }

class DeviceInfo {
  final int deviceId;
  final String name;
  final DeviceCategory category;
  final bool isOnline;
  final IconData icon;

  final String? status;
  final String? streamUrl;
  final String? location;

  final double? humidityPercent;
  final int? batteryPercent;
  final DateTime updatedAt;

  final String? latestImageUrl; // ✅ thêm

  const DeviceInfo({
    required this.deviceId,
    required this.name,
    required this.category,
    required this.isOnline,
    required this.icon,
    required this.updatedAt,
    this.status,
    this.streamUrl,
    this.location,
    this.humidityPercent,
    this.batteryPercent,
    this.latestImageUrl, // ✅ thêm
  });
}


class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<DeviceInfo> _devices = [];
  int? _selectedCameraId;
  bool _loading = false;

  DeviceCategory? _filter; // null = all

  List<DeviceInfo> get _visibleDevices {
    if (_filter == null) return _devices;
    return _devices.where((d) => d.category == _filter).toList();
  }

  void _handleFilter(DeviceCategory? filter) {
    setState(() => _filter = filter);
  }

  void _handleAddDevice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng thêm thiết bị sẽ sớm có.')),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }
Future<void> _bootstrapAuth() async {
  if (ApiClient.authToken == null || ApiClient.authToken!.isEmpty) {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('auth_token');
    if (saved != null && saved.isNotEmpty) {
      ApiClient.authToken = saved;
    }
  }
}

  Future<void> _loadDevices() async {
  if (_loading) return;
  setState(() => _loading = true);

  try {
    final list = await DeviceService.fetchMyDevices();
    final futures = <Future<DeviceInfo?>>[];

    for (final d in list) {
      if (d is! Map) continue;
      final map = d.cast<String, dynamic>();

      final idRaw = map['device_id'] ?? map['id'];
      final deviceId = (idRaw is num) ? idRaw.toInt() : int.tryParse('$idRaw');
      if (deviceId == null) continue;

      futures.add(() async {
        final name = (map['name'] ?? 'Thiết bị').toString();
        final status = map['status']?.toString();
        final streamUrl = map['stream_url']?.toString();
        final location = map['location']?.toString();

        final isCamera = (streamUrl != null && streamUrl.isNotEmpty);
        final category = isCamera ? DeviceCategory.camera : DeviceCategory.sensor;

        double? humidity;
        int? battery;
        DateTime updatedAt = DateTime.now();

        // ✅ chạy song song: detail (sensor) + latest detection (camera)
        final detailFuture = DeviceService.fetchMyDeviceDetail(deviceId);
        final latestFuture =
            isCamera ? DeviceService.fetchLatestDetection(deviceId) : Future.value(null);

        final detail = await detailFuture;
        final last = detail['last_sensor_reading'];
        if (last is Map) {
          final lm = last.cast<String, dynamic>();

          final h = lm['humidity'] ?? lm['humidity_percent'] ?? lm['humidityPercent'];
          if (h is num) humidity = h.toDouble();
          if (h is String) humidity = double.tryParse(h);

          final b = lm['battery'] ?? lm['battery_percent'] ?? lm['batteryPercent'];
          if (b is num) battery = b.toInt();
          if (b is String) battery = int.tryParse(b);

          final t = lm['updated_at'] ?? lm['created_at'];
          if (t != null) {
            try {
              updatedAt = DateTime.parse(t.toString());
            } catch (_) {}
          }
        } else {
          // nếu backend có updated_at ngay trên device list:
          final updatedRaw = map['updated_at']?.toString();
          if (updatedRaw != null) {
            try {
              updatedAt = DateTime.parse(updatedRaw);
            } catch (_) {}
          }
        }

        String? latestImageUrl;
        final latest = await latestFuture;
        // ✅ map theo schema bản 1: {found:true, img_url:"..."}
        if (latest != null) {
          final found = latest['found'] == true;
          final img = latest['img_url']?.toString();
          if (found && img != null && img.isNotEmpty) latestImageUrl = img;
        }

        return DeviceInfo(
          deviceId: deviceId,
          name: name,
          category: category,
          isOnline: true,
          icon: isCamera ? Icons.videocam_outlined : Icons.sensors_outlined,
          updatedAt: updatedAt,
          status: status,
          streamUrl: streamUrl,
          location: location,
          humidityPercent: humidity,
          batteryPercent: battery,
          latestImageUrl: latestImageUrl, // ✅ thêm
        );
      }());
    }

    final results = await Future.wait(futures);
    final items = results.whereType<DeviceInfo>().toList();

    // ✅ set default selected camera (ưu tiên status=active)
    final cams = items.where((x) => x.category == DeviceCategory.camera).toList();
    int? defaultCamId;
    if (cams.isNotEmpty) {
      final active = cams.firstWhere(
        (c) => (c.status ?? '').toLowerCase() == 'active',
        orElse: () => cams.first,
      );
      defaultCamId = active.deviceId;
    }

    if (!mounted) return;
    setState(() {
      _devices = items;
      _selectedCameraId ??= defaultCamId;
    });
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi tải thiết bị: $e')),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}





  // ✅ Backend không có select_camera => chọn camera chỉ lưu local UI
  Future<void> _selectCamera(DeviceInfo device) async {
  setState(() => _selectedCameraId = device.deviceId);

  try {
    await DeviceService.selectCamera(device.deviceId); // ✅ lưu server
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đang sử dụng camera: ${device.name}')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không lưu được lựa chọn camera: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FFE9), Color(0xFFF2F9E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadDevices,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Thiết bị',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Quản lý mọi thiết bị thông minh',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _loading ? null : _loadDevices,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF7CCD2B),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: IconButton(
                              onPressed: _handleAddDevice,
                              icon: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterButton(
                          label: 'Tất cả',
                          icon: Icons.grid_view_rounded,
                          isActive: _filter == null,
                          onTap: () => _handleFilter(null),
                        ),
                        const SizedBox(width: 10),
                        _FilterButton(
                          label: 'Camera',
                          icon: Icons.videocam_outlined,
                          isActive: _filter == DeviceCategory.camera,
                          onTap: () => _handleFilter(DeviceCategory.camera),
                        ),
                        const SizedBox(width: 10),
                        _FilterButton(
                          label: 'Cảm biến',
                          icon: Icons.sensors_outlined,
                          isActive: _filter == DeviceCategory.sensor,
                          onTap: () => _handleFilter(DeviceCategory.sensor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_devices.any((d) => d.category == DeviceCategory.camera))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, color: Color(0xFF7CCD2B)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chọn một camera để sử dụng (lưu local)',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  ..._visibleDevices.map((device) {
                    final isSelected = device.category == DeviceCategory.camera &&
                        device.deviceId == _selectedCameraId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DeviceCard(
                        device: device,
                        isSelected: isSelected,
                        onSelect: device.category == DeviceCategory.camera
                            ? () => _selectCamera(device)
                            : null,
                      ),
                    );
                  }).toList(),

                  if (_visibleDevices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text('Không có thiết bị nào cho bộ lọc này.'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF7CCD2B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF7CCD2B) : const Color(0xFFE3E9DA),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF7CCD2B).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF7CCD2B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool isSelected;
  final VoidCallback? onSelect;

  const _DeviceCard({
    required this.device,
    this.isSelected = false,
    this.onSelect,
  });

  String _statusText() {
    final s = (device.status ?? '').toLowerCase();
    if (s.isEmpty) return device.isOnline ? 'Đang hoạt động' : 'Ngoại tuyến';
    return s;
  }

  String _lastUpdateText() {
    final diff = DateTime.now().difference(device.updatedAt);
    if (diff.inMinutes < 1) return 'Cập nhật vài giây trước';
    if (diff.inMinutes < 60) return 'Cập nhật ${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return 'Cập nhật ${diff.inHours} giờ trước';
    return 'Cập nhật ${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    final isCamera = device.category == DeviceCategory.camera;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4D9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(device.icon, color: const Color(0xFF7CCD2B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: device.isOnline ? Colors.green : Colors.grey.shade400,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _statusText(),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                      if ((device.location ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          device.location!,
                          style: const TextStyle(color: Colors.black45, fontSize: 12),
                        ),
                      ]
                    ],
                  ),
                ),
                if (isCamera)
                  InkWell(
                    onTap: onSelect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF7CCD2B) : const Color(0xFFE8F4D9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.white : const Color(0xFF7CCD2B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isSelected ? 'Đang dùng' : 'Chọn dùng',
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF4B8D1F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (device.latestImageUrl != null && device.latestImageUrl!.isNotEmpty) ...[
  const SizedBox(height: 10),
  ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      device.latestImageUrl!,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: 120,
        color: const Color(0xFFE8F4D9),
        child: const Center(child: Icon(Icons.broken_image)),
      ),
    ),
  ),
],

              ],
            ),
            const SizedBox(height: 12),

            if (!isCamera) ...[
              Row(
                children: [
                  const Icon(Icons.opacity, color: Color(0xFF7CCD2B)),
                  const SizedBox(width: 6),
                  Text(
                    '${device.humidityPercent?.toStringAsFixed(0) ?? '--'}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.battery_full, color: Color(0xFF7CCD2B)),
                  const SizedBox(width: 6),
                  Text(
                    '${device.batteryPercent ?? '--'}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ] else ...[
              if ((device.streamUrl ?? '').isNotEmpty)
                Text(
                  'Stream: ${device.streamUrl}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],

            const SizedBox(height: 10),
            Text(
              _lastUpdateText(),
              style: const TextStyle(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
