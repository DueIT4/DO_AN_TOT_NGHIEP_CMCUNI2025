#!/usr/bin/env python3
"""
Script test nhanh streaming video real-time
Tạo device và start stream, sau đó tạo HTML page để xem
"""
import sys
import argparse
import requests
import time
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))


def create_device_with_stream(api_base: str, token: str, name: str, stream_url: str) -> int:
    """Tạo device mới với stream URL"""
    print(f"\n{'='*60}")
    print(f"CREATING DEVICE: {name}")
    print(f"{'='*60}\n")
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }
    
    payload = {
        "name": name,
        "device_type_id": 1,
        "stream_url": stream_url,
        "status": "active"
    }
    
    try:
        resp = requests.post(f"{api_base}/api/v1/devices/", json=payload, headers=headers)
        resp.raise_for_status()
        device = resp.json()
        device_id = device.get("device_id")
        
        print(f"✅ Device created successfully!")
        print(f"   Device ID: {device_id}")
        print(f"   Name: {device.get('name')}")
        print(f"   Stream URL: {device.get('stream_url')}")
        
        return device_id
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to create device: {e}")
        if hasattr(e, 'response') and e.response:
            print(f"   Response: {e.response.text}")
        return None


def start_stream(api_base: str, token: str, device_id: int) -> str:
    """Start streaming cho device"""
    print(f"\n{'='*60}")
    print(f"STARTING STREAM FOR DEVICE {device_id}")
    print(f"{'='*60}\n")
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }
    
    payload = {"device_id": device_id}
    
    try:
        resp = requests.post(f"{api_base}/api/v1/streams/start", json=payload, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        
        hls_url = data.get("hls_url")
        full_url = f"{api_base}{hls_url}"
        
        print(f"✅ Stream started successfully!")
        print(f"   HLS URL: {full_url}")
        print(f"   Status: {data.get('message')}")
        
        # Wait a bit for ffmpeg to generate segments
        print(f"\n⏳ Waiting 5 seconds for stream to initialize...")
        time.sleep(5)
        
        return full_url
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to start stream: {e}")
        if hasattr(e, 'response') and e.response:
            print(f"   Response: {e.response.text}")
        return None


def check_stream_health(api_base: str, token: str, device_id: int):
    """Kiểm tra health của stream"""
    print(f"\n{'='*60}")
    print(f"CHECKING STREAM HEALTH")
    print(f"{'='*60}\n")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        resp = requests.get(f"{api_base}/api/v1/streams/health/{device_id}", headers=headers)
        resp.raise_for_status()
        health = resp.json()
        
        if health.get("healthy"):
            print(f"✅ Stream is healthy!")
        else:
            print(f"⚠️  Stream has issues:")
            print(f"   Error: {health.get('error')}")
        
        print(f"\n   Details:")
        print(f"   - Running: {health.get('running')}")
        print(f"   - HLS exists: {health.get('hls_exists')}")
        print(f"   - Last update: {health.get('last_update')} seconds ago")
        
        return health.get("healthy")
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to check health: {e}")
        return False


def generate_html_viewer(hls_url: str, device_name: str, output_path: Path):
    """Tạo HTML page để xem stream"""
    html_content = f"""<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{device_name} - Live Stream</title>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 20px;
        }}
        .container {{
            max-width: 1200px;
            width: 100%;
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 24px;
            text-align: center;
        }}
        .header h1 {{
            font-size: 28px;
            margin-bottom: 8px;
        }}
        .header p {{
            opacity: 0.9;
            font-size: 14px;
        }}
        .video-container {{
            position: relative;
            padding-top: 56.25%; /* 16:9 Aspect Ratio */
            background: #000;
        }}
        video {{
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
        }}
        .controls {{
            padding: 20px;
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            align-items: center;
            background: #f8f9fa;
        }}
        .btn {{
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
        }}
        .btn:hover {{
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }}
        .btn-primary {{
            background: #667eea;
            color: white;
        }}
        .btn-success {{
            background: #28a745;
            color: white;
        }}
        .btn-danger {{
            background: #dc3545;
            color: white;
        }}
        .btn-info {{
            background: #17a2b8;
            color: white;
        }}
        .status {{
            padding: 20px;
            border-top: 1px solid #dee2e6;
        }}
        .status-item {{
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #f0f0f0;
        }}
        .status-item:last-child {{
            border-bottom: none;
        }}
        .status-label {{
            font-weight: 600;
            color: #495057;
        }}
        .status-value {{
            color: #6c757d;
        }}
        .indicator {{
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }}
        .indicator.live {{
            background: #28a745;
            animation: pulse 2s infinite;
        }}
        .indicator.offline {{
            background: #dc3545;
        }}
        @keyframes pulse {{
            0%, 100% {{ opacity: 1; }}
            50% {{ opacity: 0.5; }}
        }}
        .loading {{
            text-align: center;
            padding: 40px;
        }}
        .spinner {{
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 16px;
        }}
        @keyframes spin {{
            0% {{ transform: rotate(0deg); }}
            100% {{ transform: rotate(360deg); }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📹 {device_name}</h1>
            <p>Real-time Live Stream</p>
        </div>

        <div id="loading" class="loading">
            <div class="spinner"></div>
            <p>Đang tải stream...</p>
        </div>

        <div class="video-container" id="videoContainer" style="display: none;">
            <video id="video" controls autoplay muted></video>
        </div>

        <div class="controls">
            <button class="btn btn-primary" onclick="playStream()">▶ Play</button>
            <button class="btn btn-danger" onclick="pauseStream()">⏸ Pause</button>
            <button class="btn btn-info" onclick="reloadStream()">🔄 Reload</button>
            <button class="btn btn-success" onclick="toggleFullscreen()">⛶ Fullscreen</button>
        </div>

        <div class="status">
            <div class="status-item">
                <span class="status-label">
                    <span id="liveIndicator" class="indicator live"></span>
                    Status
                </span>
                <span class="status-value" id="streamStatus">Đang kết nối...</span>
            </div>
            <div class="status-item">
                <span class="status-label">HLS URL</span>
                <span class="status-value">{hls_url}</span>
            </div>
            <div class="status-item">
                <span class="status-label">Buffer</span>
                <span class="status-value" id="bufferInfo">-</span>
            </div>
            <div class="status-item">
                <span class="status-label">Quality</span>
                <span class="status-value" id="qualityInfo">-</span>
            </div>
        </div>
    </div>

    <script>
        const video = document.getElementById('video');
        const hlsUrl = '{hls_url}';
        let hls;

        function initStream() {{
            if (Hls.isSupported()) {{
                hls = new Hls({{
                    enableWorker: true,
                    lowLatencyMode: true,
                    backBufferLength: 10,
                    maxBufferLength: 20,
                    liveSyncDurationCount: 3
                }});

                hls.loadSource(hlsUrl);
                hls.attachMedia(video);

                hls.on(Hls.Events.MANIFEST_PARSED, function() {{
                    console.log('Stream manifest loaded');
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('videoContainer').style.display = 'block';
                    document.getElementById('streamStatus').textContent = 'Live';
                    video.play();
                }});

                hls.on(Hls.Events.ERROR, function(event, data) {{
                    console.error('HLS Error:', data);
                    document.getElementById('streamStatus').textContent = 'Error: ' + data.type;
                    document.getElementById('liveIndicator').classList.remove('live');
                    document.getElementById('liveIndicator').classList.add('offline');
                }});

                hls.on(Hls.Events.FRAG_LOADED, function(event, data) {{
                    const buffer = video.buffered;
                    if (buffer.length > 0) {{
                        const buffered = buffer.end(0) - video.currentTime;
                        document.getElementById('bufferInfo').textContent = buffered.toFixed(1) + 's';
                    }}
                }});

                hls.on(Hls.Events.LEVEL_LOADED, function(event, data) {{
                    document.getElementById('qualityInfo').textContent = 
                        data.details.totalduration.toFixed(0) + 's / ' +
                        data.details.fragments.length + ' segments';
                }});
            }}
            else if (video.canPlayType('application/vnd.apple.mpegurl')) {{
                // Native HLS support (Safari)
                video.src = hlsUrl;
                video.addEventListener('loadedmetadata', function() {{
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('videoContainer').style.display = 'block';
                    document.getElementById('streamStatus').textContent = 'Live (Native)';
                    video.play();
                }});
            }}
            else {{
                alert('Your browser does not support HLS streaming!');
            }}
        }}

        function playStream() {{
            video.play();
            document.getElementById('streamStatus').textContent = 'Live';
            document.getElementById('liveIndicator').classList.add('live');
            document.getElementById('liveIndicator').classList.remove('offline');
        }}

        function pauseStream() {{
            video.pause();
            document.getElementById('streamStatus').textContent = 'Paused';
            document.getElementById('liveIndicator').classList.remove('live');
            document.getElementById('liveIndicator').classList.add('offline');
        }}

        function reloadStream() {{
            if (hls) {{
                hls.destroy();
            }}
            document.getElementById('loading').style.display = 'block';
            document.getElementById('videoContainer').style.display = 'none';
            setTimeout(initStream, 500);
        }}

        function toggleFullscreen() {{
            if (!document.fullscreenElement) {{
                video.requestFullscreen();
            }} else {{
                document.exitFullscreen();
            }}
        }}

        // Auto-initialize
        window.addEventListener('load', initStream);
    </script>
</body>
</html>
"""
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    
    print(f"\n✅ HTML viewer created: {output_path.absolute()}")
    print(f"   Open this file in your browser to watch the stream!")


def main():
    parser = argparse.ArgumentParser(
        description="Test streaming video real-time từ DroidCam",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Test với token và stream URL
  python test_streaming.py \\
    --token YOUR_JWT_TOKEN \\
    --url http://192.168.1.6:4747/video \\
    --name "DroidCam Test"
  
  # Chỉ tạo HTML viewer (nếu đã có device và stream)
  python test_streaming.py \\
    --html-only \\
    --hls-url http://localhost:8000/media/hls/123/index.m3u8
        """
    )
    
    parser.add_argument("--api-base", default="http://localhost:8000", help="API base URL")
    parser.add_argument("--token", help="JWT authentication token")
    parser.add_argument("--url", help="Camera stream URL (HTTP, RTSP, MJPEG)")
    parser.add_argument("--name", default="DroidCam Live", help="Device name")
    parser.add_argument("--device-id", type=int, help="Existing device ID (skip creation)")
    parser.add_argument("--html-only", action="store_true", help="Only generate HTML viewer")
    parser.add_argument("--hls-url", help="HLS URL for HTML viewer (with --html-only)")
    parser.add_argument("--output", default="stream_viewer.html", help="Output HTML file")
    
    args = parser.parse_args()
    
    # HTML only mode
    if args.html_only:
        if not args.hls_url:
            print("❌ --hls-url is required with --html-only")
            sys.exit(1)
        
        output_path = Path(args.output)
        generate_html_viewer(args.hls_url, args.name, output_path)
        print(f"\n🎉 Done! Open {output_path.name} in your browser.")
        return
    
    # Full test mode
    if not args.token:
        print("❌ --token is required")
        sys.exit(1)
    
    if not args.url and not args.device_id:
        print("❌ Either --url or --device-id is required")
        sys.exit(1)
    
    # Create device if needed
    device_id = args.device_id
    if not device_id:
        device_id = create_device_with_stream(args.api_base, args.token, args.name, args.url)
        if not device_id:
            print("\n❌ Failed to create device. Exiting.")
            sys.exit(1)
    
    # Start stream
    hls_url = start_stream(args.api_base, args.token, device_id)
    if not hls_url:
        print("\n❌ Failed to start stream. Exiting.")
        sys.exit(1)
    
    # Check health
    healthy = check_stream_health(args.api_base, args.token, device_id)
    
    # Generate HTML viewer
    output_path = Path(args.output)
    generate_html_viewer(hls_url, args.name, output_path)
    
    print(f"\n{'='*60}")
    print("🎉 STREAMING TEST COMPLETE!")
    print(f"{'='*60}")
    print(f"\n📋 Summary:")
    print(f"   Device ID: {device_id}")
    print(f"   HLS URL: {hls_url}")
    print(f"   Health: {'✅ Healthy' if healthy else '⚠️  Issues detected'}")
    print(f"   HTML Viewer: {output_path.absolute()}")
    print(f"\n🚀 Next Steps:")
    print(f"   1. Open {output_path.name} in your browser")
    print(f"   2. Click 'Play' button if video doesn't auto-play")
    print(f"   3. Enjoy your live stream!")
    print(f"\n💡 Tips:")
    print(f"   - Stream có độ trễ ~4-6 giây (HLS latency)")
    print(f"   - Nếu không thấy video, check ffmpeg log tại: media/hls/{device_id}/ffmpeg.log")
    print(f"   - Để dừng stream: POST /api/v1/streams/stop với device_id={device_id}")


if __name__ == "__main__":
    main()
