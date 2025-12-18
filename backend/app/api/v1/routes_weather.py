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
    if not settings.OPENWEATHER_API_KEY:
        raise HTTPException(status_code=500, detail="Missing OPENWEATHER_API_KEY in .env")

    base = settings.OPENWEATHER_BASE_URL.rstrip("/")
    key = settings.OPENWEATHER_API_KEY

    current_url = f"{base}/weather"
    forecast_url = f"{base}/forecast"

    params = {"lat": lat, "lon": lon, "appid": key, "units": units, "lang": lang}

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            cur_res, fc_res = await client.get(current_url, params=params), await client.get(forecast_url, params=params)

        if cur_res.status_code != 200:
            raise HTTPException(status_code=cur_res.status_code, detail=cur_res.text)
        if fc_res.status_code != 200:
            raise HTTPException(status_code=fc_res.status_code, detail=fc_res.text)

        mapped = map_weather_from_api(cur_res.json(), fc_res.json())
        return mapped

    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"OpenWeather request failed: {e}")
