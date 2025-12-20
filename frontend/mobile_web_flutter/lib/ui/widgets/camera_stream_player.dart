import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'dart:async';

import '../../services/camera_stream_service.dart';

/// Widget hiển thị camera stream HLS với error handling
class CameraStreamPlayer extends StatefulWidget {
  final int deviceId;
  final String deviceName;
  final String hlsUrl;
  final VoidCallback? onCameraChanged; // Gọi khi đổi camera

  const CameraStreamPlayer({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.hlsUrl,
    this.onCameraChanged,
  });

  @override
  State<CameraStreamPlayer> createState() => _CameraStreamPlayerState();
}

class _CameraStreamPlayerState extends State<CameraStreamPlayer> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  String? _errorMessage;
  Timer? _healthCheckTimer;

  @override
  void initState() {
    super.initState();
    _startStreamAndInitVideo();
    _startHealthCheck();
  }

  // ✅ Start stream trước khi initialize video
  Future<void> _startStreamAndInitVideo() async {
    setState(() {
      _isInitialized = false;
      _errorMessage = null;
    });

    try {
      // 1. Start stream từ backend
      final result = await CameraStreamService.startStream(widget.deviceId);

      if (result['running'] != true) {
        setState(() {
          _errorMessage =
              result['message']?.toString() ?? 'Không thể khởi động stream';
        });
        return;
      }

      // 2. Wait 2 giây để FFmpeg tạo segments
      await Future.delayed(const Duration(seconds: 2));

      // 3. Initialize video player
      _initializeVideo();
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khởi động: $e';
      });
    }
  }

  @override
  void didUpdateWidget(CameraStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nếu HLS URL thay đổi → reinitialize
    if (oldWidget.hlsUrl != widget.hlsUrl) {
      _cleanupVideo();
      _initializeVideo();
    }
  }

  void _initializeVideo() {
    // Build HLS URL: prefer provided URL; fallback to computed
    final provided = widget.hlsUrl.trim();
    final fullUrl = provided.isNotEmpty
        ? provided
        : CameraStreamService.buildFullHlsUrl(widget.deviceId);

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(fullUrl),
      formatHint: VideoFormat.hls, // HLS.js sẽ xử lý trên web
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
        });
        _videoController.play();
      }).catchError((e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Lỗi phát video: $e';
        });
      });
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      if (!mounted) return;

      final health =
          await CameraStreamService.checkStreamHealth(widget.deviceId);
      final isHealthy = health['healthy'] == true;

      if (!mounted) return;

      if (!isHealthy && _errorMessage == null) {
        setState(() {
          _errorMessage =
              health['error']?.toString() ?? 'Camera không hoạt động';
        });
      } else if (isHealthy && _errorMessage != null) {
        setState(() {
          _errorMessage = null;
        });
        // Thử phát lại
        if (_videoController.value.isInitialized &&
            !_videoController.value.isPlaying) {
          _videoController.play();
        }
      }
    });
  }

  void _cleanupVideo() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    // Dù chưa initialize vẫn nên dispose để giải phóng tài nguyên
    try {
      _videoController.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanupVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Video player
            if (_isInitialized && _errorMessage == null)
              VideoPlayer(_videoController)
            else
              Container(
                color: Colors.grey[800],
                child: Center(
                  child: _errorMessage != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.videocam_off,
                              color: Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                _cleanupVideo();
                                _startStreamAndInitVideo();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Kết nối lại'),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF7CCD2B),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Đang kết nối camera...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                ),
              ),

            // Header: Camera name + controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.deviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _errorMessage != null
                            ? Colors.red.withOpacity(0.8)
                            : Colors.green.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _errorMessage != null ? 'Offline' : 'Online',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Play/Pause button (nếu video đã load)
            if (_isInitialized && _errorMessage == null)
              Positioned(
                bottom: 12,
                right: 12,
                child: FloatingActionButton.small(
                  backgroundColor: Colors.black.withOpacity(0.6),
                  onPressed: () {
                    setState(() {
                      if (_videoController.value.isPlaying) {
                        _videoController.pause();
                      } else {
                        _videoController.play();
                      }
                    });
                  },
                  child: Icon(
                    _videoController.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
