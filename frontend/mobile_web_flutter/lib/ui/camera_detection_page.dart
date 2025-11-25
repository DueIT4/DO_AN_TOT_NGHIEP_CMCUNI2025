import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/detection_record.dart';
import '../services/detection_service.dart';
import 'detection_detail_page.dart';
import 'devices_page.dart';
import 'user_settings_page.dart';

class CameraDetectionPage extends StatefulWidget {
  const CameraDetectionPage({super.key});

  @override
  State<CameraDetectionPage> createState() => _CameraDetectionPageState();
}

class _CameraDetectionPageState extends State<CameraDetectionPage> {
  final ImagePicker _picker = ImagePicker();
  final ValueNotifier<bool> _loading = ValueNotifier(false);

  List<DetectionRecord> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await DetectionService.fetchHistory();
    if (mounted) {
      setState(() => _history = data);
    }
  }

  Future<void> _handlePick(ImageSource source) async {
    if (_loading.value) return;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;

    _loading.value = true;
    try {
      final record = await DetectionService.analyzeImage(
        file: file,
        source: source == ImageSource.camera
            ? DetectionSource.camera
            : DetectionSource.upload,
      );
      if (!mounted) return;
      setState(() {
        _history = [record, ..._history];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${record.diseaseName} · ${(record.accuracy * 100).toStringAsFixed(0)}%',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể gửi ảnh: $e')),
      );
    } finally {
      _loading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F9E9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Camera & Nhận diện',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                    _CameraPreviewBox(loading: _loading),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handlePick(ImageSource.camera),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              backgroundColor: const Color(0xFF7CCD2B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text(
                              'Chụp ảnh',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _handlePick(ImageSource.gallery),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text(
                              'Thư viện',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Lịch sử phát hiện bệnh',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (_history.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Chưa có lịch sử. Hãy chụp hoặc tải ảnh để bắt đầu.',
                        ),
                      )
                    else
                      ..._history.map(
                        (record) => _DetectionCard(
                          record: record,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DetectionDetailPage(record: record),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
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
          if (index == 1) return;
          if (index == 0) {
            Navigator.pop(context);
            return;
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DevicesPage()),
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

class _CameraPreviewBox extends StatelessWidget {
  final ValueNotifier<bool> loading;

  const _CameraPreviewBox({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF101010), Color(0xFF202020)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: const Center(
                child: Text(
                  'Luồng camera trực tiếp sẽ hiển thị tại đây',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: ValueListenableBuilder(
              valueListenable: loading,
              builder: (_, bool isLoading, __) {
                if (!isLoading) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Đang phân tích...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  final DetectionRecord record;
  final VoidCallback onTap;

  const _DetectionCard({required this.record, required this.onTap});

  String _formattedDate() {
    return DateFormat('dd/MM/yyyy HH:mm').format(record.detectedAt);
  }

  Widget _buildImage() {
    if (record.imageBytes != null) {
      return Image.memory(record.imageBytes!, fit: BoxFit.cover);
    }
    if (record.imageUrl != null && record.imageUrl!.isNotEmpty) {
      return Image.network(record.imageUrl!, fit: BoxFit.cover);
    }
    return Container(
      color: const Color(0xFFE8F4D9),
      child: const Icon(Icons.image_outlined, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (record.accuracy * 100).toStringAsFixed(0);
    final sourceLabel =
        record.source == DetectionSource.camera ? 'Camera' : 'Thư viện';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: _buildImage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          record.diseaseName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4D9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          sourceLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B8D1F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formattedDate(),
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.speed, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '$percent% độ chính xác',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

