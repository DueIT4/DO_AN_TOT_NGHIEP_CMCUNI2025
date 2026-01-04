"""
HLS Stream Service with OpenCV support
Hỗ trợ DroidCam và các camera từ xa bằng OpenCV + ffmpeg pipe
"""
import cv2
import subprocess
import threading
import logging
import hashlib
from pathlib import Path
from typing import Optional, Dict
import time

logger = logging.getLogger(__name__)

import tempfile

# On Cloud Run, only /tmp is writable
TEMP_DIR = Path(tempfile.gettempdir())
HLS_OUTPUT_DIR = TEMP_DIR / "hls"
HLS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Global registry to track active streams
_active_streams: Dict[str, Dict] = {}
_streams_lock = threading.Lock()


class OpenCVStreamConverter:
    """
    Convert camera stream to HLS using OpenCV + ffmpeg pipe
    Hỗ trợ DroidCam, IP Webcam và các MJPEG streams từ xa
    """
    
    def __init__(self, stream_url: str, session_id: str, output_dir: Path):
        self.stream_url = stream_url
        self.session_id = session_id
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.playlist_file = output_dir / "index.m3u8"
        self.segment_pattern = str(output_dir / "segment_%03d.ts")
        self.log_file = output_dir / "conversion.log"
        
        self.cap: Optional[cv2.VideoCapture] = None
        self.ffmpeg_process: Optional[subprocess.Popen] = None
        self.thread: Optional[threading.Thread] = None
        self.running = False
        self.error: Optional[str] = None
        
    def start(self):
        """Start conversion in background thread"""
        if self.running:
            logger.warning(f"[OpenCV-HLS] Stream {self.session_id} already running")
            return
        
        self.running = True
        self.thread = threading.Thread(target=self._convert_loop, daemon=True)
        self.thread.start()
        logger.info(f"[OpenCV-HLS] Started converter thread for {self.session_id}")
    
    def stop(self):
        """Stop conversion"""
        logger.info(f"[OpenCV-HLS] Stopping stream {self.session_id}")
        self.running = False
        
        if self.cap:
            self.cap.release()
        
        if self.ffmpeg_process:
            try:
                self.ffmpeg_process.stdin.close()
                self.ffmpeg_process.terminate()
                self.ffmpeg_process.wait(timeout=5)
            except Exception as e:
                logger.error(f"[OpenCV-HLS] Error stopping ffmpeg: {e}")
    
    def _convert_loop(self):
        """Main conversion loop running in background thread"""
        import shutil
        
        try:
            # Find ffmpeg
            ffmpeg_path = shutil.which("ffmpeg")
            
            # Fallback for Windows local dev environment if not in PATH
            if not ffmpeg_path:
                common_paths = [
                    r"D:\ffmpeg\ffmpeg-2025-12-04-git-d6458f6a8b-essentials_build\bin\ffmpeg.exe",
                    r"C:\ffmpeg\bin\ffmpeg.exe",
                ]
                for path in common_paths:
                    import os
                    if os.path.exists(path):
                        ffmpeg_path = path
                        break
            
            if not ffmpeg_path:
                raise FileNotFoundError("ffmpeg not found")
            
            logger.info(f"[OpenCV-HLS] Connecting to stream: {self.stream_url}")
            
            # Open stream with OpenCV
            self.cap = cv2.VideoCapture(self.stream_url)
            
            if not self.cap.isOpened():
                raise RuntimeError(f"Failed to open stream: {self.stream_url}")
            
            # Get stream properties
            fps = int(self.cap.get(cv2.CAP_PROP_FPS))
            if fps <= 0 or fps > 60:
                fps = 25  # Default fallback
            
            width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            
            if width <= 0 or height <= 0:
                # Read first frame to get dimensions
                ret, frame = self.cap.read()
                if ret and frame is not None:
                    height, width = frame.shape[:2]
                    # Put frame back by recreating capture
                    self.cap.release()
                    self.cap = cv2.VideoCapture(self.stream_url)
                else:
                    raise RuntimeError("Cannot determine stream dimensions")
            
            logger.info(f"[OpenCV-HLS] Stream info: {width}x{height} @ {fps}fps")
            
            # Start ffmpeg with pipe input
            ffmpeg_cmd = [
                ffmpeg_path,
                "-y",
                "-f", "rawvideo",
                "-vcodec", "rawvideo",
                "-pix_fmt", "bgr24",
                "-s", f"{width}x{height}",
                "-r", str(fps),
                "-i", "-",  # stdin pipe
                # Video encoding
                "-c:v", "libx264",
                "-preset", "ultrafast",
                "-tune", "zerolatency",
                "-pix_fmt", "yuv420p",
                "-g", str(fps * 2),  # Keyframe every 2 seconds
                "-sc_threshold", "0",
                # HLS output
                "-f", "hls",
                "-hls_time", "2",
                "-hls_list_size", "10",
                "-hls_flags", "delete_segments+append_list",
                "-hls_segment_type", "mpegts",
                "-hls_segment_filename", self.segment_pattern,
                "-start_number", "0",
                str(self.playlist_file),
            ]
            
            logger.info(f"[OpenCV-HLS] Starting ffmpeg pipe...")
            
            log_file_handle = open(self.log_file, "wb")
            
            self.ffmpeg_process = subprocess.Popen(
                ffmpeg_cmd,
                stdin=subprocess.PIPE,
                stdout=log_file_handle,
                stderr=log_file_handle,
            )
            
            logger.info(f"[OpenCV-HLS] ✅ Conversion started, PID={self.ffmpeg_process.pid}")
            
            frame_count = 0
            error_count = 0
            max_errors = 30  # Max 30 consecutive errors
            
            # Main loop: read frames and pipe to ffmpeg
            while self.running:
                ret, frame = self.cap.read()
                
                if not ret or frame is None:
                    error_count += 1
                    logger.warning(f"[OpenCV-HLS] Failed to read frame {frame_count}, errors: {error_count}/{max_errors}")
                    
                    if error_count >= max_errors:
                        logger.error(f"[OpenCV-HLS] Too many errors, stopping stream")
                        break
                    
                    time.sleep(0.1)
                    continue
                
                # Reset error count on successful frame
                error_count = 0
                
                try:
                    # Write frame to ffmpeg stdin
                    self.ffmpeg_process.stdin.write(frame.tobytes())
                    frame_count += 1
                    
                    # Log progress every 100 frames
                    if frame_count % 100 == 0:
                        logger.debug(f"[OpenCV-HLS] Processed {frame_count} frames")
                    
                except (BrokenPipeError, IOError) as e:
                    logger.error(f"[OpenCV-HLS] Pipe error: {e}")
                    break
            
            logger.info(f"[OpenCV-HLS] Conversion loop ended, processed {frame_count} frames")
            
        except Exception as e:
            logger.error(f"[OpenCV-HLS] Conversion error: {e}", exc_info=True)
            self.error = str(e)
        finally:
            self.stop()
            logger.info(f"[OpenCV-HLS] Cleanup completed for {self.session_id}")


