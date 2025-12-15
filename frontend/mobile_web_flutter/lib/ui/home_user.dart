import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/web_hls_player.dart';

import '../l10n/app_localizations.dart';
import '../models/notification.dart' as models;
import '../services/api_client.dart';
//import '../services/device_service.dart';
import '../core/api_base.dart';
import 'ai_chat_page.dart';
import 'camera_detection_page.dart';
import 'devices_page.dart';
import 'notifications_list_page.dart';
import 'user_settings_page.dart';

class HomeUserPage extends StatefulWidget {
  const HomeUserPage({super.key});

  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  int _currentIndex = 0; // bottom nav

  String? _droicamUrl; // lưu địa chỉ Droicam đã nhập
  final TextEditingController _droicamCtrl = TextEditingController();

  // Thông báo
  List<models.AppNotification> _notifications = [];
  bool _notificationsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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
        final notifications = (data as List)
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

  Future<void> _showDroicamDialog() async {
    // gợi ý lại url cũ nếu đã có
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
                      content: Text('Vui lòng nhập địa chỉ Droicam'),
                    ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserSettingsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline),
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

              // ========== 2 CARD ĐỘ ẨM / NHIỆT ĐỘ ==========
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: l10n.translate('humidity'),
                      value: '70%',
                      icon: Icons.water_drop_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: l10n.translate('temperature'),
                      value: '27 °C',
                      icon: Icons.thermostat_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ========== CAMERA ==========
              GestureDetector(
                onTap: _showDroicamDialog, // chạm để nhập địa chỉ Droicam
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: (_droicamUrl == null || _droicamUrl!.isEmpty)
                          ? Center(
                              child: Text(
                                l10n.translate('camera_hint'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            )
                          : DroicamView(url: _droicamUrl!),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('camera_title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(l10n.translate('camera_hint')),
                ],
              ),
              const SizedBox(height: 16),

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
                      onTap: () {
                        // TODO: điều hướng sang trang báo cáo
                      },
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
                          // Reload notifications khi quay lại
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

      // ========== BOTTOM NAV ==========
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraDetectionPage()),
            );
            return;
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DevicesPage()),
            );
            return;
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserSettingsPage()),
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        selectedItemColor: const Color(0xFF7CCD2B),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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
      ),
    );
  }
}

// ================= DROICAM VIEW (bản mobile – placeholder) =================
class DroicamView extends StatefulWidget {
  final String url;
  const DroicamView({super.key, required this.url});

  @override
  State<DroicamView> createState() => _DroicamViewState();
}

