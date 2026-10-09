pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The weather in the corner of the desktop clock. Open-Meteo (no key): the place is where the IP
// says (ip-api.com) or the city typed in Settings → Widgets (Open-Meteo's geocoding). Asked only
// while a clock shows it (`wanted`), every 30 minutes; the last answer is kept in
// ~/.cache/angelos/weather.json, so a restart shows it at once and offline keeps the last one.
Singleton {
    id: root

    // a clock with the weather on is on some desktop (DesktopWidgets says so)
    property bool wanted: false
    readonly property string city: (Config.desktop.weatherCity || "").trim()

    // where: {name, lat, lon, from: "ip" | city typed}
    property var place: null
    // now: {temp, feels, code, wind, day, max, min, at}
    property var now: null
    property string error: ""
    property bool busy: false
    readonly property bool ok: !!now && !!place
    readonly property int refreshMs: 30 * 60 * 1000
    readonly property string cacheFile: Config.cacheDir + "/weather.json"

    // WMO weather codes (Open-Meteo): the pixel icon and the words
    function kind(code) {
        const c = code === undefined || code === null ? -1 : code;
        if (c === 0 || c === 1)
            return "clear";
        if (c === 2)
            return "partly";
        if (c === 3)
            return "cloudy";
        if (c === 45 || c === 48)
            return "fog";
        if (c >= 51 && c <= 67 || c >= 80 && c <= 82)
            return "rain";
        if (c >= 71 && c <= 77 || c === 85 || c === 86)
            return "snow";
        if (c >= 95)
            return "storm";
        return "cloudy";
    }
    function icon(code, day) {
        const k = kind(code);
        return k === "clear" ? (day === false ? "moon" : "sun") : ({
                "partly": "cloudSun",
                "cloudy": "cloud",
                "fog": "fog",
                "rain": "rain",
                "snow": "snow",
                "storm": "storm"
            })[k];
    }
    function words(code) {
        return ({
                "clear": I18n.t("ясно", "clear"),
                "partly": I18n.t("переменная облачность", "partly cloudy"),
                "cloudy": I18n.t("облачно", "cloudy"),
                "fog": I18n.t("туман", "fog"),
                "rain": I18n.t("дождь", "rain"),
                "snow": I18n.t("снег", "snow"),
                "storm": I18n.t("гроза", "thunderstorm")
            })[kind(code)];
    }
    function deg(t) {
        if (t === undefined || t === null || isNaN(t))
            return "—";
        const r = Math.round(t);
        return (r > 0 ? "+" : r < 0 ? "−" : "") + Math.abs(r) + "°";
    }

    function get(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let body = null;
            try {
                body = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            done(body, xhr.status);
        };
        xhr.open("GET", url);
        xhr.send();
    }
    function fail(status) {
        busy = false;
        error = status ? "HTTP " + status : I18n.t("нет сети", "offline");
    }

    // the place first (the typed city, or the IP's once a day), then the weather
    function refresh() {
        if (busy || !Config.ready)
            return;
        busy = true;
        const want = city || "ip";
        if (place && place.from === want && (want !== "ip" || Date.now() - (place.at || 0) < 24 * 3600 * 1000)) {
            fetchWeather();
            return;
        }
        if (city) {
            get("https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&language=" + (I18n.english ? "en" : "ru") + "&name=" + encodeURIComponent(city), (b, s) => {
                const r = b && b.results && b.results[0];
                if (!r) {
                    busy = false;
                    error = b ? I18n.t("город не найден", "city not found") : (s ? "HTTP " + s : I18n.t("нет сети", "offline"));
                    return;
                }
                place = {
                    "name": r.name,
                    "lat": r.latitude,
                    "lon": r.longitude,
                    "from": want,
                    "at": Date.now()
                };
                fetchWeather();
            });
        } else {
            get("http://ip-api.com/json/?fields=status,city,lat,lon", (b, s) => {
                if (!b || b.status !== "success")
                    return fail(s);
                place = {
                    "name": b.city,
                    "lat": b.lat,
                    "lon": b.lon,
                    "from": "ip",
                    "at": Date.now()
                };
                fetchWeather();
            });
        }
    }
    function fetchWeather() {
        const p = place;
        get("https://api.open-meteo.com/v1/forecast?latitude=" + p.lat + "&longitude=" + p.lon + "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day&daily=temperature_2m_max,temperature_2m_min&wind_speed_unit=ms&timezone=auto&forecast_days=1", (b, s) => {
            busy = false;
            const c = b && b.current;
            if (!c)
                return fail(s);
            now = {
                "temp": c.temperature_2m,
                "feels": c.apparent_temperature,
                "code": c.weather_code,
                "wind": c.wind_speed_10m,
                "day": c.is_day !== 0,
                "max": b.daily && b.daily.temperature_2m_max ? b.daily.temperature_2m_max[0] : null,
                "min": b.daily && b.daily.temperature_2m_min ? b.daily.temperature_2m_min[0] : null,
                "at": Date.now()
            };
            error = "";
            cache.write(JSON.stringify({
                "place": place,
                "now": now
            }));
        });
    }

    // a new city: ask again (a moment after the typing stops)
    onCityChanged: if (wanted)
        cityPause.restart()
    Timer {
        id: cityPause
        interval: 1500
        onTriggered: {
            root.busy = false;
            root.refresh();
        }
    }
    Timer {
        running: root.wanted && Config.ready
        interval: root.refreshMs
        repeat: true
        triggeredOnStart: true
        // the cached answer is fresh enough: wait for the next turn
        onTriggered: if (!root.now || Date.now() - (root.now.at || 0) > root.refreshMs - 60000 || !root.place || root.place.from !== (root.city || "ip"))
            root.refresh()
    }

    AsyncFile {
        id: cache
        path: root.cacheFile
        printErrors: false
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (c.place && !root.place)
                    root.place = c.place;
                if (c.now && !root.now)
                    root.now = c.now;
            } catch (e) {}
        }
    }
}
