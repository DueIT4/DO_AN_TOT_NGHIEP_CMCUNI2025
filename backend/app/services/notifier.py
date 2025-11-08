# app/services/notifier.py

def send_sms(phone: str, text: str) -> None:
    # TODO: thay bằng gọi SMS gateway thật (Twilio, Viettel, v.v.)
    print(f"[DEV] SMS to {phone}: {text}")

def send_email(email: str, subject: str, body: str) -> None:
    # TODO: thay bằng SMTP/Email API thật
    print(f"[DEV] EMAIL to {email}: {subject}\n{body}")

def send_facebook_dm(fb_id: str, text: str) -> None:
    # TODO: thay bằng Facebook Graph API thật
    print(f"[DEV] FB DM to {fb_id}: {text}")
