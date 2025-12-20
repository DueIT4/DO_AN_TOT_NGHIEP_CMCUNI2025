# Hướng Dẫn Streaming Video Real-time

## 🎯 Tổng Quan

Hệ thống hỗ trợ streaming video real-time liên tục từ DroidCam hoặc camera IP thông qua:
- **Backend**: FFmpeg chuyển đổi RTSP/HTTP → HLS (HTTP Live Streaming)
- **Frontend**: Video player hiển thị HLS stream trong trình duyệt

## 🚀 Quick Start

### Bước 1: Thêm Device với Stream URL

```bash
# Thêm DroidCam device
curl -X POST http://localhost:8000/api/v1/devices/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "name": "DroidCam Living Room",
    "device_type_id": 1,
    "stream_url": "http://192.168.1.6:4747/video",
    "status": "active"
  }'

# Response sẽ trả về device_id (ví dụ: 123)
```

### Bước 2: Start Stream

```bash
# Start streaming cho device_id = 123
curl -X POST http://localhost:8000/api/v1/streams/start \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"device_id": 123}'

# Response:
{
  "hls_url": "/media/hls/123/index.m3u8",
  "running": true,
  "message": "Stream started or resumed"
}
```

### Bước 3: Xem Video trong Browser

**HTML Example:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>DroidCam Live Stream</title>
    <!-- HLS.js library -->
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
</head>
<body>
    <h1>Live Camera Feed</h1>
    <video id="video" controls autoplay width="800"></video>

    <script>
        const video = document.getElementById('video');
        const hlsUrl = 'http://localhost:8000/media/hls/123/index.m3u8';

        if (Hls.isSupported()) {
            const hls = new Hls({
                enableWorker: true,
                lowLatencyMode: true,
                backBufferLength: 10
            });
            hls.loadSource(hlsUrl);
            hls.attachMedia(video);
            
            hls.on(Hls.Events.MANIFEST_PARSED, function() {
                video.play();
            });
            
            hls.on(Hls.Events.ERROR, function(event, data) {
                console.error('HLS Error:', data);
            });
        } 
        // Safari native HLS support
        else if (video.canPlayType('application/vnd.apple.mpegurl')) {
            video.src = hlsUrl;
        }
    </script>
</body>
</html>
```

## 📡 API Endpoints

### 1. Start Stream
```http
POST /api/v1/streams/start
Content-Type: application/json

{
  "device_id": 123
}
```

**Response:**
```json
{
  "hls_url": "/media/hls/123/index.m3u8",
  "running": true,
  "message": "Stream started or resumed"
}
```

### 2. Stop Stream
```http
POST /api/v1/streams/stop
Content-Type: application/json

{
  "device_id": 123
}
```

### 3. Check Stream Status
```http
GET /api/v1/streams/device/123
```

**Response:**
```json
{
  "running": true,
  "hls_url": "/media/hls/123/index.m3u8",
  "info": {
    "device_id": 123,
    "rtsp_url": "http://192.168.1.6:4747/video",
    "hls_url": "/media/hls/123/index.m3u8",
    "running": true,
    "pid": 12345
  }
}
```

### 4. Check Stream Health
```http
GET /api/v1/streams/health/123
```

**Response:**
```json
{
  "healthy": true,
  "running": true,
  "error": null,
  "hls_exists": true,
  "last_update": 1.5
}
```

### 5. List Active Streams
```http
GET /api/v1/streams/active
```

## 🎬 Integration với Flutter

**Thêm package trong `pubspec.yaml`:**
```yaml
dependencies:
  video_player: ^2.8.0
  flutter_vlc_player: ^7.4.0  # Alternative cho HLS
```

**Flutter Code:**
```dart
import 'package:video_player/video_player.dart';

class LiveStreamPage extends StatefulWidget {
  final int deviceId;
  const LiveStreamPage({required this.deviceId});

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  late VideoPlayerController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  Future<void> _initStream() async {
    // 1. Start stream via API
    final response = await http.post(
      Uri.parse('http://localhost:8000/api/v1/streams/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_id': widget.deviceId}),
    );

    final data = jsonDecode(response.body);
    final hlsUrl = 'http://localhost:8000${data['hls_url']}';