def start_opencv_hls_stream(stream_url: str) -> tuple[str, Path]:
    """
    Start HLS conversion using OpenCV + ffmpeg pipe
    
    Returns:
        (session_id, output_dir)
    """
    # Generate session ID
    session_id = hashlib.md5(stream_url.encode()).hexdigest()[:8]
    output_dir = HLS_OUTPUT_DIR / session_id
    
    with _streams_lock:
        # Check if already running
        if session_id in _active_streams:
            converter = _active_streams[session_id]["converter"]
            if converter.running:
                logger.info(f"[OpenCV-HLS] Stream {session_id} already active")
                return session_id, output_dir
        
        # Start new converter
        converter = OpenCVStreamConverter(stream_url, session_id, output_dir)
        converter.start()
        
        _active_streams[session_id] = {
            "converter": converter,
            "stream_url": stream_url,
            "started_at": time.time()
        }
    
    return session_id, output_dir


def stop_opencv_hls_stream(session_id: str):
    """Stop HLS conversion"""
    with _streams_lock:
        if session_id in _active_streams:
            converter = _active_streams[session_id]["converter"]
            converter.stop()
            del _active_streams[session_id]
            logger.info(f"[OpenCV-HLS] Stopped stream {session_id}")


def get_stream_status(session_id: str) -> Optional[Dict]:
    """Get stream status"""
    with _streams_lock:
        if session_id in _active_streams:
            stream_info = _active_streams[session_id]
            converter = stream_info["converter"]
            
            return {
                "session_id": session_id,
                "running": converter.running,
                "error": converter.error,
                "playlist_exists": converter.playlist_file.exists(),
                "stream_url": stream_info["stream_url"],
                "started_at": stream_info["started_at"],
                "uptime": time.time() - stream_info["started_at"]
            }
    
    return None


def cleanup_all_streams():
    """Stop all active streams"""
    with _streams_lock:
        session_ids = list(_active_streams.keys())
        for session_id in session_ids:
            stop_opencv_hls_stream(session_id)
    
    logger.info("[OpenCV-HLS] All streams cleaned up")
