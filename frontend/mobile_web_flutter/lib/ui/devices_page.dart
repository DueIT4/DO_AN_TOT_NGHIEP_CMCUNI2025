import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'camera_detection_page.dart';
import 'user_settings_page.dart';
import '../services/device_service.dart';

enum DeviceCategory { camera, sensor }

class DeviceInfo {
  final int? deviceId;
  final String name;
  final DeviceCategory category;
  final bool isOnline;
  final IconData icon;
  final double? bandwidthMbps;
  final int? batteryPercent;
  final int? humidityPercent;
  final DateTime updatedAt;
  final String? latestImageUrl;
  final String status;

  const DeviceInfo({
    this.deviceId,
    required this.name,
    required this.category,
    required this.isOnline,
    required this.icon,
    required this.updatedAt,
    this.latestImageUrl,
    this.bandwidthMbps,
    this.batteryPercent,
    this.humidityPercent,
    this.status = 'inactive',
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

  DeviceCategory? _filter; // null = all

  List<DeviceInfo> get _visibleDevices {
    if (_filter == null) return _devices;
    return _devices.where((device) => device.category == _filter).toList();
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

  Future<void> _loadDevices() async {
    try {
      final list = await DeviceService.fetchDevices();
      final items = <DeviceInfo>[];
      for (final d in list) {
        final name = (d['name'] ?? 'Thiết bị').toString();
        final streamUrl = (d['stream_url'] ?? '').toString();
        final gateway = (d['gateway_stream_id'] ?? '').toString();
        final isCamera = (streamUrl.isNotEmpty || gateway.isNotEmpty);
        DateTime updated = DateTime.now();
        final updatedRaw = d['updated_at']?.toString();
        if (updatedRaw != null) {
          try {
            updated = DateTime.parse(updatedRaw);
          } catch (_) {}
        }

        String? latestUrl;
        if (isCamera && d['device_id'] != null) {
          final latest = await DeviceService.fetchLatest(d['device_id']);
          if (latest != null &&
              latest['found'] == true &&
              latest['img_url'] != null) {
            latestUrl = latest['img_url'] as String?;
          }
        }

        items.add(DeviceInfo(
          deviceId: d['device_id'] as int?,
          name: name,
          category: isCamera ? DeviceCategory.camera : DeviceCategory.sensor,
          isOnline: true,
          icon: isCamera ? Icons.videocam_outlined : Icons.sensors_outlined,
          updatedAt: updated,
          latestImageUrl: latestUrl,
          status: (d['status'] ?? 'inactive').toString(),
        ));
      }

      if (mounted) {
        final cameraDevices =
            items.where((d) => d.category == DeviceCategory.camera).toList();
        int? defaultCam;
        if (cameraDevices.isNotEmpty) {
          final activeCam = cameraDevices.firstWhere(
            (d) => d.status == 'active',
            orElse: () => cameraDevices.first,
          );
          defaultCam = activeCam.deviceId;
        }

        setState(() {
          _devices = items;
          _selectedCameraId = defaultCam;
        });
      }
    } catch (e) {
      // ignore errors for now
    }
  }

  void _selectCamera(DeviceInfo device) {
    if (device.deviceId == null) return;
    setState(() => _selectedCameraId = device.deviceId);
    DeviceService.selectCamera(device.deviceId!).then((ok) {
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được lựa chọn camera')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đang sử dụng camera: ${device.name}')),
        );
      }
    });
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
          child: SingleChildScrollView(
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
                          onPressed: () {},
                          icon: const Icon(Icons.search),
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
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFF7CCD2B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _devices
                                          .where((d) =>
                                              d.category ==
                                              DeviceCategory.camera)
                                          .length >
                                      1
                                  ? 'Chọn một camera để sử dụng (tối đa 1)'
                                  : 'Camera sẽ được dùng mặc định',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ..._visibleDevices
                    .map((device) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _DeviceCard(
                            device: device,
                            isSelected:
                                device.category == DeviceCategory.camera &&
                                    device.deviceId != null &&
                                    device.deviceId == _selectedCameraId,
                            onSelect: device.category == DeviceCategory.camera
                                ? () => _selectCamera(device)
                                : null,
                          ),
                        ))
                    .toList(),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF7CCD2B),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              label: l10n.translate('home_tab')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.videocam_outlined),
              label: l10n.translate('camera_tab')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.sensors_outlined),
              label: l10n.translate('device_tab')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              label: l10n.translate('personal_tab')),
        ],
        onTap: (index) {
          if (index == 2) return;
          if (index == 0) {
            Navigator.pop(context);
            return;
          }
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraDetectionPage()),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserSettingsPage()),
          );
        },
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

  String _statusText() => device.isOnline ? 'Đang hoạt động' : 'Ngoại tuyến';

  String _lastUpdateText() {
    final diff = DateTime.now().difference(device.updatedAt);
    if (diff.inMinutes < 1) return 'Cập nhật vài giây trước';
    if (diff.inMinutes < 60) {
      return 'Cập nhật ${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24) {
      return 'Cập nhật ${diff.inHours} giờ trước';
    }
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
                            color: device.isOnline
                                ? Colors.green
                                : Colors.grey.shade400,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _statusText(),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isCamera)
                  InkWell(
                    onTap: onSelect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7CCD2B)
                            : const Color(0xFFE8F4D9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF7CCD2B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isSelected ? 'Đang dùng' : 'Chọn dùng',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF4B8D1F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isCamera) ...[
              Row(
                children: [
                  const Icon(Icons.wifi, color: Color(0xFF7CCD2B)),
                  const SizedBox(width: 6),
                  Text(
                    '${device.bandwidthMbps?.toStringAsFixed(0) ?? '--'} Mb/s',
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
              const SizedBox(height: 12),
              if (device.latestImageUrl != null) ...[
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
                const SizedBox(height: 8),
              ],
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.opacity, color: Color(0xFF7CCD2B)),
                  const SizedBox(width: 6),
                  Text(
                    '${device.humidityPercent ?? '--'}%',
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
            ],
            const SizedBox(height: 12),
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
