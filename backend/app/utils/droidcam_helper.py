# app/utils/droidcam_helper.py
"""
Utility helper for DroidCam RTSP configuration
Hỗ trợ tạo URL RTSP cho DroidCam và các camera IP khác
"""
import logging
from typing import Optional

logger = logging.getLogger(__name__)


class DroidCamConfig:
    """
    Helper class để tạo URL RTSP cho DroidCam và camera IP
    """
    
    # DroidCam mặc định dùng port 4747 cho HTTP và 8554 cho RTSP
    DEFAULT_HTTP_PORT = 4747
    DEFAULT_RTSP_PORT = 8554
    
    @staticmethod
    def create_rtsp_url(
        ip: str,
        port: Optional[int] = None,
        stream_path: str = "video",
        username: Optional[str] = None,
        password: Optional[str] = None,
        transport: str = "tcp"
    ) -> str:
        """
        Tạo URL RTSP cho DroidCam
        
        Args:
            ip: Địa chỉ IP của thiết bị (ví dụ: "192.168.1.100")
            port: Port RTSP (mặc định 8554 cho DroidCam)
            stream_path: Đường dẫn stream (mặc định "video")
            username: Username nếu cần auth
            password: Password nếu cần auth
            transport: Protocol transport (tcp hoặc udp, mặc định tcp)
            
        Returns:
            URL RTSP đầy đủ
            
        Examples:
            >>> DroidCamConfig.create_rtsp_url("192.168.1.100")
            'rtsp://192.168.1.100:8554/video'
            
            >>> DroidCamConfig.create_rtsp_url("192.168.1.100", username="admin", password="123456")
            'rtsp://admin:123456@192.168.1.100:8554/video'
        """
        if not port:
            port = DroidCamConfig.DEFAULT_RTSP_PORT
        
        # Tạo auth part nếu có
        auth_part = ""
        if username:
            if password:
                auth_part = f"{username}:{password}@"
            else:
                auth_part = f"{username}@"
        
        # Remove leading slash nếu có
        stream_path = stream_path.lstrip("/")
        
        url = f"rtsp://{auth_part}{ip}:{port}/{stream_path}"
        
        # Thêm transport parameter nếu cần
        if transport and transport.lower() != "tcp":
            url += f"?transport={transport}"
        
        logger.info(f"[DroidCam] Created RTSP URL: rtsp://{ip}:{port}/{stream_path}")
        return url
    
    @staticmethod
    def create_http_url(
        ip: str,
        port: Optional[int] = None,
        endpoint: str = "video",
        use_https: bool = False
    ) -> str:
        """
        Tạo URL HTTP cho DroidCam (snapshot mode)
        
        Args:
            ip: Địa chỉ IP của thiết bị
            port: Port HTTP (mặc định 4747)
            endpoint: Endpoint (mặc định "video")
            use_https: Sử dụng HTTPS hay không
            
        Returns:
            URL HTTP/HTTPS đầy đủ
            
        Examples:
            >>> DroidCamConfig.create_http_url("192.168.1.100")
            'http://192.168.1.100:4747/video'
        """
        if not port:
            port = DroidCamConfig.DEFAULT_HTTP_PORT
        
        protocol = "https" if use_https else "http"
        endpoint = endpoint.lstrip("/")
        
        return f"{protocol}://{ip}:{port}/{endpoint}"
    
    @staticmethod
    def validate_rtsp_url(url: str) -> bool:
        """
        Kiểm tra URL RTSP có hợp lệ không
        
        Args:
            url: URL cần kiểm tra
            
        Returns:
            True nếu URL hợp lệ
        """
        if not url:
            return False
        
        url = url.strip()
        
        # Kiểm tra protocol
        if not url.startswith("rtsp://"):
            logger.warning(f"[DroidCam] URL không bắt đầu bằng rtsp://: {url}")
            return False
        
        # Kiểm tra có IP/hostname
        try:
            # Remove protocol
            without_protocol = url.replace("rtsp://", "")
            
            # Remove auth if present
            if "@" in without_protocol:
                without_protocol = without_protocol.split("@", 1)[1]
            
            # Check for host and port
            if ":" not in without_protocol:
                logger.warning(f"[DroidCam] URL không có port: {url}")
                return False
            
            return True
        except Exception as e:
            logger.error(f"[DroidCam] Lỗi validate URL: {e}")
            return False
    
    @staticmethod
    def get_connection_tips() -> dict:
        """
        Trả về các tips để kết nối DroidCam
        
        Returns:
            Dict chứa các tips và troubleshooting
        """
        return {
            "rtsp_setup": [
                "1. Mở DroidCam app trên điện thoại",
                "2. Bật 'Video Source' (camera trước hoặc sau)",
                "3. Chọn 'Start Server'",
                "4. Lấy IP address được hiển thị trên app",
                "5. Sử dụng port 8554 cho RTSP hoặc 4747 cho HTTP"
            ],
            "url_formats": {
                "rtsp": "rtsp://<IP>:8554/video",
                "rtsp_with_auth": "rtsp://<username>:<password>@<IP>:8554/video",
                "http": "http://<IP>:4747/video",
                "mjpeg": "http://<IP>:4747/mjpegfeed"
            },
            "common_issues": {
                "connection_failed": [
                    "Kiểm tra điện thoại và server cùng mạng WiFi",
                    "Tắt firewall hoặc mở port 8554 (RTSP) và 4747 (HTTP)",
                    "Đảm bảo DroidCam app đang chạy và server đã start"
                ],
                "timeout": [
                    "Thử giảm resolution trong DroidCam settings",
                    "Chuyển từ UDP sang TCP (thêm ?transport=tcp vào URL)",
                    "Kiểm tra băng thông mạng"
                ],
                "poor_quality": [
                    "Tăng bitrate trong DroidCam settings",
                    "Đảm bảo ánh sáng tốt",
                    "Giảm FPS nếu mạng chậm"
                ]
            },
            "optimal_settings": {
                "resolution": "720p hoặc 480p (tùy mạng)",
                "fps": "15-30 fps",
                "bitrate": "1-3 Mbps",
                "transport": "TCP (ổn định hơn UDP)"
            }
        }


