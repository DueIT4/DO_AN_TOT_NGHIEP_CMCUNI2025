import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'camera_detection_page.dart';
import 'user_settings_page.dart';

enum DeviceCategory { camera, sensor }

class DeviceInfo {
  final String name;
  final DeviceCategory category;
  final bool isOnline;
  final IconData icon;
  final double? bandwidthMbps;
  final int? batteryPercent;
  final int? humidityPercent;
  final DateTime updatedAt;

  const DeviceInfo({
    required this.name,
    required this.category,
    required this.isOnline,
    required this.icon,
    required this.updatedAt,
    this.bandwidthMbps,
    this.batteryPercent,
    this.humidityPercent,
  });
}

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final List<DeviceInfo> _devices = [
    DeviceInfo(
      name: 'Camera chính',
      category: DeviceCategory.camera,
      isOnline: true,
      icon: Icons.videocam_outlined,
      bandwidthMbps: 25,
      batteryPercent: 85,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
    DeviceInfo(
      name: 'Cảm biến nhiệt độ A1',
      category: DeviceCategory.sensor,
      isOnline: true,
      icon: Icons.thermostat_outlined,
      humidityPercent: 85,
      batteryPercent: 80,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    DeviceInfo(
      name: 'Cảm biến nhiệt độ B2',
      category: DeviceCategory.sensor,
      isOnline: true,
      icon: Icons.water_drop_outlined,
      humidityPercent: 83,
      batteryPercent: 86,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

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
                ..._visibleDevices
                    .map((device) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _DeviceCard(device: device),
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

  const _DeviceCard({required this.device});

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