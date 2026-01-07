# 🎬 Luồng Hoạt Động Phân Tích Bệnh Cây (Chi Tiết Theo Người Dùng - Hệ Thống - AI)

---

## 📱 LUỒNG 1: PHÂN TÍCH BỆNH TỪ TẢI ẢNH (Upload Detection Flow)

### **Sơ Đồ Hoạt Động:**

| Bước | 👤 Người Dùng | 🖥️ Hệ Thống | 🤖 AI |
|------|---|---|---|
| **1** | Mở ứng dụng | Kiểm tra xác thực người dùng. Nếu chưa đăng nhập → Yêu cầu đăng nhập. Nếu đã đăng nhập → Cho phép tiếp tục | - |
| **2** | Chọn "Phân Tích Ảnh" từ menu | Hiển thị giao diện tải ảnh với nút "Chọn ảnh" hoặc "Chụp ảnh" | - |
| **3** | Chọn ảnh từ thư viện hoặc chụp ảnh | Đọc dữ liệu file ảnh. Kiểm tra file không rỗng, định dạng hợp lệ (JPEG/PNG), kích thước < 10MB | - |
| **4** | Nhấn nút "Phân Tích" | Hiển thị loading spinner | - |
| **5** | Chờ kết quả | Upload ảnh lên cloud storage. Chuẩn bị dữ liệu cho AI xử lý | **YOLO nhận diện bệnh**: Phân tích ảnh, trích xuất các đối tượng bệnh (tên bệnh, độ tin cậy, vị trí) |
| **6** | - | - | **Gemini xác minh ảnh**: Kiểm tra xem ảnh có phải cây trồng không. Nếu không phải cây và độ tin cậy của YOLO dưới 98% → Hủy kết quả YOLO |
| **7** | - | Kiểm tra độ tin cậy của kết quả. Nếu < 0.4 → Thông báo "Ảnh không rõ, chụp lại". Nếu ≥ 0.4 → Gọi LLM để tóm tắt | **LLM tóm tắt**: Mô tả chi tiết bệnh phát hiện được và đưa ra hướng dẫn chăm sóc |
| **8** | - | Lưu kết quả vào cơ sở dữ liệu (nếu user đăng nhập): Lưu ảnh, lưu thông tin bệnh phát hiện, đánh dấu cần xem xét | - |
| **9** | Xem kết quả trên màn hình | Trả lại kết quả phân tích cho ứng dụng | - |
| **10** | Đọc tóm tắt bệnh và hướng dẫn | Hiển thị: ảnh đã upload, tên bệnh, độ tin cậy, mô tả bệnh, hướng dẫn chăm sóc, nút lưu/chia sẻ | - |
| **11** | Có thể chia sẻ, lưu lịch sử hoặc phân tích ảnh khác | Xử lý các hành động của user: lưu, chia sẻ, cập nhật lịch sử | - |

### **Các Quyết Định Chính:**

- **File upload hợp lệ?** Nếu không → Hiển thị lỗi
- **Upload ảnh thành công?** Nếu không → Hiển thị lỗi
- **YOLO phát hiện bệnh?** Nếu không → Thông báo "Không phát hiện bệnh"
- **Gemini xác minh ảnh là cây?** Nếu không (và YOLO < 98%) → Hủy kết quả
- **Độ tin cậy đủ cao (≥ 0.4)?** Nếu không → Thông báo "Ảnh không rõ". Nếu có → Gọi LLM
- **LLM xử lý thành công?** Nếu không → Hiển thị lỗi. Nếu có → Hiển thị kết quả

---

## 📷 LUỒNG 2: CHỤP ẢNH TỪ CAMERA & PHÂN TÍCH (Camera Capture Flow)

### **Sơ Đồ Hoạt Động:**

