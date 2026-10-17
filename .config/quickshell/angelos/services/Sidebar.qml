pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Experimental sidebar: a bookmark tab on a screen edge opens a panel with
// toggles, media, sound, system stats and AI limits — or, in its "phone" look (the default), a
// pixel flip phone that comes out of the edge and opens (modules/sidebar/Phone): its keys are the
// toggles, its screen pages the rest; turned on its side it is the sound, the wallpapers and
// the theme.
Singleton {
    id: root

    // the panel: open or not. The phone: `shown` it is on the desk (by its edge), `open` its lid
    // is up; the tab brings it out open and takes it away, the lid opens and shuts in between
    property bool open: false
    property bool shown: false
    onOpenChanged: if (open && phone)
        shown = true
    property bool dragging: false
    property string ghostEdge: ""
    property real ghostOffset: 0.5
    readonly property string screenName: Config.sidebar.screen || (Shell.primaryScreen ? Shell.primaryScreen.name : "")
    readonly property bool enabled: Config.sidebar.enabled && Shell.screenByName(screenName) !== null

    readonly property bool phone: Config.sidebar.look !== "panel"
    // the phone: its screen's page (home, sound, system, ai — those of `sections` it has) and
    // on its side, which tab there (sound | walls | theme)
    property int page: 0
    property bool turned: false
    property string side: "sound"
    signal devLean(real dx, real dy)            // dev: the phone leans as if the pointer were there (tests)
    signal devKey(string k)                     // dev: a key of the phone, "pull:<deg>", "drop", "antenna:<0..1>"

    function toggle() {
        if (!phone)
            open = !open;
        else if (shown)
            hide();
        else
            show(true);
    }
    function show(lidUp) {
        shown = true;
        open = !!lidUp;
    }
    // away for good (the panel: closed)
    function hide() {
        open = false;
        shown = false;
    }
    function has(section) {
        return (Config.sidebar.sections || []).includes(section);
    }
    function setSection(section, on) {
        const list = (Config.sidebar.sections || []).filter(s => s !== section);
        if (on)
            list.push(section);
        Config.sidebar.sections = list;
    }
    // nearest edge for a point on a w×h screen, and the position along it
    function snap(x, y, w, h) {
        const d = {
            "left": x,
            "right": w - x,
            "top": y,
            "bottom": h - y
        };
        const edge = Object.keys(d).reduce((a, b) => d[a] <= d[b] ? a : b);
        const along = edge === "left" || edge === "right" ? y / Math.max(1, h) : x / Math.max(1, w);
        return {
            "edge": edge,
            "offset": Math.max(0.03, Math.min(0.97, along))
        };
    }

    Connections {
        target: Shell
        function onLockedChanged() {
            root.open = false;
        }
    }
}
