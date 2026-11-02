pragma Singleton

import QtQuick
import Quickshell
import qs.config

// angel-niri: the windows spring a pixel or two on each kick of the music (Settings → Windows →
// «Windows on the kick»; off by default). The compositor rescales them as they are drawn
// (src/window_pulse.rs), nothing is drawn twice; fullscreen windows stay put. Asked once whether
// the running angel-niri knows the action: an older one or stock niri answers Err, and it stays off.
Singleton {
    id: root

    property bool supported: false
    readonly property bool on: supported && Config.ready && Config.windows.kickPulse === true && !GoldenGate.on
    onOnChanged: Bass.windowsListen = on
    Component.onCompleted: {
        if (!Niri.available)
            return;
        Niri.request({
            "Action": {
                "WindowPulse": {
                    "px": 0,
                    "ms": 0
                }
            }
        }, (ok, err) => supported = !err, true);
    }
    Connections {
        target: Bass
        enabled: root.on && Lyrics.isSong
        function onKicked() {
            // a light kick a pixel, a hard one two; the song's first kicks a step more
            Niri.action("WindowPulse", {
                "px": Math.round(1 + Bass.punch) + (Bass.hype > 0.5 ? 1 : 0),
                "ms": 180
            });
        }
    }
}
