import sys
import os
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent.parent
sys.path.append(str(backend_dir))

from app.core.config import settings
import cloudinary
import cloudinary.uploader

def test_upload():
    print("--- Cloudinary Connection Test ---")
    print(f"Cloud Name: {settings.CLOUDINARY_CLOUD_NAME}")
    print(f"API Key: {settings.CLOUDINARY_API_KEY[:4]}****")
    
    # Configure
    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True
    )
    
    # Create a dummy white image (100x100)
    from PIL import Image
    from io import BytesIO
    
    img = Image.new('RGB', (100, 100), color='white')
    buf = BytesIO()
    img.save(buf, format='JPEG')
    raw_bytes = buf.getvalue()
    
    print(f"Attempting to upload {len(raw_bytes)} bytes...")
    
    try:
        response = cloudinary.uploader.upload(
            raw_bytes,
            folder="zestguard/test",
            resource_type="image"
        )
        print("✅ Upload SUCCESS!")
        print(f"URL: {response.get('secure_url')}")
    except Exception as e:
        print("❌ Upload FAILED!")
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_upload()
