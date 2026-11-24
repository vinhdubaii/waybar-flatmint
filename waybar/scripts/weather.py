#!/usr/bin/env python3
"""Waybar weather module using open-meteo.com directly (no third-party server, stdlib only).

Optional config: ~/.config/weather.cfg
    [DEFAULT]
    city = Bien Hoa          # omit or "auto" -> detect via IP (geoip.sh)
    temperature = C          # C or F
    distance = km            # km or miles
    # latitude = 10.95       # optional, overrides city
    # longitude = 106.82
"""
import argparse, configparser, json, os, subprocess, sys, urllib.parse, urllib.request
from datetime import date

HOME = os.environ["HOME"]
cfg_path = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config"), "weather.cfg")
cfg = configparser.ConfigParser()
cfg.read(cfg_path)

ap = argparse.ArgumentParser(description="Waybar weather module")
ap.add_argument("-c", "--city", default=cfg.get("DEFAULT", "city", fallback="auto"))
ap.add_argument("-t", "--temperature", default=cfg.get("DEFAULT", "temperature", fallback="C"), choices=["C", "F"])
ap.add_argument("-d", "--distance", default=cfg.get("DEFAULT", "distance", fallback="km"), choices=["km", "miles"])
args = ap.parse_args()

lat = cfg.get("DEFAULT", "latitude", fallback=None)
lon = cfg.get("DEFAULT", "longitude", fallback=None)
tunit = "fahrenheit" if args.temperature == "F" else "celsius"
wunit = "mph" if args.distance == "miles" else "kmh"
cache_dir = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "waybar-weather")
os.makedirs(cache_dir, exist_ok=True)
cache_file = os.path.join(cache_dir, f"weather-{urllib.parse.quote(args.city)}-{tunit}-{wunit}.json")

# WMO weather code -> (day icon, night icon, description)
WMO = {
    0: ("☀️", "🌙", "Clear sky"), 1: ("🌤️", "🌙", "Mainly clear"), 2: ("⛅", "☁️", "Partly cloudy"),
    3: ("☁️", "☁️", "Overcast"), 45: ("🌫️", "🌫️", "Fog"), 48: ("🌫️", "🌫️", "Rime fog"),
    51: ("🌦️", "🌧️", "Light drizzle"), 53: ("🌦️", "🌧️", "Drizzle"), 55: ("🌧️", "🌧️", "Heavy drizzle"),
    56: ("🌧️", "🌧️", "Freezing drizzle"), 57: ("🌧️", "🌧️", "Freezing drizzle"),
    61: ("🌦️", "🌧️", "Light rain"), 63: ("🌧️", "🌧️", "Rain"), 65: ("🌧️", "🌧️", "Heavy rain"),
    66: ("🌧️", "🌧️", "Freezing rain"), 67: ("🌧️", "🌧️", "Freezing rain"),
    71: ("🌨️", "🌨️", "Light snow"), 73: ("🌨️", "🌨️", "Snow"), 75: ("❄️", "❄️", "Heavy snow"),
    77: ("🌨️", "🌨️", "Snow grains"), 80: ("🌦️", "🌧️", "Light showers"), 81: ("🌧️", "🌧️", "Showers"),
    82: ("⛈️", "⛈️", "Violent showers"), 85: ("🌨️", "🌨️", "Snow showers"), 86: ("🌨️", "🌨️", "Heavy snow showers"),
    95: ("⛈️", "⛈️", "Thunderstorm"), 96: ("⛈️", "⛈️", "Thunderstorm, hail"), 99: ("⛈️", "⛈️", "Thunderstorm, heavy hail"),
}

def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "waybar-weather/1.0"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)

def locate():
    """Return (lat, lon, city_name)."""
    if lat and lon:
        return float(lat), float(lon), args.city if args.city != "auto" else ""
    if args.city and args.city != "auto":
        g = get_json("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + urllib.parse.quote(args.city))
        res = (g.get("results") or [None])[0]
        if not res:
            raise RuntimeError(f"city not found: {args.city}")
        return res["latitude"], res["longitude"], res.get("name", args.city)
    here = os.path.dirname(os.path.abspath(__file__))
    out = subprocess.run(["sh", os.path.join(here, "geoip.sh")], capture_output=True, text=True, timeout=30).stdout
    g = json.loads(out or "{}")
    if "latitude" not in g:
        raise RuntimeError("could not detect location")
    return g["latitude"], g["longitude"], g.get("city", "")

def fetch():
    la, lo, name = locate()
    q = urllib.parse.urlencode({
        "latitude": la, "longitude": lo, "timezone": "auto",
        "temperature_unit": tunit, "wind_speed_unit": wunit,
        "current": "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day",
        "daily": "temperature_2m_max,temperature_2m_min,sunrise,sunset",
    })
    d = get_json("https://api.open-meteo.com/v1/forecast?" + q)
    c, day = d["current"], d["daily"]
    icon_day, icon_night, desc = WMO.get(c["weather_code"], ("🌡️", "🌡️", "Unknown"))
    icon = icon_day if c["is_day"] else icon_night
    deg = "°F" if args.temperature == "F" else "°C"
    wu = "mph" if args.distance == "miles" else "km/h"
    tooltip = "\n".join(filter(None, [
        f"<b>{name}</b>" if name else "",
        f"{icon} {desc}",
        f"Temperature: {c['temperature_2m']}{deg} (feels like {c['apparent_temperature']}{deg})",
        f"Wind: {c['wind_speed_10m']} {wu}   Humidity: {c['relative_humidity_2m']}%",
        f"Today: {day['temperature_2m_min'][0]}{deg} / {day['temperature_2m_max'][0]}{deg}",
        f"Sunrise {day['sunrise'][0][-5:]}   Sunset {day['sunset'][0][-5:]}",
    ]))
    return {"text": f"{icon} {c['temperature_2m']}{deg}", "tooltip": tooltip,
            "class": "day" if c["is_day"] else "night", "alt": str(c["weather_code"])}

try:
    out = fetch()
    with open(cache_file, "w") as f:
        json.dump(out, f)
except Exception as err:
    if os.path.exists(cache_file):
        with open(cache_file) as f:
            out = json.load(f)
    else:
        print(err, file=sys.stderr)
        sys.exit(1)
print(json.dumps(out, ensure_ascii=False))
