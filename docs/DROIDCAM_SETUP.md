# Hướng Dẫn Cấu Hình DroidCam RTSP

## 📱 Tổng Quan

DroidCam cho phép bạn sử dụng điện thoại Android/iOS làm webcam thông qua RTSP hoặc HTTP. Hệ thống hỗ trợ đầy đủ cả hai giao thức.

## 🚀 Cài Đặt DroidCam

### Trên Điện Thoại:
1. Tải **DroidCam** từ:
   - Android: [Google Play Store](https://play.google.com/store/apps/details?id=com.dev47apps.droidcam)
   - iOS: [App Store](https://apps.apple.com/us/app/droidcam-webcam-obs-camera/id1510258102)

2. Mở app và cho phép quyền truy cập camera

3. Kết nối điện thoại và server cùng một mạng WiFi

4. Nhấn **"Start Server"** trong app

5. Ghi lại địa chỉ IP hiển thị (ví dụ: `192.168.1.100`)

## 🔗 Định Dạng URL

### 1. RTSP (Khuyên Dùng)

**URL cơ bản:**
```
rtsp://192.168.1.100:8554/video
```

**URL có authentication:**
```
rtsp://username:password@192.168.1.100:8554/video
```

**URL với UDP transport:**
```
rtsp://192.168.1.100:8554/video?transport=udp
```

### 2. HTTP/MJPEG

**HTTP video:**
```
http://192.168.1.100:4747/video
```

**MJPEG stream:**
```
http://192.168.1.100:4747/mjpegfeed
```

**HTTP snapshot:**
```
http://192.168.1.100:4747/snapshot.jpg
```

## ⚙️ Cấu Hình Tối Ưu

| Thông Số | Giá Trị Khuyến Nghị | Ghi Chú |
|----------|---------------------|---------|
| **Resolution** | 720p hoặc 480p | Tùy vào tốc độ mạng |
| **FPS** | 15-30 fps | Giảm xuống nếu lag |
| **Bitrate** | 1-3 Mbps | Tăng cho chất lượng cao |
| **Transport** | TCP | Ổn định hơn UDP |
| **Port RTSP** | 8554 | Mặc định |
| **Port HTTP** | 4747 | Mặc định |

## 📝 Cách Sử Dụng Với Hệ Thống

### Bước 1: Test URL Trước Khi Lưu

```bash
# Sử dụng API endpoint
POST /api/v1/devices/test_stream_url
Content-Type: application/json

{
  "stream_url": "rtsp://192.168.1.100:8554/video",
  "timeout": 10
}
```

Response khi thành công:
```json
{
  "success": true,
  "message": "Kết nối thành công với RTSP stream",
  "url_type": "rtsp",
  "can_capture": true,
  "image_size": 125834,
  "tips": "URL hoạt động tốt, bạn có thể lưu vào device"
}
```

### Bước 2: Tạo Device Với URL

```bash
POST /api/v1/devices/
Content-Type: application/json
Authorization: Bearer <token>

{
  "name": "DroidCam Phòng Khách",
  "device_type_id": 1,
  "stream_url": "rtsp://192.168.1.100:8554/video",
  "status": "active"
}
```

### Bước 3: Xem Hướng Dẫn Từ API

```bash
GET /api/v1/devices/droidcam_guide
Authorization: Bearer <token>
```

## 🛠️ Xử Lý Lỗi Thường Gặp

### Lỗi: "Cannot open RTSP stream"

**Nguyên nhân:**
- Điện thoại và server không cùng mạng
- Firewall chặn port 8554
- DroidCam app chưa start server
- Sai địa chỉ IP

**Giải pháp:**
1. Kiểm tra cả 2 thiết bị đều kết nối WiFi giống nhau
2. Tắt firewall hoặc mở port:
   ```bash
   # Windows Firewall
   netsh advfirewall firewall add rule name="DroidCam RTSP" dir=in action=allow protocol=TCP localport=8554
   
   # Linux iptables
   sudo iptables -A INPUT -p tcp --dport 8554 -j ACCEPT
   ```
3. Restart DroidCam app
4. Ping IP để test kết nối:
   ```bash
   ping 192.168.1.100
   ```

### Lỗi: "Timeout" hoặc Lag

**Giải pháp:**
1. Giảm resolution xuống 480p trong DroidCam settings
2. Chuyển sang TCP nếu đang dùng UDP:
   ```
   rtsp://192.168.1.100:8554/video?transport=tcp
   ```
3. Giảm FPS xuống 15-20
4. Kiểm tra tốc độ mạng WiFi
5. Đảm bảo không có thiết bị khác đang chiếm băng thông

### Lỗi: "Video format not supported"

**Giải pháp:**
1. Đảm bảo OpenCV đã được cài đặt:
   ```bash
   pip install opencv-python-headless
   ```
2. Thử các URL format khác:
   ```
   # Thử MJPEG thay vì RTSP
   http://192.168.1.100:4747/mjpegfeed
   
   # Hoặc HTTP video
   http://192.168.1.100:4747/video
   ```
3. Check log backend để xem lỗi chi tiết

### Lỗi: "Poor Video Quality"

**Giải pháp:**
1. Tăng bitrate trong DroidCam settings
2. Đảm bảo ánh sáng tốt (DroidCam rất nhạy sáng)
3. Tăng resolution lên 720p nếu mạng ổn định
4. Chọn camera sau thay vì camera trước (thường chất lượng tốt hơn)
5. Giữ điện thoại cố định (không rung lắc)

## 🔒 Bảo Mật

### Sử dụng Authentication (Khuyến Nghị)

1. Trong DroidCam app, bật **"Enable Authentication"**
2. Đặt username và password
3. Sử dụng URL có auth:
   ```
   rtsp://myuser:mypass@192.168.1.100:8554/video
   ```

### Mạng Riêng

- Không expose DroidCam ra internet công cộng
- Chỉ sử dụng trong mạng LAN tin cậy
- Có thể setup VPN nếu cần truy cập từ xa

## 📊 So Sánh RTSP vs HTTP

| Tiêu Chí | RTSP | HTTP/MJPEG |
|----------|------|------------|
| **Độ trễ** | Thấp (< 1s) | Cao (2-3s) |
| **Ổn định** | Cao | Trung bình |
| **Tương thích** | Cần OpenCV | Native support |
| **Băng thông** | Tối ưu | Cao hơn |
| **Setup** | Phức tạp hơn | Đơn giản |
| **Khuyến nghị** | Production | Testing |

## 🧪 Testing & Debugging

### Test Connectivity Từ Command Line

**Test RTSP với ffmpeg:**
```bash
ffmpeg -i rtsp://192.168.1.100:8554/video -frames:v 1 test.jpg
```

**Test HTTP với curl:**
```bash
curl -o snapshot.jpg http://192.168.1.100:4747/snapshot.jpg
```

**Test RTSP với OpenCV (Python):**
```python
import cv2

cap = cv2.VideoCapture("rtsp://192.168.1.100:8554/video")
ret, frame = cap.read()
if ret:
    cv2.imwrite("test.jpg", frame)
    print("Success!")
else:
    print("Failed to capture")
cap.release()
```

### View Logs

Backend log sẽ hiển thị chi tiết:
```
[Camera] Successfully captured from RTSP: rtsp://192.168.1.100:8554/video
[Camera] Cannot open RTSP stream: rtsp://...
[Camera] Error capturing RTSP: [Errno 111] Connection refused
```

## 💡 Tips & Tricks

1. **Giữ điện thoại sạc:** DroidCam tiêu tốn pin nhanh
2. **Sử dụng giá đỡ:** Để camera ổn định
3. **Tắt sleep mode:** Không để điện thoại tự khóa màn hình
4. **Background mode:** Enable trong DroidCam settings để chạy background
5. **Multiple cameras:** Có thể chạy nhiều điện thoại với IP khác nhau
6. **Quality vs Performance:** Cân bằng giữa chất lượng và hiệu năng

## 🔄 Alternative Apps

Nếu DroidCam không hoạt động, thử:
- **IP Webcam** (Android)
- **EpocCam** (iOS/Android)
- **iVCam** (iOS/Android)
- **Iriun Webcam** (iOS/Android)

## 📞 Support

Nếu vẫn gặp vấn đề:
1. Check log backend trong terminal
2. Test URL bằng API endpoint `/devices/test_stream_url`
3. Xem guide API endpoint `/devices/droidcam_guide`
4. Đảm bảo OpenCV đã cài: `pip list | grep opencv`

## 📚 Resources

- [DroidCam Official Site](https://www.dev47apps.com/)
- [OpenCV Documentation](https://docs.opencv.org/)
- [RTSP Protocol RFC](https://www.rfc-editor.org/rfc/rfc2326)
- [FFmpeg RTSP Guide](https://trac.ffmpeg.org/wiki/StreamingGuide)
