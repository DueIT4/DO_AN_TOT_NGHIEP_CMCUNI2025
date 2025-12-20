# app/api/v1/routes_weather.py
import httpx
from fastapi import APIRouter, HTTPException, Query

from app.core.config import settings
from app.utils.weather_mapper import map_weather_from_api

router = APIRouter(prefix="/weather", tags=["Weather"])


@router.get("")
async def get_weather(
    lat: float = Query(...),
    lon: float = Query(...),
    lang: str = Query("vi"),
    units: str = Query("metric"),
):
    # Nếu chưa config API key, trả về dữ liệu placeholder
    if not settings.OPENWEATHER_API_KEY or not settings.OPENWEATHER_API_KEY.strip():
        return {
            "current": {
                "temp": "--",
                "feels_like": "--",
                "humidity": "--",
                "weather": [{"main": "Unknown", "description": "API key not configured"}],
                "wind_speed": "--",
            },
            "forecast": [],
        }

    base = settings.OPENWEATHER_BASE_URL.rstrip("/")
    key = settings.OPENWEATHER_API_KEY

    current_url = f"{base}/weather"
    forecast_url = f"{base}/forecast"

    params = {"lat": lat, "lon": lon, "appid": key, "units": units, "lang": lang}

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            cur_res = await client.get(current_url, params=params)
            fc_res = await client.get(forecast_url, params=params)

        if cur_res.status_code != 200:
            # Log error nhưng không crash - trả về dữ liệu placeholder
            print(f"OpenWeather current error: {cur_res.status_code} {cur_res.text}")
            return {
                "current": {
                    "temp": "--",
                    "feels_like": "--",
                    "humidity": "--",
                    "weather": [{"main": "Error", "description": f"HTTP {cur_res.status_code}"}],
                    "wind_speed": "--",
                },
                "forecast": [],
            }
        
        if fc_res.status_code != 200:
            print(f"OpenWeather forecast error: {fc_res.status_code} {fc_res.text}")

        mapped = map_weather_from_api(cur_res.json(), fc_res.json() if fc_res.status_code == 200 else {"list": []})
        return mapped

    except httpx.RequestError as e:
        print(f"OpenWeather request error: {e}")
        # Không crash - trả về dữ liệu placeholder
        return {
            "current": {
                "temp": "--",
                "feels_like": "--",
                "humidity": "--",
                "weather": [{"main": "Offline", "description": "Network error"}],
                "wind_speed": "--",
            },
            "forecast": [],
        }
