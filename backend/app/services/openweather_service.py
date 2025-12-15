import httpx
from app.core.config import settings

class OpenWeatherService:
    def __init__(self):
        if not getattr(settings, "OPENWEATHER_API_KEY", None):
            raise RuntimeError("Missing OPENWEATHER_API_KEY in settings/.env")
        self.api_key = settings.OPENWEATHER_API_KEY
        self.base = getattr(settings, "OPENWEATHER_BASE_URL", "https://api.openweathermap.org/data/2.5")

    async def get_current_and_forecast(self, lat: float, lon: float, lang: str = "vi"):
        current_url = (
            f"{self.base}/weather?lat={lat}&lon={lon}"
            f"&appid={self.api_key}&units=metric&lang={lang}"
        )
        forecast_url = (
            f"{self.base}/forecast?lat={lat}&lon={lon}"
            f"&appid={self.api_key}&units=metric&lang={lang}"
        )

        async with httpx.AsyncClient(timeout=15) as client:
            cur_res, fc_res = await client.get(current_url), await client.get(forecast_url)

        return cur_res, fc_res
