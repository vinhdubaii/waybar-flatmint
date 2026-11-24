#!/bin/sh
# Prints JSON: latitude, longitude, city, sunrise, sunset, sunrise_tomorrow, sunset_tomorrow
# Cached in ~/.cache/geoip for 6 hours. Uses ipwho.is (fallback ipapi.co) + open-meteo.
set -u
cache_file="$HOME/.cache/geoip"
mkdir -p "$HOME/.cache"
now=$(date +%s)
mtime=$(date -r "$cache_file" +%s 2>/dev/null || echo 0)

if [ ! -s "$cache_file" ] || [ $((now - mtime)) -gt 21600 ]; then
    loc=$(curl -fsSL --max-time 8 "https://ipwho.is/" 2>/dev/null | jq -c 'select(.success != false) | {latitude, longitude, city}' 2>/dev/null)
    if [ -z "$loc" ]; then
        loc=$(curl -fsSL --max-time 8 "https://ipapi.co/json/" 2>/dev/null | jq -c 'select(.latitude != null) | {latitude, longitude, city}' 2>/dev/null)
    fi
    if [ -n "$loc" ]; then
        lat=$(echo "$loc" | jq -r '.latitude')
        lon=$(echo "$loc" | jq -r '.longitude')
        sun=$(curl -fsSL --max-time 8 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&daily=sunrise,sunset&timezone=auto&forecast_days=2" 2>/dev/null)
        tmp=$(mktemp "$cache_file.XXXXXX") || exit 1
        if [ -n "$sun" ] && echo "$sun" | jq -e '.daily.sunrise[1]' >/dev/null 2>&1; then
            echo "$sun" | jq -c --argjson loc "$loc" '$loc + {
                sunrise: .daily.sunrise[0], sunset: .daily.sunset[0],
                sunrise_tomorrow: .daily.sunrise[1], sunset_tomorrow: .daily.sunset[1]}' > "$tmp"
        else
            echo "$loc" > "$tmp"
        fi
        mv "$tmp" "$cache_file"
    fi
fi
[ -s "$cache_file" ] && cat "$cache_file" || echo '{}'
