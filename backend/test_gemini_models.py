#!/usr/bin/env python3
"""Script để test và list các Gemini models available"""
import os
from dotenv import load_dotenv
import google.generativeai as genai

load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("❌ GEMINI_API_KEY không tìm thấy trong .env")
    exit(1)

print(f"✅ API Key found: {api_key[:10]}...")

try:
    genai.configure(api_key=api_key)
    print("✅ Gemini configured OK\n")
    
    # List available models
    print("📋 Available models:")
    for model in genai.list_models():
        if 'generateContent' in model.supported_generation_methods:
            print(f"  - {model.name}")
    
    print("\n🧪 Testing models:")
    
    # Test gemini-pro
    try:
        model = genai.GenerativeModel('gemini-pro')
        response = model.generate_content("Hello")
        print(f"✅ gemini-pro: OK - {response.text[:50]}...")
    except Exception as e:
        print(f"❌ gemini-pro: {e}")
    
    # Test gemini-1.5-pro
    try:
        model = genai.GenerativeModel('gemini-2.0-pro')
        response = model.generate_content("Hello")
        print(f"✅ gemini-2.0-pro: OK - {response.text[:50]}...")
    except Exception as e:
        print(f"❌ gemini-2.0-pro: {e}")
    
    # Test gemini-1.5-flash
    try:
        model = genai.GenerativeModel('gemini-2.0-flash')
        response = model.generate_content("Hello")
        print(f"✅ gemini-2.0-flash: OK - {response.text[:50]}...")
    except Exception as e:
        print(f"❌ gemini-2.0-flash: {e}")
        
except Exception as e:
    print(f"❌ Error: {e}")