| Bước | 👤 Người Dùng | 🖥️ Hệ Thống | 🤖 AI |
|------|---|---|---|
| **1** | Mở ứng dụng → Vào trang "Quản Lý Thiết Bị" | Kiểm tra xác thực. Tải danh sách các camera/thiết bị của người dùng | - |
| **2** | Xem danh sách camera của mình | Hiển thị: tên thiết bị, vị trí, trạng thái (online/offline), nút "Chụp ảnh phân tích" | - |
| **3** | Chọn thiết bị → Nhấn "Chụp Ảnh" | Gửi yêu cầu tới server, hiển thị loading | - |
| **4** | Chờ | Lấy thông tin thiết bị: địa chỉ stream, cấu hình kết nối | - |
| **5** | - | Kết nối tới camera để lấy ảnh hiện tại. Hỗ trợ nhiều kiểu stream: HTTP snapshot, MJPEG (video), RTSP. Timeout 10 giây. Nếu kết nối thất bại → Hiển thị lỗi | - |
| **6** | - | Nếu lấy ảnh thất bại → Thông báo "Không kết nối được camera". Nếu thành công → Tiếp tục | - |
| **7** | - | Upload ảnh lên cloud storage | - |
| **8** | - | - | **YOLO nhận diện**: Phân tích ảnh từ camera, phát hiện bệnh |
| **9** | - | - | **Gemini xác minh**: Kiểm tra ảnh có phải cây không |
| **10** | - | Kiểm tra độ tin cậy. Nếu < 0.4 → Thông báo. Nếu ≥ 0.4 → Gọi LLM | **LLM tóm tắt**: Mô tả bệnh và hướng dẫn chăm sóc |
| **11** | - | Lưu vào cơ sở dữ liệu: ảnh, thông tin bệnh, tạo thông báo cho người dùng | - |
| **12** | Xem kết quả trên màn hình | Hiển thị: ảnh từ camera, tên bệnh, độ tin cậy, mô tả bệnh, hướng dẫn chăm sóc | - |
| **13** | Nhận thông báo trên điện thoại (nếu phát hiện bệnh) | Gửi thông báo push tới điện thoại người dùng | - |
| **14** | Có thể chia sẻ kết quả, chụp thêm | Xử lý các hành động của user | - |

### **Hỗ Trợ Các Loại Camera:**

- **HTTP Snapshot**: Lấy ảnh tĩnh trực tiếp qua HTTP
- **MJPEG Stream**: Lấy frame từ video stream
- **RTSP Stream**: Sử dụng OpenCV để kết nối và lấy frame
- **HLS Playlist**: Lấy frame từ file video segment

---

## ⏰ LUỒNG 3: PHÂN TÍCH TỰ ĐỘNG ĐỊNH KỲ (Auto Detection Scheduled Flow)

### **Sơ Đồ Hoạt Động:**

| Bước | 👤 Người Dùng | 🖥️ Hệ Thống | 🤖 AI |
|------|---|---|---|
| **1** | (Không làm gì)<br/>Có thể đang ngủ hoặc sử dụng ứng dụng khác | Scheduler chạy tự động (mỗi 1-4 giờ) để phân tích camera | - |
| **2** | - | Tìm tất cả các thiết bị camera được bật chế độ "Phân tích tự động" | - |
| **3** | - | Cho mỗi thiết bị: Lấy thông tin thiết bị (tên, vị trí, địa chỉ stream) | - |
| **4** | - | Lấy ảnh hiện tại từ camera (giống như Camera Capture Flow) | - |
| **5** | - | Upload ảnh lên cloud storage | - |
| **6** | - | - | **YOLO phát hiện bệnh** từ ảnh |
| **7** | - | - | **Gemini xác minh** ảnh có phải cây không |
| **8** | - | Phân tích dữ liệu cảm biến trong 24 giờ gần nhất (nếu có): độ ẩm đất, nhiệt độ, độ ẩm không khí, v.v. Tính trung bình, thấp nhất, cao nhất của từng chỉ số | - |
| **9** | - | Xem lại lịch sử bệnh trong 7 ngày: bệnh nào xuất hiện lần, xu hướng tăng hay giảm, độ tin cậy trung bình | - |
| **10** | - | Kết hợp tất cả thông tin: thiết bị, cảm biến, lịch sử bệnh, kết quả YOLO hiện tại → Chuẩn bị thông tin chi tiết cho AI | - |
| **11** | - | - | **LLM phân tích nâng cao**: Dùng tất cả context (cảm biến + lịch sử bệnh) để đưa ra tư vấn cụ thể cho thiết bị này. Xác định mức độ cần thiết (thường thường hay khẩn cấp) |
| **12** | - | Lưu kết quả vào cơ sở dữ liệu: ảnh, bệnh phát hiện, dữ liệu cảm biến, ghi log sự kiện | - |
| **13** | - | Nếu phát hiện bệnh mới hoặc xu hướng tăng → Tạo thông báo, đánh dấu mức độ ưu tiên (khẩn cấp hoặc bình thường) | - |
| **14** | - | Gửi thông báo push tới điện thoại người dùng | - |
| **15** | 📲 Nhận thông báo trên điện thoại:<br/>"🚨 Vườn cây bưởi A: Phát hiện sâu vẽ bùa (87%)"<br/><br/>Có thể nhấn vào xem chi tiết | Hệ thống ghi nhận thông báo đã được gửi | - |
| **16** | (Tuỳ chọn)<br/>Mở ứng dụng → Xem "Phát hiện gần đây" → Xem chi tiết bệnh, dữ liệu cảm biến, xu hướng bệnh | Hiển thị giao diện: ảnh tự động chụp, bệnh phát hiện, dữ liệu cảm biến (nếu có), biểu đồ xu hướng | - |
| **17** | - | Hệ thống tiếp tục chờ cho lần chạy tự động kế tiếp | - |

