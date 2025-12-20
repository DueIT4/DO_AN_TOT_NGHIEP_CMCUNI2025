#!/usr/bin/env python3
"""
Script test nhanh DroidCam RTSP connectivity
Sử dụng để kiểm tra xem DroidCam có hoạt động không trước khi thêm vào hệ thống
"""
import sys
import argparse
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.utils.droidcam_helper import DroidCamConfig, print_droidcam_guide
from app.services.camera_service import capture_image_from_stream


def test_url(url: str, timeout: int = 10, save_image: bool = False):
    """Test stream URL và lưu ảnh nếu thành công"""
    print(f"\n{'='*60}")
    print(f"Testing stream URL: {url}")
    print(f"{'='*60}\n")
    
    # Validate nếu là RTSP
    if url.startswith("rtsp://"):
        if not DroidCamConfig.validate_rtsp_url(url):
            print("❌ URL RTSP không hợp lệ!")
            print("   Format đúng: rtsp://IP:PORT/path")
            print("   Ví dụ: rtsp://192.168.1.100:8554/video")
            return False
        print("✅ URL RTSP format hợp lệ")
    
    # Try capture
    print(f"\n📷 Đang thử kết nối (timeout: {timeout}s)...")
    
    try:
        img_data = capture_image_from_stream(url, timeout=timeout)
        
        if img_data:
            print(f"✅ Thành công! Đã lấy được ảnh ({len(img_data)} bytes)")
            
            if save_image:
                output_path = Path("test_capture.jpg")
                with open(output_path, "wb") as f:
                    f.write(img_data)
                print(f"💾 Đã lưu ảnh test tại: {output_path.absolute()}")
            
            return True
        else:
            print("❌ Không thể lấy ảnh từ stream")
            print("\n🔍 Kiểm tra:")
            print("   1. DroidCam app đang chạy và đã start server?")
            print("   2. Điện thoại và máy tính cùng mạng WiFi?")
            print("   3. IP address đúng chưa?")
            print("   4. Port đúng chưa? (8554 cho RTSP, 4747 cho HTTP)")
            return False
    
    except Exception as e:
        print(f"❌ Lỗi: {str(e)}")
        print("\n🔍 Troubleshooting:")
        print("   - Kiểm tra firewall/antivirus")
        print("   - Thử ping IP để test connectivity")
        print("   - Đảm bảo OpenCV đã cài: pip install opencv-python-headless")
        return False


def create_url_interactive():
    """Tạo URL RTSP interactive"""
    print("\n" + "="*60)
    print("TẠO URL RTSP CHO DROIDCAM")
    print("="*60 + "\n")
    
    # Get IP
    ip = input("Nhập IP address của điện thoại (ví dụ: 192.168.1.100): ").strip()
    if not ip:
        print("❌ IP không được để trống!")
        return None
    
    # Get port
    port_input = input(f"Nhập port (Enter để dùng mặc định 8554): ").strip()
    port = int(port_input) if port_input else 8554
    
    # Get stream path
    path = input("Nhập stream path (Enter để dùng 'video'): ").strip() or "video"
    
    # Auth?
    use_auth = input("Có sử dụng authentication không? (y/N): ").strip().lower() == 'y'
    username = None
    password = None
    
    if use_auth:
        username = input("Username: ").strip()
        password = input("Password: ").strip()
    
    # Transport
    transport_input = input("Transport protocol (tcp/udp, Enter cho tcp): ").strip().lower()
    transport = transport_input if transport_input in ['tcp', 'udp'] else 'tcp'
    
    # Create URL
    url = DroidCamConfig.create_rtsp_url(
        ip=ip,
        port=port,
        stream_path=path,
        username=username if use_auth else None,
        password=password if use_auth else None,
        transport=transport
    )
    
    print(f"\n✅ URL đã tạo: {url}")
    return url


def main():
    parser = argparse.ArgumentParser(
        description="Test DroidCam RTSP connectivity",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Show guide
  python test_droidcam.py --guide
  
  # Test RTSP URL
  python test_droidcam.py --url rtsp://192.168.1.100:8554/video
  
  # Test và lưu ảnh
  python test_droidcam.py --url rtsp://192.168.1.100:8554/video --save
  
  # Interactive mode
  python test_droidcam.py --interactive
  
  # Test HTTP
  python test_droidcam.py --url http://192.168.1.100:4747/video
        """
    )
    
    parser.add_argument(
        "--url",
        help="Stream URL to test (RTSP, HTTP, or HTTPS)"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=10,
        help="Timeout in seconds (default: 10)"
    )
    parser.add_argument(
        "--save",
        action="store_true",
        help="Save captured image to test_capture.jpg"
    )
    parser.add_argument(
        "--guide",
        action="store_true",
        help="Show DroidCam setup guide"
    )
    parser.add_argument(
        "--interactive",
        "-i",
        action="store_true",
        help="Interactive mode to create RTSP URL"
    )
    parser.add_argument(
        "--create-url",
        help="Create RTSP URL from IP (e.g., --create-url 192.168.1.100)"
    )
    
    args = parser.parse_args()
    
    # Show guide
    if args.guide:
        print_droidcam_guide()
        return
    
    # Interactive mode
    if args.interactive:
        url = create_url_interactive()
        if url:
            test_url(url, timeout=args.timeout, save_image=args.save)
        return
    
    # Quick create URL
    if args.create_url:
        url = DroidCamConfig.create_rtsp_url(args.create_url)
        print(f"\n✅ RTSP URL: {url}")
        test_url(url, timeout=args.timeout, save_image=args.save)
        return
    
    # Test URL
    if args.url:
        success = test_url(args.url, timeout=args.timeout, save_image=args.save)
        sys.exit(0 if success else 1)
    
    # No args - show help
    parser.print_help()
    print("\n💡 Tip: Dùng --guide để xem hướng dẫn chi tiết")
    print("💡 Tip: Dùng --interactive để tạo URL theo hướng dẫn")


if __name__ == "__main__":
    main()
