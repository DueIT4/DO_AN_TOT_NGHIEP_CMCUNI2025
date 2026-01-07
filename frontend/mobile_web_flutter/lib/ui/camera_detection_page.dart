// lib/ui/camera_detection_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/detection_record.dart';
import '../services/detection_service.dart';
import 'detection_detail_page.dart';

DateTime _parseUtcDate(String dateStr) {
  if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
    return DateTime.parse('${dateStr}Z');
  }
  return DateTime.parse(dateStr);
}

class CameraDetectionPage extends StatefulWidget {
  const CameraDetectionPage({super.key});

  @override
  State<CameraDetectionPage> createState() => _CameraDetectionPageState();
}

class _CameraDetectionPageState extends State<CameraDetectionPage> {
  final ImagePicker _picker = ImagePicker();
  final ValueNotifier<bool> _loading = ValueNotifier(false);
  final ValueNotifier<XFile?> _selectedImage =
      ValueNotifier(null); // Lưu ảnh đã chọn

  List<DetectionRecord> _history = const [];
  Timer? _timer;

  // ✅ Highlight IDs (Set to support multiple new items)
  final Set<String> _highlightIds = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // ✅ Start polling for auto-detections
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _pollHistory());
  }

  Future<void> _pollHistory() async {
    try {
      // Fetch latest history silently
      final newData = await DetectionService.fetchHistory(skip: 0, limit: 50);
      if (!mounted) return;
      
      if (_history.isEmpty) {
        // First load or empty, just update if we have data now
        if (newData.isNotEmpty) {
           setState(() => _history = newData);
        }
        return;
      }

      // Check for new items (top of the list)
      final currentTopId = _history.first.id;
      final newItems = <DetectionRecord>[];
      
      for (final item in newData) {
        if (item.id == currentTopId) break; // Reached known data
        newItems.add(item);
      }

      if (newItems.isNotEmpty) {
        // Found new auto-detected items
        setState(() {
          _history = newData;
          // Add new IDs to highlight set
          _highlightIds.addAll(newItems.map((e) => e.id));
        });
        
        // Optional: Show snackbar or visual cue?
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Có phát hiện mới!')));
      } else {
        // No new items, but we might want to update list in case other things changed (e.g. status),
        // but generally we only care if list changed. 
        // Syncing anyway is safer to keep consistency.
        // Only update if length changed or first ID changed to avoid unnecessary rebuilds?
        // For now, let's only update if we found new items to avoid flickering, 
        // OR if the list size is different (e.g. deletion).
        if (newData.length != _history.length) {
            setState(() => _history = newData);
        }
      }

    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final data = await DetectionService.fetchHistory(skip: 0, limit: 50);
      if (!mounted) return;
      debugPrint('[_CameraDetectionPageState] _loadHistory: Set ${data.length} items to state');
      setState(() => _history = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được lịch sử: $e')),
      );
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

    _selectedImage.value = file; // Lưu ảnh đã chọn
    _loading.value = true;
    try {
      final record = await DetectionService.analyzeImage(
        file: file,
        source: source == ImageSource.camera
            ? DetectionSource.camera
            : DetectionSource.upload,
      );

      if (!mounted) return;
      
      // ✅ Set highlight for the new record
      setState(() {
        _highlightIds.add(record.id);
        // Prepend temporarily for immediate feedback
        _history = [record, ..._history]; 
      });

      // ✅ Re-fetch to ensure data consistency
      await _loadHistory();

      if (!mounted) return;
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

  int? _parseDetectionId(DetectionRecord r) => int.tryParse(r.id);

  @override
  Widget build(BuildContext context) {
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
                    'Phân tích bệnh',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
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
                    _CameraPreviewBox(
                        loading: _loading, selectedImage: _selectedImage),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handlePick(ImageSource.camera),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
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
                            isHighlighted: _highlightIds.contains(record.id), // ✅ Check Set
                            onTap: () async {
                              // ✅ Clear highlight on tap
                              if (_highlightIds.contains(record.id)) {
                                  setState(() => _highlightIds.remove(record.id));
                              }

                            try {
                              final detId = _parseDetectionId(record);
                              if (detId == null) {
                                throw Exception(
                                  'Bản ghi đang đồng bộ (id=${record.id}). Hãy bấm refresh.',
                                );
                              }

                              final detail =
                                  await DetectionService.fetchHistoryDetail(
                                      detId);

                              if (!mounted) return;

                              final deleted = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetectionDetailPage(record: detail),
                                ),
                              );

                              if (!mounted) return;
                              if (deleted == true) {
                                await _loadHistory();
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Không tải được chi tiết: $e'),
                                ),
                              );
                            }
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
    );
  }
}

class _CameraPreviewBox extends StatelessWidget {
  final ValueNotifier<bool> loading;
  final ValueNotifier<XFile?> selectedImage;

  const _CameraPreviewBox({required this.loading, required this.selectedImage});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<XFile?>(
      valueListenable: selectedImage,
      builder: (_, imageFile, __) {
        return Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: imageFile == null
                ? const LinearGradient(
                    colors: [Color(0xFF101010), Color(0xFF202020)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: FutureBuilder<Uint8List>(
                            future: imageFile.readAsBytes(),
                            builder: (_, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                } else if (snapshot.hasError) {
                                  return Container(
                                    color: const Color(0xFFE8F4D9),
                                    child: const Icon(Icons.broken_image,
                                        size: 40),
                                  );
                                }
                              }
                              return Container(
                                color: const Color(0xFF202020),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                        )
                      : const Center(
                          child: Text(
                            'Tải hoặc chụp ảnh để hiển thị',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
      },
    );
  }
}

class _DetectionCard extends StatelessWidget {
  final DetectionRecord record;
  final VoidCallback onTap;
  final bool isHighlighted; // ✅ New Parameter

  const _DetectionCard({
    required this.record, 
    required this.onTap,
    this.isHighlighted = false, // Default false
  });

  String _formattedDate() {
    final vietnamTime = record.detectedAt.toLocal();
    return DateFormat('dd/MM/yyyy HH:mm').format(vietnamTime);
  }

  Widget _buildImage() {
    if (record.imageBytes != null) {
      return Image.memory(record.imageBytes!, fit: BoxFit.cover);
    }
    if (record.imageUrl != null && record.imageUrl!.isNotEmpty) {
      return Image.network(
        record.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFE8F4D9),
          child: const Icon(Icons.broken_image, size: 40),
        ),
      );
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
          color: isHighlighted ? const Color(0xFFF0FDF4) : Colors.white, // ✅ Light green bg if highlighted
          borderRadius: BorderRadius.circular(18),
          border: isHighlighted ? Border.all(color: const Color(0xFF4B8D1F), width: 2) : null, // ✅ Green border if highlighted
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
             Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 72, height: 72, child: _buildImage()),
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
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 15,
                                  color: isHighlighted ? const Color(0xFF2E7D32) : Colors.black87 // ✅ Darker text if highlighted
                              ),
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
            // ✅ "Mới" Badge
            if (isHighlighted)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(16), // Match container radius - border width
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: const Text('MỚI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ]
        ),
      ),
    );
  }
}