### **Thông Tin Tăng Cường Cho LLM:**

Khi AI phân tích, nó được cung cấp toàn bộ context:
- **Thông tin thiết bị**: Tên vườn, vị trí, thời gian hiện tại
- **Dữ liệu cảm biến 24h**: Độ ẩm đất trung bình, nhiệt độ, độ ẩm không khí, v.v. (min, max, avg)
- **Lịch sử bệnh 7 ngày**: Bệnh nào xuất hiện mấy lần, xu hướng tăng hay giảm, độ tin cậy trung bình
- **Kết quả YOLO hiện tại**: Bệnh phát hiện được, độ tin cậy

Nhờ đó, LLM có thể đưa ra tư vấn chuyên sâu hơn, không chỉ là mô tả bệnh mà còn phân tích nguyên nhân và dự báo tương lai.

---

## 🔄 SO SÁNH 3 LUỒNG

| Tiêu Chí | 📱 Upload | 📷 Camera Capture | ⏰ Auto Detect |
|----------|---|---|---|
| **Người kích hoạt** | Người dùng | Người dùng | Hệ thống tự động |
| **Tần suất** | Khi cần | Khi cần | Mỗi 1-4 giờ |
| **Nguồn ảnh** | Thư viện điện thoại/chụp từ điện thoại | Lấy từ camera trong khu vườn | Lấy từ camera trong khu vườn |
| **Cần đăng nhập?** | Không bắt buộc | Có | Có (nhưng không cần user thao tác) |
| **Lưu vào DB?** | Có (nếu đăng nhập) | Có | Có |
| **Tạo thông báo?** | Không | Có | Có |
| **AI dùng context gì?** | Chỉ ảnh và kết quả nhận diện | Ảnh + thông tin thiết bị | Ảnh + dữ liệu cảm biến + lịch sử bệnh |
| **Có dữ liệu cảm biến?** | Không | Không | Có (24h gần nhất) |
| **Gửi push notification?** | Không | Không (chỉ show trên app) | Có (gửi lên điện thoại) |
| **Được dùng khi nào?** | Người dùng muốn kiểm tra nhanh | Kiểm tra chi tiết khu vực cụ thể | Giám sát liên tục, theo dõi tự động |

---

## 📊 LUỒNG DỮ LIỆU CHÍNH

### **Upload Flow (Tải ảnh):**
```
Người dùng chọn ảnh
    ↓
Upload ảnh lên cloud
    ↓
YOLO phát hiện bệnh
    ↓
Gemini xác minh ảnh hợp lệ
    ↓
LLM tóm tắt bệnh & hướng dẫn
    ↓
Lưu vào DB (nếu đăng nhập)
    ↓
Hiển thị kết quả cho người dùng
```

### **Camera Capture Flow (Chụp từ camera):**
```
Người dùng chọn thiết bị
    ↓
Lấy ảnh từ camera trong khu vườn
    ↓
Upload ảnh lên cloud
    ↓
YOLO + Gemini + LLM (giống Upload)
    ↓
Lưu vào DB
    ↓
Tạo thông báo
    ↓
Hiển thị kết quả + gửi thông báo
```

### **Auto Detection Flow (Phân tích tự động):**
```
Scheduler chạy định kỳ
    ↓
Cho mỗi thiết bị có auto-detect bật:
  ├─ Lấy ảnh từ camera
  ├─ Upload lên cloud
  ├─ YOLO + Gemini + LLM
  ├─ Lấy dữ liệu cảm biến (24h)
  ├─ Lấy lịch sử bệnh (7 ngày)
  ├─ LLM phân tích toàn bộ context
  ├─ Lưu vào DB
  ├─ Tạo thông báo
  └─ Gửi push notification
```

---

## 🛑 NHỮNG QUYẾT ĐỊNH QUAN TRỌNG

### **Upload Flow:**
1. **File ảnh hợp lệ?** → Nếu không → Lỗi
2. **Upload thành công?** → Nếu không → Lỗi
3. **YOLO phát hiện bệnh?** → Nếu không → "Không phát hiện bệnh"
4. **Gemini xác nhận ảnh là cây?** → Nếu không (và YOLO < 98%) → Hủy kết quả
5. **Độ tin cậy ≥ 0.4?** → Nếu không → "Ảnh không rõ". Nếu có → Gọi LLM
6. **LLM phân tích xong?** → Nếu không → Lỗi. Nếu có → Hiển thị kết quả

