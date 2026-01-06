
import os
import cloudinary
import cloudinary.uploader
from dotenv import load_dotenv

# Load .env directly
load_dotenv()

def test_upload():
    cloud_name = os.getenv("CLOUDINARY_CLOUD_NAME")
    api_key = os.getenv("CLOUDINARY_API_KEY")
    api_secret = os.getenv("CLOUDINARY_API_SECRET")

    print("Checking Cloudinary Configuration (Direct from .env)...")
    print(f"Cloud Name: {cloud_name}")
    print(f"API Key: {'*' * 5 if api_key else 'MISSING'}")
    print(f"API Secret: {'*' * 5 if api_secret else 'MISSING'}")

    if not all([cloud_name, api_key, api_secret]):
        print("\n❌ MISSING CREDENTIALS! Please check your .env file.")
        return

    # Configure
    cloudinary.config(
        cloud_name=cloud_name,
        api_key=api_key,
        api_secret=api_secret,
        secure=True
    )

    print("\nAttempting upload...")
    try:
        # Dummy image (red dot)
        dummy_image = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf\xc0\x00\x00\x03\x01\x01\x00\x18\xdd\x8d\xb0\x00\x00\x00\x00IEND\xaeB`\x82'
        
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
