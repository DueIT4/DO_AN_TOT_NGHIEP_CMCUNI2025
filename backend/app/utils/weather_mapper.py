# app/utils/weather_mapper.py
from datetime import datetime, date


def _title_case_vi(s: str) -> str:
    parts = [p for p in (s or "").split(" ") if p]
    return " ".join([p[0].upper() + p[1:] if len(p) > 1 else p.upper() for p in parts])


def _map_icon(main: str) -> str:
    m = (main or "").lower()
    if m == "clear":
        return "☀️"
    if m == "clouds":
        return "⛅"
    if m in ("rain", "drizzle"):
        return "🌧️"
    if m == "thunderstorm":
        return "⛈️"
    if m == "snow":
        return "❄️"
    if m in ("mist", "fog", "haze"):
        return "🌫️"
    return "☁️"


def map_weather_from_api(current: dict, forecast: dict) -> dict:
    location = f"{current.get('name','Không rõ')}, {current.get('sys',{}).get('country','')}".strip()
    temp = round(current.get("main", {}).get("temp", 0))
    feels_like = round(current.get("main", {}).get("feels_like", temp))
    description = _title_case_vi(str((current.get("weather") or [{}])[0].get("description", "")))

    humidity = round(current.get("main", {}).get("humidity", 0))
    wind_ms = float(current.get("wind", {}).get("speed", 0.0))
    wind_kmh = wind_ms * 3.6  # m/s -> km/h
    pressure = round(current.get("main", {}).get("pressure", 0))
    uv_index = 7  # free plan: mock
    visibility = f"{(float(current.get('visibility', 0)) / 1000):.1f}"

    weather_main = str((current.get("weather") or [{}])[0].get("main", ""))
    icon = _map_icon(weather_main)

    daily = {}
    for item in (forecast.get("list") or []):
        dt_txt = str(item.get("dt_txt", ""))
        if not dt_txt:
            continue
        d = dt_txt.split(" ")[0]  # yyyy-mm-dd
        tmax = float(item.get("main", {}).get("temp_max", 0))
        tmin = float(item.get("main", {}).get("temp_min", 0))
        main = str((item.get("weather") or [{}])[0].get("main", ""))
        desc = str((item.get("weather") or [{}])[0].get("description", ""))

        if d not in daily:
            daily[d] = {"high": tmax, "low": tmin, "main": main, "desc": desc}
        else:
            if tmax > daily[d]["high"]:
                daily[d]["high"] = tmax
            if tmin < daily[d]["low"]:
                daily[d]["low"] = tmin

    now = datetime.now()
    today = date(now.year, now.month, now.day)

    days = [{
        "day": "Hôm nay",
        "high": temp,
        "low": temp,
        "icon": icon,
        "desc": description,
    }]

    weekday_names = ["Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "CN"]

    for d_str in sorted(daily.keys()):
        try:
            dt = datetime.fromisoformat(d_str)
        except ValueError:
            continue

        d_date = date(dt.year, dt.month, dt.day)
        if d_date == today:
            continue

        diff = (d_date - today).days
        if diff <= 0:
            continue

        d = daily[d_str]
        if diff == 1:
            days.append({
                "day": "Ngày mai",
                "high": round(d["high"]),
                "low": round(d["low"]),
                "icon": _map_icon(d["main"]),
                "desc": d["desc"],
            })
        elif diff > 1 and len(days) < 5:
            days.append({
                "day": weekday_names[dt.weekday()],
                "high": round(d["high"]),
                "low": round(d["low"]),
                "icon": _map_icon(d["main"]),
                "desc": d["desc"],
            })

        if len(days) >= 5:
            break

    return {
        "location": location,
        "temperature": temp,
        "feelsLike": feels_like,
        "description": description,
        "humidity": humidity,
        "windSpeed": f"{wind_kmh:.1f}",
        "pressure": pressure,
        "uvIndex": uv_index,
        "visibility": visibility,
        "icon": icon,
        "forecast": days,
    }
