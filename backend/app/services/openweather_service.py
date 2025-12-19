import httpx
from app.core.config import settings


class OpenWeatherService:
    def __init__(self):
        if not getattr(settings, "OPENWEATHER_API_KEY", None):
            raise RuntimeError("Missing OPENWEATHER_API_KEY in settings/.env")
        self.api_key = settings.OPENWEATHER_API_KEY
        self.base = getattr(settings, "OPENWEATHER_BASE_URL", "https://api.openweathermap.org/data/2.5").rstrip("/")

    async def get_current_and_forecast(self, lat: float, lon: float, lang: str = "vi", units: str = "metric"):
        current_url = f"{self.base}/weather"
        forecast_url = f"{self.base}/forecast"
        params = {"lat": lat, "lon": lon, "appid": self.api_key, "units": units, "lang": lang}

        async with httpx.AsyncClient(timeout=15) as client:
            cur_res, fc_res = await client.get(current_url, params=params), await client.get(forecast_url, params=params)

        return cur_res, fc_res