    // 2. Initialize video player
    _controller = VideoPlayerController.network(hlsUrl)
      ..initialize().then((_) {
        setState(() => _isLoading = false);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
```

## ⚙️ Cấu Hình FFmpeg

Stream service tự động cấu hình FFmpeg với các tham số tối ưu:

```bash
# Cho RTSP
ffmpeg -y -rtsp_transport tcp -i rtsp://... \
  -c:v libx264 -preset veryfast -g 50 -sc_threshold 0 -an \
  -f hls -hls_time 2 -hls_list_size 6 \
  -hls_flags independent_segments+append_list \
  -hls_segment_filename segment_%03d.ts index.m3u8

# Cho HTTP/MJPEG (DroidCam)
ffmpeg -y -f mjpeg -analyzeduration 0 -probesize 32 -i http://... \
  -c:v libx264 -preset veryfast -g 50 -sc_threshold 0 -an \
  -f hls -hls_time 2 -hls_list_size 6 \
  -hls_flags independent_segments+append_list \
  -hls_segment_filename segment_%03d.ts index.m3u8
```

**Giải thích tham số:**
- `-hls_time 2`: Mỗi segment dài 2 giây (độ trễ thấp)
- `-hls_list_size 6`: Giữ 6 segments mới nhất
- `-preset veryfast`: Encode nhanh, độ trễ thấp
- `-g 50`: GOP size cho smooth playback
- `-an`: Không có audio (tùy chọn)

## 🔧 Troubleshooting

### Lỗi: "ffmpeg not found"

**Giải pháp:**
```bash
# Windows (Chocolatey)
choco install ffmpeg

# Windows (Manual)
# Tải từ https://ffmpeg.org/download.html
# Thêm vào PATH

# Linux
sudo apt install ffmpeg

# macOS
brew install ffmpeg
```

### Lỗi: Stream không hiển thị

**Kiểm tra:**
```bash
# 1. Check stream đang chạy
curl http://localhost:8000/api/v1/streams/device/123

# 2. Check health
curl http://localhost:8000/api/v1/streams/health/123

# 3. Check HLS files exist
ls backend/media/hls/123/

# 4. Check ffmpeg log
cat backend/media/hls/123/ffmpeg.log
```

### Lỗi: Độ trễ cao

**Giải pháp:**
1. Giảm `hls_time` xuống 1 giây (trade-off với overhead)
2. Sử dụng WebRTC thay vì HLS (latency < 500ms)
3. Tăng bandwidth mạng
4. Giảm resolution trong DroidCam

### Lỗi: "Stream not updating"

**Nguyên nhân:**
- Camera mất kết nối
- FFmpeg process died
- Network issue

**Giải pháp:**
```bash
# Restart stream
curl -X POST http://localhost:8000/api/v1/streams/stop \
  -d '{"device_id": 123}'

curl -X POST http://localhost:8000/api/v1/streams/start \
  -d '{"device_id": 123}'
```

## 📊 Performance Tips

### 1. Optimize FFmpeg
```python
# Trong stream_service.py, có thể điều chỉnh:
"-preset", "ultrafast",  # Faster encoding
"-tune", "zerolatency",  # Lower latency
"-hls_time", "1",        # Shorter segments
```

### 2. Browser-side Optimization
```javascript
const hls = new Hls({
  enableWorker: true,
  lowLatencyMode: true,
  backBufferLength: 10,
  maxBufferLength: 20,
  maxMaxBufferLength: 30,
  liveSyncDurationCount: 3
});
```

### 3. Network
- Sử dụng Ethernet thay vì WiFi nếu có thể
- Đảm bảo router không bị quá tải
- QoS settings ưu tiên traffic video

## 🔐 Security

### 1. Authentication
```python
# Trong routes_streams.py, thêm:
from app.api.v1.deps import get_current_user

@router.post("/streams/start")
def start_stream(
    payload: StartStreamIn,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)  # ✅ Require auth
):
    # ... existing code
```

### 2. Rate Limiting
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/streams/start")
@limiter.limit("10/minute")  # Max 10 requests/minute
def start_stream(...):
    # ... existing code
```

### 3. CORS
```python
# Trong config.py
CORS_ORIGINS = [
    "http://localhost:57174",  # Flutter dev
    "https://yourdomain.com",
    # ... trusted domains only
]
```

## 📱 Mobile Considerations

### iOS Safari
- Native HLS support, không cần HLS.js
- Tự động fullscreen khi play
- Requires user interaction để play

### Android Chrome
- Cần HLS.js library
- Hardware acceleration support tốt
- Battery optimization ảnh hưởng background playback

## 🎯 Advanced: WebRTC (Ultra Low Latency)

Nếu cần latency < 500ms, cân nhắc WebRTC:

```bash
# Cài đặt mediasoup (WebRTC SFU)
npm install mediasoup

# Hoặc dùng Janus Gateway
# https://janus.conf.meetecho.com/
```

## 📚 Resources

- [HLS.js Documentation](https://github.com/video-dev/hls.js/)
- [FFmpeg HLS Guide](https://trac.ffmpeg.org/wiki/StreamingGuide)
- [Video.js Player](https://videojs.com/)
- [Flutter Video Player](https://pub.dev/packages/video_player)

## 💡 Best Practices

1. **Always check stream health** trước khi hiển thị cho user
2. **Implement auto-reconnect** khi stream bị disconnect
3. **Show loading state** khi đang khởi tạo stream
4. **Handle errors gracefully** với user-friendly messages
5. **Stop stream** khi user rời khỏi trang để tiết kiệm tài nguyên
6. **Monitor ffmpeg logs** để debug issues
7. **Use CDN** cho production để scale tốt hơn

---

**Ready to stream!** 🎥 Giờ bạn có thể xem video real-time từ DroidCam trong trình duyệt!
