import firebase_admin
from firebase_admin import credentials, auth
from pathlib import Path
import os


# =========================
# 🔥 Khởi tạo Firebase Admin
# =========================
def init_firebase():
    """
    Hàm khởi tạo Firebase Admin SDK chỉ 1 lần.
    - Đọc credentials từ biến môi trường hoặc file JSON
    """
    if not firebase_admin._apps:
        cred_path = os.getenv("FIREBASE_CRED_PATH")

        # Nếu không có biến môi trường, thử dùng file mặc định trong app/core/firebase-key.json
        if not cred_path:
            cred_path = Path(__file__).parent / "firebase-key.json"

        if not Path(cred_path).exists():
            raise FileNotFoundError(
                f"Không tìm thấy file Firebase credential: {cred_path}"
            )

        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred)
        print("✅ Firebase Admin SDK đã khởi tạo.")
    else:
        print("ℹ️ Firebase Admin SDK đã tồn tại.")


# =========================
# ✅ Xác thực token từ FE gửi lên
# =========================
def verify_firebase_token(id_token: str) -> dict:
    """
    Xác thực Firebase ID token từ client (mobile/web)
    - Trả về thông tin người dùng (uid, email, name, picture, ...)
    - Nếu token không hợp lệ → raise ValueError
    """
    try:
        decoded = auth.verify_id_token(id_token)
        return decoded
    except Exception as e:
        raise ValueError(f"Token Firebase không hợp lệ: {e}")
