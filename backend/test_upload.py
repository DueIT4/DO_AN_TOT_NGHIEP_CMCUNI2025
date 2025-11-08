"""
Script test API upload ảnh
Sử dụng: python test_upload.py <đường_dẫn_ảnh>
"""
import sys
import requests
from pathlib import Path

API_BASE = "http://localhost:8000"
UPLOAD_ENDPOINT = f"{API_BASE}/api/v1/detect/upload"

def test_upload(image_path: str):
    """Test upload ảnh lên API."""
    image_path = Path(image_path)
    
    if not image_path.exists():
        print(f"❌ File không tồn tại: {image_path}")
        return
    
    if not image_path.suffix.lower() in [".jpg", ".jpeg", ".png", ".webp"]:
        print(f"❌ File không phải ảnh: {image_path}")
        return
    
    print(f"📤 Đang upload ảnh: {image_path}")
    
    try:
        with open(image_path, "rb") as f:
            files = {"image": (image_path.name, f, "image/jpeg")}
            response = requests.post(UPLOAD_ENDPOINT, files=files, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print("\n✅ Upload thành công!")
            print(f"📋 Kết quả:")
            print(f"   - Bệnh: {result.get('disease', 'N/A')}")
            print(f"   - Độ chính xác: {result.get('confidence', 0)*100:.2f}%")
            print(f"   - ID ảnh: {result.get('img_id', 'N/A')}")
            print(f"   - ID detection: {result.get('detection_id', 'N/A')}")
            print(f"\n📝 Giải thích:")
            print(f"   {result.get('explanation', 'N/A')[:200]}...")
        else:
            print(f"\n❌ Lỗi: {response.status_code}")
            print(f"   Chi tiết: {response.text}")
    
    except requests.exceptions.ConnectionError:
        print(f"❌ Không thể kết nối đến server tại {API_BASE}")
        print("   Hãy đảm bảo server đang chạy: uvicorn app.main:app --reload")
    except Exception as e:
        print(f"❌ Lỗi: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Sử dụng: python test_upload.py <đường_dẫn_ảnh>")
        print("Ví dụ: python test_upload.py ../test_images/pomelo_leaf.jpg")
        sys.exit(1)
    
    test_upload(sys.argv[1])

