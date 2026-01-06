import cloudinary
import cloudinary.uploader
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Cấu hình Cloudinary
cloudinary.config(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET,
    secure=True
)

def upload_image_to_cloudinary(raw_bytes: bytes, folder: str = "zestguard/general") -> str:
    """Dành cho ảnh (Avatar, Detection)"""
    import time
    max_retries = 3
    for attempt in range(max_retries):
        try:
            response = cloudinary.uploader.upload(
                raw_bytes,
                folder=folder, #
                resource_type="image" #
            )
            return response.get("secure_url")
        except Exception as e:
            logger.warning(f"⚠️ Cloudinary Upload Failed (Attempt {attempt+1}/{max_retries}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2)  # Wait 2 seconds before retry
            else:
                logger.error(f"❌ Cloudinary Image Upload Error after {max_retries} attempts: {str(e)}")
                return None

def upload_dataset_to_cloudinary(raw_bytes: bytes, filename: str, folder: str = "zestguard/datasets") -> str:
    """
    Dành cho file ZIP Dataset (Phải dùng resource_type='raw')
    """
    try:
        # Đối với file raw, dùng public_id bao gồm cả folder là cách tốt nhất để giữ tên file
        response = cloudinary.uploader.upload(
            raw_bytes,
            public_id=f"{folder}/{filename}", # Kết hợp folder và filename vào đây
            resource_type="raw" # BẮT BUỘC cho file ZIP
        )
        return response.get("secure_url")
    except Exception as e:
        logger.error(f"❌ Cloudinary Raw Upload Error: {str(e)}")
        return None