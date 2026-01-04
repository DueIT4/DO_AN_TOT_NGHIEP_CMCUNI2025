"""
HLS Cleanup Service
Tự động xóa các HLS session cũ và ffmpeg processes không còn sử dụng
"""
import shutil
import subprocess
import psutil
from pathlib import Path
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

HLS_OUTPUT_DIR = Path("media/hls")


def cleanup_old_hls_sessions(max_age_hours: int = 1):
    """
    Xóa các HLS session cũ hơn max_age_hours.
    
    Args:
        max_age_hours: Số giờ tối đa giữ session
    
    Returns:
        Number of sessions cleaned up
    """
    if not HLS_OUTPUT_DIR.exists():
        return 0
    
    cleaned_count = 0
    cutoff_time = datetime.now() - timedelta(hours=max_age_hours)
    
    try:
        for session_dir in HLS_OUTPUT_DIR.iterdir():
            if not session_dir.is_dir():
                continue
            
            # Check modification time của playlist file
            playlist_file = session_dir / "index.m3u8"
            
            if playlist_file.exists():
                mod_time = datetime.fromtimestamp(playlist_file.stat().st_mtime)
                if mod_time < cutoff_time:
                    logger.info(f"[HLS Cleanup] Removing old session: {session_dir.name}")
                    shutil.rmtree(session_dir, ignore_errors=True)
                    cleaned_count += 1
            else:
                # Session không có playlist -> có thể là failed session
                # Xóa nếu directory cũ hơn 30 phút
                dir_mod_time = datetime.fromtimestamp(session_dir.stat().st_mtime)
                if dir_mod_time < datetime.now() - timedelta(minutes=30):
                    logger.info(f"[HLS Cleanup] Removing incomplete session: {session_dir.name}")
                    shutil.rmtree(session_dir, ignore_errors=True)
                    cleaned_count += 1
    
    except Exception as e:
        logger.error(f"[HLS Cleanup] Error during cleanup: {e}")
    
    return cleaned_count


def kill_orphaned_ffmpeg_processes():
    """
    Tìm và kill các ffmpeg processes đang chạy mà output directory không còn tồn tại.
    
    Returns:
        Number of processes killed
    """
    killed_count = 0
    
    try:
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                if proc.info['name'] and 'ffmpeg' in proc.info['name'].lower():
                    cmdline = proc.info['cmdline']
                    if not cmdline:
                        continue
                    
                    # Tìm output path trong command line
                    for i, arg in enumerate(cmdline):
                        if str(HLS_OUTPUT_DIR) in arg:
                            # Check if output directory still exists
                            output_path = Path(arg)
                            if output_path.suffix == '.m3u8':
                                output_dir = output_path.parent
                                if not output_dir.exists():
                                    logger.info(
                                        f"[HLS Cleanup] Killing orphaned ffmpeg PID={proc.info['pid']} "
                                        f"(output dir removed: {output_dir.name})"
                                    )
                                    proc.kill()
                                    killed_count += 1
                            break
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                pass
    
    except Exception as e:
        logger.error(f"[HLS Cleanup] Error killing orphaned processes: {e}")
    
    return killed_count


def cleanup_all():
    """
    Chạy tất cả cleanup tasks.
    
    Returns:
        Dictionary with cleanup statistics
    """
    logger.info("[HLS Cleanup] Starting cleanup...")
    
    sessions_cleaned = cleanup_old_hls_sessions(max_age_hours=1)
    processes_killed = kill_orphaned_ffmpeg_processes()
    
    logger.info(
        f"[HLS Cleanup] Finished: {sessions_cleaned} sessions cleaned, "
        f"{processes_killed} processes killed"
    )
    
    return {
        "sessions_cleaned": sessions_cleaned,
        "processes_killed": processes_killed,
        "timestamp": datetime.now().isoformat()
    }


if __name__ == "__main__":
    # Test cleanup
    logging.basicConfig(level=logging.INFO)
    result = cleanup_all()
    print(f"Cleanup result: {result}")
