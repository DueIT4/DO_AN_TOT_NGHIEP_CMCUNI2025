# Quick Start: Sử Dụng DroidCam với Hệ Thống

## 🎯 Mục Đích
Hướng dẫn nhanh để kết nối DroidCam (điện thoại làm webcam) với hệ thống phát hiện bệnh.

## ⚡ Quick Steps (5 phút)

### 1. Cài DroidCam trên điện thoại
- Android: Tải từ Play Store
- iOS: Tải từ App Store

### 2. Kết nối cùng mạng WiFi
- Đảm bảo điện thoại và server cùng một WiFi

### 3. Start DroidCam Server
- Mở app → Nhấn "Start Server"
- Ghi lại IP (ví dụ: `192.168.1.100`)

### 4. Tạo URL RTSP
```
rtsp://192.168.1.100:8554/video
```
Thay `192.168.1.100` bằng IP của bạn

### 5. Test URL
```bash
# Option 1: Dùng script test
cd backend
python test_droidcam.py --url rtsp://192.168.1.100:8554/video --save

# Option 2: Dùng API
curl -X POST http://localhost:8000/api/v1/devices/test_stream_url \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"stream_url": "rtsp://192.168.1.100:8554/video"}'
```

### 6. Thêm vào hệ thống
```bash
# Qua API
curl -X POST http://localhost:8000/api/v1/devices/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "name": "DroidCam Phòng Khách",
    "device_type_id": 1,
    "stream_url": "rtsp://192.168.1.100:8554/video",
    "status": "active"
  }'
```

## 🛠️ Cài Đặt Dependencies

```bash
# Đảm bảo OpenCV đã cài
pip install opencv-python-headless numpy

# Hoặc cài tất cả dependencies
pip install -r requirements.txt
```

## 🔍 Troubleshooting Nhanh

| Lỗi | Giải Pháp |
|-----|-----------|
| Cannot connect | Kiểm tra cùng WiFi, restart DroidCam |
| Timeout | Giảm resolution trong DroidCam settings |
| Poor quality | Tăng bitrate, cải thiện ánh sáng |
| Port blocked | Mở port 8554 trong firewall |

## 📱 DroidCam Settings Khuyến Nghị

```
Resolution: 720p
FPS: 30
Bitrate: 2 Mbps
Transport: TCP
Camera: Rear (chất lượng tốt hơn)
```

## 🎥 Alternative URLs

```bash
# RTSP (khuyên dùng)
rtsp://192.168.1.100:8554/video

# HTTP video
http://192.168.1.100:4747/video

# MJPEG stream
http://192.168.1.100:4747/mjpegfeed

# Snapshot only
http://192.168.1.100:4747/snapshot.jpg
```

## 💡 Tips

1. **Giữ sạc điện thoại** - DroidCam tốn pin
2. **Sử dụng giá đỡ** - Camera ổn định hơn
3. **Ánh sáng tốt** - Quan trọng cho chất lượng
4. **Tắt sleep** - Không để điện thoại khóa màn hình
5. **Test trước** - Luôn test URL trước khi lưu vào DB

## 📚 Xem Thêm

- [Hướng dẫn chi tiết](DROIDCAM_SETUP.md)
- [API Documentation](api_contract_v1.md)
- Test script: `backend/test_droidcam.py`
- Helper utils: `backend/app/utils/droidcam_helper.py`

## 🆘 Cần Giúp Đỡ?

```bash
# Xem hướng dẫn trong script
python backend/test_droidcam.py --guide

# Interactive mode
python backend/test_droidcam.py --interactive

# Xem hướng dẫn qua API
curl http://localhost:8000/api/v1/devices/droidcam_guide \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## ✅ Checklist

- [ ] DroidCam app đã cài trên điện thoại
- [ ] Cùng mạng WiFi với server
- [ ] OpenCV đã cài trên server (`pip install opencv-python-headless`)
- [ ] DroidCam server đã start
- [ ] IP address đã lấy
- [ ] URL đã test thành công
- [ ] Device đã tạo trong hệ thống
- [ ] Stream đang hoạt động

---

**Ready to go!** 🚀 Bây giờ bạn có thể sử dụng điện thoại làm camera phát hiện bệnh!