def print_droidcam_guide():
    """In hướng dẫn sử dụng DroidCam ra console"""
    tips = DroidCamConfig.get_connection_tips()
    
    print("\n" + "="*60)
    print("HƯỚNG DẪN KẾT NỐI DROIDCAM RTSP")
    print("="*60)
    
    print("\n📱 THIẾT LẬP:")
    for tip in tips["rtsp_setup"]:
        print(f"   {tip}")
    
    print("\n🔗 ĐỊNH DẠNG URL:")
    for name, url in tips["url_formats"].items():
        print(f"   {name:20s}: {url}")
    
    print("\n⚙️  CÀI ĐẶT TỐI ƯU:")
    for key, value in tips["optimal_settings"].items():
        print(f"   {key.capitalize():20s}: {value}")
    
    print("\n❌ XỬ LÝ LỖI THƯỜNG GẶP:")
    for issue, solutions in tips["common_issues"].items():
        print(f"\n   {issue.replace('_', ' ').title()}:")
        for solution in solutions:
            print(f"      - {solution}")
    
    print("\n" + "="*60 + "\n")


# Example usage
if __name__ == "__main__":
    # In hướng dẫn
    print_droidcam_guide()
    
    # Ví dụ tạo URL
    print("\nVÍ DỤ TẠO URL:")
    print("-" * 60)
    
    # RTSP cơ bản
    url1 = DroidCamConfig.create_rtsp_url("192.168.1.100")
    print(f"RTSP cơ bản: {url1}")
    
    # RTSP có auth
    url2 = DroidCamConfig.create_rtsp_url(
        "192.168.1.100",
        username="admin",
        password="123456"
    )
    print(f"RTSP có auth: {url2}")
    
    # RTSP với UDP
    url3 = DroidCamConfig.create_rtsp_url(
        "192.168.1.100",
        transport="udp"
    )
    print(f"RTSP UDP: {url3}")
    
    # HTTP
    url4 = DroidCamConfig.create_http_url("192.168.1.100")
    print(f"HTTP: {url4}")
    
    # Validate
    print(f"\nValidate URL1: {DroidCamConfig.validate_rtsp_url(url1)}")
    print(f"Validate invalid: {DroidCamConfig.validate_rtsp_url('http://invalid')}")
