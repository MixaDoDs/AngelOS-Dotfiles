pragma Singleton

import QtQuick
import Quickshell
import qs.services

// serp-skin: which line icon a state wants (MacIcons' names)
Singleton {
    function weather(now) {
        if (!now)
            return "cloud";
        const k = Weather.kind(now.code);
        return k === "clear" ? (now.day === false ? "moon" : "sun") : k === "partly" ? "sun-dim" : k === "rain" || k === "storm" ? "zap" : k === "fog" ? "wind" : "cloud";
    }
    function net() {
        if (!Wifi.hasWifi && Wifi.wiredDevice)
            return "ethernet-port";
        return !Wifi.enabled ? "wifi-off" : !Wifi.connected ? "wifi-zero" : Wifi.strength < 0.4 ? "wifi-low" : "wifi";
    }
    function volume() {
        return Audio.muted || Audio.volume === 0 ? "volume-x" : Audio.volume < 0.34 ? "volume" : Audio.volume < 0.67 ? "volume-1" : "volume-2";
    }
}
