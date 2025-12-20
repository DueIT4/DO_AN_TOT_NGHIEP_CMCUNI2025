"""
Script test API /api/v1/streams/start
Chạy: python test_streams_api.py
"""
import requests
import json

BASE_URL = "http://localhost:8000"
DEVICE_ID = 19

def test_start_stream():
    url = f"{BASE_URL}/api/v1/streams/start"
    payload = {"device_id": DEVICE_ID}
    
    print(f"🔄 Testing POST {url}")
    print(f"📦 Payload: {payload}")
    
    try:
        response = requests.post(
            url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"\n✅ Status Code: {response.status_code}")
        print(f"📄 Response:")
        print(json.dumps(response.json(), indent=2, ensure_ascii=False))
        
        return response.status_code == 200
        
    except requests.exceptions.RequestException as e:
        print(f"\n❌ Error: {e}")
        return False

def test_get_stream_status():
    url = f"{BASE_URL}/api/v1/streams/device/{DEVICE_ID}"
    
    print(f"\n🔄 Testing GET {url}")
    
    try:
        response = requests.get(url, timeout=10)
        
        print(f"✅ Status Code: {response.status_code}")
        print(f"📄 Response:")
        print(json.dumps(response.json(), indent=2, ensure_ascii=False))
        
        return response.status_code == 200
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    print("=" * 60)
    print("🧪 TESTING STREAMS API")
    print("=" * 60)
    
    # Test 1: Start stream
    success1 = test_start_stream()
    
    # Test 2: Get stream status
    success2 = test_get_stream_status()
    
    print("\n" + "=" * 60)
    if success1 and success2:
        print("✅ TẤT CẢ TEST THÀNH CÔNG!")
    else:
        print("❌ CÓ TEST THẤT BẠI!")
    print("=" * 60)
