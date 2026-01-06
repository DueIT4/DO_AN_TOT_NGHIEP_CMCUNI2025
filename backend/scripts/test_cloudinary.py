
import sys
import os
from pathlib import Path

# Add backend directory to sys.path
sys.path.append(str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv
load_dotenv()

from app.core.config import settings
import cloudinary
import cloudinary.uploader

def test_upload():
    print("Checking Cloudinary Configuration...")
    print(f"Cloud Name: {settings.CLOUDINARY_CLOUD_NAME}")
    print(f"API Key: {'*' * 5 if settings.CLOUDINARY_API_KEY else 'MISSING'}")
    print(f"API Secret: {'*' * 5 if settings.CLOUDINARY_API_SECRET else 'MISSING'}")

    # Configure manually to be sure (like in service)
    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True
    )

    print("\nAttempting upload...")
    try:
        # Create a dummy image (1x1 transparent pixel) or just upload a small text file as raw
        # Using a small byte string for image
        dummy_image = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
        
        response = cloudinary.uploader.upload(
            dummy_image,
            folder="zestguard/test",
            resource_type="image"
        )
        print("\n✅ Upload SUCCESS!")
        print(f"URL: {response.get('secure_url')}")
    except Exception as e:
        print(f"\n❌ Upload FAILED: {e}")

if __name__ == "__main__":
    test_upload()
