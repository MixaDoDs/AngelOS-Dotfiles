pragma Singleton

import QtQuick
import Quickshell
import qs.config

// angel-niri: Alt+wheel over a window makes it see-through in dots, a Bayer screen door with no
// blending (Settings → Windows; off by default — apps lose their Alt+wheel). The compositor does it
// all (src/window_dither.rs); nothing is remembered. Asked once whether the running angel-niri knows
// the action: an older one or stock niri answers Err, and it stays off. The same build has
// `show-desktop --release`, so Chalk writes the held Mod+D only when this is supported.
Singleton {
    id: root

    property bool supported: false
    property bool probed: false
    readonly property bool on: supported && Config.ready && Config.windows.ditherWheel === true
    onOnChanged: Niri.action("SetDitherWheel", {
        "on": on
    })
    Component.onCompleted: {
        if (!Niri.available)
            return;
        Niri.request({
            "Action": {
                "SetDitherWheel": {
                    "on": false
                }
            }
        }, (ok, err) => {
            supported = !err;
            probed = true;
        }, true);
    }
}
