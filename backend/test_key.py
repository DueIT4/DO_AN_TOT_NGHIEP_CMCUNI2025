import requests
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("GEMINI_API_KEY")

print("Raw API_KEY repr:", repr(API_KEY))
print("Length:", len(API_KEY) if API_KEY else None)

url = f"https://generativelanguage.googleapis.com/v1beta/models?key={API_KEY}"
resp = requests.get(url)
print("Status:", resp.status_code)
print("Body:", resp.text)