class _DroicamViewState extends State<DroicamView> {
  String? _hlsUrl;
  String? _tempKey;
  bool _starting = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _ensureStream();
  }

  @override
  void didUpdateWidget(covariant DroicamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _stopTempStreamIfAny();
      _ensureStream();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _stopTempStreamIfAny();
    super.dispose();
  }

  Future<void> _ensureStream() async {
    setState(() {
      _starting = true;
      _hlsUrl = null;
    });

    try {
      final uri = Uri.parse(ApiBase.api('/streams/start_temp'));
      final resp = await http.post(uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"url": widget.url}));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final hls = data['hls_url'] as String?;
        final key = data['key'] as String?;
        if (hls != null) {
          final full = hls.startsWith('http') ? hls : ApiBase.host + hls;
          _tempKey = key;
          await _startVideo(full);
          setState(() {
            _hlsUrl = full;
          });
          return;
        }
      }
      setState(() {
        _hlsUrl = null;
      });
    } catch (e) {
      setState(() {
        _hlsUrl = null;
      });
    } finally {
      setState(() {
        _starting = false;
      });
    }
  }

  Future<void> _startVideo(String url) async {
    // On web we use the embedded hls.js player (iframe). video_player
    // is used for mobile platforms only.
    if (kIsWeb) {
      return;
    }

    _videoController?.dispose();
    _videoController = VideoPlayerController.network(url);
    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      await _videoController!.play();
      setState(() {});
    } catch (e) {
      // ignore
    }
  }

  Future<void> _stopTempStreamIfAny() async {
    if (_tempKey == null) return;
    try {
      final uri = Uri.parse(ApiBase.api('/streams/stop_temp'));
      await http.post(uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"key": _tempKey}));
    } catch (_) {}
    _tempKey = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: _starting
                ? const Center(child: CircularProgressIndicator())
                : (kIsWeb
                    // On web use hls.js iframe player
                    ? (_hlsUrl != null
                        ? WebHlsPlayer(
                            hlsUrl: _hlsUrl!,
                            viewId: 'hls-${_tempKey ?? 'tmp'}',
                          )
                        : Center(
                            child: Text(
                              l10n.translate('camera_hint'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ))
                    // On mobile/desktop use VideoPlayer
                    : (_videoController != null &&
                            _videoController!.value.isInitialized)
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : Center(
                            child: Text(
                              l10n.translate('camera_hint'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          )),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _starting
                    ? null
                    : () {
                        _ensureStream();
                      },
                tooltip: 'Làm mới',
              ),
              if (_videoController != null)
                IconButton(
                  icon: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_videoController!.value.isPlaying) {
                      _videoController!.pause();
                    } else {
                      _videoController!.play();
                    }
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// class DroicamView extends StatefulWidget {
//   final String url;

//   const DroicamView({super.key, required this.url});

//   @override
//   State<DroicamView> createState() => _DroicamViewState();
// }

// class _DroicamViewState extends State<DroicamView> {
//   int? _deviceId;
//   String? _imageUrl; // full URL to show
//   String? _statusMsg;
//   Timer? _pollTimer;
//   bool _loading = false;

//   @override
//   void initState() {
//     super.initState();
//     _initForUrl();
//     _startPolling();
//   }

//   @override
//   void didUpdateWidget(covariant DroicamView oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.url != widget.url) {
//       _initForUrl();
//     }
//   }

//   @override
//   void dispose() {
//     _pollTimer?.cancel();
//     super.dispose();
//   }

//   void _startPolling() {
//     _pollTimer?.cancel();
//     // Poll every 30 seconds for new detection images
//     _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
//       if (_deviceId != null) _fetchLatest();
//     });
//   }

//   Future<void> _initForUrl() async {
//     setState(() {
//       _statusMsg = 'Đang tìm thiết bị...';
//       _loading = true;
//       _imageUrl = null;
//       _deviceId = null;
//     });

//     try {
//       final devices = await DeviceService.fetchDevices();
//       final matched = devices.firstWhere(
//         (d) {
//           final s = (d['stream_url'] ?? '') as String;
//           final g = (d['gateway_stream_id'] ?? '') as String;
//           return s == widget.url || g == widget.url;
//         },
//         orElse: () => null,
//       );

//       if (matched != null) {
//         setState(() {
//           _deviceId = matched['id'] as int?;
//           _statusMsg = null;
//         });
//         await _fetchLatest();
//       } else {
//         setState(() {
//           _statusMsg = 'Không tìm thấy thiết bị khớp. Chưa có ảnh hiển thị.';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _statusMsg = 'Lỗi khi tìm thiết bị';
//       });
//     } finally {
//       setState(() {
//         _loading = false;
//       });
//     }
//   }

//   Future<void> _fetchLatest() async {
//     if (_deviceId == null) return;
//     setState(() => _loading = true);
//     try {
//       final data = await DeviceService.fetchLatest(_deviceId!);
//       if (data != null && data['found'] == true && data['img_url'] != null) {
//         var url = data['img_url'] as String;
//         if (!url.startsWith('http')) {
//           url = ApiBase.host + url;
//         }
//         setState(() {
//           _imageUrl = url;
//           _statusMsg = null;
//         });
//       } else {
//         setState(() {
//           _statusMsg = 'Chưa có ảnh phân tích gần đây.';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _statusMsg = 'Lỗi khi tải ảnh';
//       });
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final l10n = AppLocalizations.of(context);
//     return Stack(
//       children: [
//         AspectRatio(
//           aspectRatio: 16 / 9,
//           child: Container(
//             color: Colors.black,
//             child: _imageUrl == null
//                 ? Center(
//                     child: _loading
//                         ? const CircularProgressIndicator()
//                         : Text(
//                             _statusMsg ?? l10n.translate('camera_hint'),
//                             textAlign: TextAlign.center,
//                             style: const TextStyle(color: Colors.white70),
//                           ),
//                   )
//                 : Image.network(
//                     _imageUrl!,
//                     fit: BoxFit.cover,
//                     errorBuilder: (ctx, err, st) => Center(
//                       child: Text(
//                         l10n.translate('camera_hint'),
//                         style: const TextStyle(color: Colors.white70),
//                       ),
//                     ),
//                   ),
//           ),
//         ),
//         Positioned(
//           right: 8,
//           top: 8,
//           child: Row(
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.refresh, color: Colors.white),
//                 onPressed: _loading ? null : _fetchLatest,
//                 tooltip: 'Làm mới',
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
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
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
            ),
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
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