### **Camera Capture Flow:**
1. **User đã đăng nhập?** → Nếu không → Lỗi
2. **Thiết bị tồn tại & thuộc về user?** → Nếu không → Lỗi
3. **Kết nối được camera?** → Nếu không → Lỗi "Camera không available"
4. **Lấy được frame ảnh?** → Nếu không → Lỗi
5. **YOLO + Gemini + LLM** (giống Upload)
6. **Phát hiện bệnh?** → Nếu có → Tạo thông báo mức độ cao. Nếu không → Tạo thông báo mức độ thấp
7. **Lưu vào DB & hiển thị**

### **Auto Detection Flow:**
1. **Đến lúc chạy?** → Nếu chưa → Chờ
2. **Có thiết bị nào có auto-detect bật?** → Nếu không → Dừng
3. **Cho mỗi thiết bị:**
   - Lấy ảnh → Nếu lỗi → Skip thiết bị này, sang thiết bị khác
   - YOLO + Gemini + LLM (giống trên)
   - Lấy dữ liệu cảm biến & lịch sử bệnh
   - LLM phân tích toàn bộ context
   - Lưu vào DB
   - **Xu hướng bệnh tăng?** → Ưu tiên KHẨN CẤP. Nếu ổn định → Ưu tiên BÌNH THƯỜNG
   - Tạo thông báo + gửi push

---

## 📱 GIAO DIỆN NGƯỜI DÙNG

### **Upload Detection UI:**
```
[Trang chính]
├─ Tab: Phân tích | Lịch sử | Cài đặt
├─ Tab "Phân tích":
│  ├─ Nút camera, nút chọn ảnh
│  ├─ Hiển thị ảnh đã chọn
│  ├─ Nút "PHÂN TÍCH"
│  └─ Loading spinner
│
└─ Màn hình kết quả:
   ├─ Ảnh với vùng phát hiện được khoanh
   ├─ Tên bệnh + Độ tin cậy (%)
   ├─ Mô tả bệnh (có thể mở rộng)
   ├─ Hướng dẫn chăm sóc (có thể mở rộng)
   └─ Nút Lưu, Chia sẻ, Phân tích lại
```

### **Camera Capture UI:**
```
[Danh sách thiết bị]
├─ Cho mỗi thiết bị:
│  ├─ Ảnh thumbnail
│  ├─ Tên thiết bị + vị trí
│  ├─ Trạng thái (online/offline)
│  ├─ Lần phát hiện gần nhất (nếu có)
│  └─ Nút "Chụp ảnh phân tích"
│
└─ Sau khi chụp:
   ├─ Hiển thị ảnh
   ├─ Tên bệnh + Độ tin cậy
   ├─ Mô tả bệnh & hướng dẫn
   ├─ Dữ liệu cảm biến (nếu có)
   └─ Nút Lưu, Chia sẻ
```

### **Thông báo:**
```
[Trên điện thoại]
┌─────────────────────────┐
│ 🚨 Cảnh báo bệnh cây    │
│ Vườn cây bưởi A         │
│ Phát hiện: Sâu vẽ bùa   │
│ Độ tin cậy: 87%        │
│ Ưu tiên: KHẨN CẤP      │
│ [Xem chi tiết] [Tắt]   │
└─────────────────────────┘

[Trong app - Trang Lịch sử]
├─ Bộ lọc: Tất cả | Hôm nay | Tuần | Tháng
├─ Cho mỗi phát hiện:
│  ├─ Ảnh thumbnail
│  ├─ Tên bệnh + ngày
│  ├─ Độ tin cậy
│  └─ [Xem chi tiết]
```

---

## ✅ TÓM TẮT NHANH

**Upload**: Người dùng tải ảnh → Hệ thống phân tích → AI nhận diện → Hiển thị kết quả

**Camera Capture**: Người dùng chọn thiết bị → Hệ thống lấy ảnh từ camera → AI phân tích → Lưu & gửi thông báo

**Auto Detection**: Hệ thống tự động chạy định kỳ → Phân tích tất cả thiết bị → Dùng dữ liệu cảm biến + lịch sử bệnh → LLM đưa tư vấn chuyên sâu → Gửi thông báo ưu tiên

**AI Component**:
- **YOLO**: Phát hiện bệnh từ ảnh (đến độ tin cậy bao nhiêu %)
- **Gemini (Verification)**: Kiểm tra ảnh có phải cây không (tránh nhận nhầm logo, hình vẽ)
- **Gemini (LLM)**: Tóm tắt, mô tả bệnh, hướng dẫn chăm sóc (có hoặc không có context từ cảm biến)

**Database**: Tất cả 3 luồng đều lưu: Ảnh + Bệnh phát hiện + Thông báo (nếu có)

---

