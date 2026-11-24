pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.serp.panels

// serp-skin: the window the skin's panels open in on one screen — the system panel (right edge,
// full height), notifications (left edge), now playing (under the left island) and the calendar
// (under the centre). Over everything but the bar's strip (the islands stay clickable and toggle
// them); a click outside or Esc closes. Each panel drops out of the bar Serpantinum's way: a spring
// on open (1 − e^(−7t)(cos 5.62t + 1.2456 sin 5.62t), 700 ms); on close it is drawn back where it
// came from (up into its island / off the right edge, a little smaller), 240 ms InCubic: slow
// away, then gone. niri's blur goes on the close's first frame (it can't move or fade with the
// panel), so the panel leaves as its own ground — needs angel-niri's blur region read at every commit (3708ce76):
// before it niri kept the old blur region until unmap.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name
    readonly property string kind: Serp.panelScreen === screenName ? Serp.panel : ""
    // the last panel shown here, kept while it closes
    property string shown: ""
    onKindChanged: if (kind !== "")
        shown = kind
    readonly property bool open: kind !== ""

    // the spring
    property real t: 0
    function spring(x) {
        return 1 - Math.exp(-7 * x) * (Math.cos(5.62 * x) + 1.2456 * Math.sin(5.62 * x));
    }
    readonly property real progress: open ? spring(t) : t
    // which curve `t` ran on last (the spring or the straight close): at a turn `open` has already
    // flipped, so where the panel stands is read from this, not from `progress`
    property bool ranOpen: false
    // the close starts where the panel stood (p0): its place, size and fade go on from there, not
    // from the close's own full-open numbers (a quick close jumped ~10 px and dimmed at once)
    property real closeFrom: 1
    // 0 at the close's start → 1 at its end
    readonly property real closeK: open ? 0 : Math.max(0, Math.min(1, (closeFrom - progress) / closeFrom))
    NumberAnimation on t {
        id: springIn
        running: false
        // closed: off the screen the very frame the panel is gone. Only at the real end: run()
        // stops the opening spring when a quick click closes it, and that stop() fired this too —
        // the panel vanished without its close (2026-11-13, clicks faster than the 700 ms spring)
        onStopped: if (!win.open && win.t <= 0.001)
            win.alive = false
    }
    // kept on screen by a flag of its own until the close is over (see SerpOsd: "open || the timer
    // runs" was false for a frame between the two — a blink)
    property bool alive: open
    onOpenChanged: {
        if (!open)
            gone.restart();
        else {
            gone.stop();
            alive = true;
        }
        run();
    }
    Timer {
        id: gone
        interval: 340   // only a fallback: the close animation's end unmaps it
        onTriggered: win.alive = false
    }
    Component.onCompleted: {
        shown = kind;
        run();
    }
    function run() {
        const p = Math.max(0, ranOpen ? spring(t) : t);   // what is on screen now (the spring overshoots 1)
        ranOpen = open;
        springIn.stop();
        if (open) {
            // reopened mid-close: the spring picks up where the panel stands (its rising part,
            // 0..0.5, is monotonic — bisect it), not from nothing
            let lo = 0, hi = 0.5;
            if (p > 0.001) {
                for (let i = 0; i < 20; i++) {
                    const m = (lo + hi) / 2;
                    if (spring(m) < p)
                        lo = m;
                    else
                        hi = m;
                }
            }
            const t0 = p > 0.001 ? lo : 0;
            springIn.from = t0;
            springIn.to = 1;
            springIn.duration = Math.round(700 * (1 - t0));
            springIn.easing.type = Easing.Linear;
        } else {
            closeFrom = Math.max(0.001, p);
            springIn.from = p;
            springIn.to = 0;
            springIn.duration = Math.round(240 * Math.max(0.4, Math.min(1, p)));   // closing mid-open: shorter
            springIn.easing.type = Easing.InCubic;
        }
        t = springIn.from;   // the same frame: no flash of the other curve
        springIn.start();
    }

    screen: modelData
    // the surface itself goes when the panel has closed: hiding only its content could leave the
    // last frame on screen (closing during the opening spring kept the cover's blur up)
    visible: alive
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-serppanel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
    mask: Region {
        item: win.open ? full : null
        Region {
            x: 0
            y: 0
            width: win.width
            height: Serp.barHeight
            intersection: Intersection.Subtract
        }
    }
    // closing: an EMPTY region at once, not null — with null the compositor's blur under the box
    // stayed a few frames after the box faded (the "tail" seen when the media panel closed)
    // niri's blur only while the panel stands (almost) whole: it showed a few frames before the
    // content when opening and stayed after it when closing (an empty frosted plate — the "tail")
    BackgroundEffect.blurRegion: Serp.blurOn && win.open && win.progress > 0.85 ? blurRegion : noBlur
    Region {
        id: blurRegion
        item: box
        radius: Serp.radius
    }
    Region {
        id: noBlur
    }

    Item {
        id: full
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: Serp.closePanel()
        MouseArea {
            anchors.fill: parent
            onPressed: Serp.closePanel()
        }
    }

    // where each panel stands
    readonly property int edge: Serp.px(8)
    readonly property int top: Serp.barHeight + Serp.px(6)
    readonly property var geo: ({
            "quick": {
                "w": Serp.px(420),
                "h": win.height - top - edge,
                "x": win.width - Serp.px(420) - edge * 2,
                "from": "right"
            },
            "notifs": {
                "w": Serp.px(420),
                "h": win.height - top - edge,
                "x": win.width - Serp.px(420) - edge * 2,
                "from": "right"
            },
            "media": {
                "w": Serp.px(625),
                "h": Serp.px(565),
                "x": edge * 2,
                "from": "top"
            },
            "net": {
                "w": Math.min(win.width - edge * 4, Serp.px(720)),
                "h": Serp.px(560),
                "x": win.width - Math.min(win.width - edge * 4, Serp.px(720)) - edge * 2,
                "from": "top"
            },
            "sound": {
                "w": Serp.px(410),
                "h": Serp.px(580),
                "x": win.width - Serp.px(410) - edge * 2,
                "from": "top"
            },
            "weather": {
                "w": Serp.px(480),
                "h": Serp.px(470),
                "x": edge * 2,
                "from": "top"
            },
            "eq": {
                "w": Serp.px(440),
                "h": Serp.px(500),
                "x": win.width - Serp.px(440) - edge * 2,
                "from": "top"
            },
            "calendar": {
                "w": Math.min(win.width - edge * 4, Serp.px(940)),
                "h": Serp.px(380),
                // under the clock: the left island's while the Halo holds the centre, else the centre's
                "x": Halo.on(win.screenName) ? edge * 2 : Math.round((win.width - Math.min(win.width - edge * 4, Serp.px(940))) / 2),
                "from": "top"
            }
        })
    readonly property var g: geo[shown] || geo.quick

    SerpBackdrop {
        id: glassBack
        screenName: win.screenName
        origin: Qt.point(0, 0)
    }
    Item {
        id: box
        // the way back is longer than the way in: it leaves, it doesn't just settle
        readonly property real away: win.open ? 1 - win.progress : (1 - win.closeFrom) + win.closeK * (1 + win.closeFrom)
        x: g.x + (g.from === "right" ? away * Serp.px(36) : g.from === "left" ? -away * Serp.px(36) : 0)
        y: win.top + (g.from === "top" ? -away * Serp.px(24) : 0)
        width: g.w
        height: g.h
        // opening: in fast with the spring; closing: the fade keeps pace with the pull (InCubic),
        // the panel still reads in the first half and is gone as it speeds off
        opacity: win.open ? Math.min(1, win.progress * 1.6) : Math.min(1, win.progress * (win.closeFrom >= 0.625 ? Math.max(1.25, 1 / win.closeFrom) : 1.6))
        // closed: gone once the fade is over, whatever the animation did (closing in the middle
        // of the opening spring left the cover's blur stuck on screen, 2026-11-13)
        visible: win.alive
        readonly property real s0: g.from === "top" ? 0.96 + 0.04 * Math.min(1, win.closeFrom) : 1
        scale: g.from === "top" ? (win.open ? 0.96 + 0.04 * Math.min(1, win.progress) : s0 + win.closeK * (0.9 - s0)) : (win.open ? 1 : 1 - 0.03 * win.closeK)
        transformOrigin: g.from === "right" ? Item.Right : Item.Top

        // the panel's glass under its own (then nearly clear) ground
        SGlass {
            anchors.fill: parent
            visible: Serp.glassOn
            backdrop: glassBack
            radius: Math.min(Serp.radius * 1.4, 24)
            bezel: Serp.px(12)  // the islands' thin lens edge (a 26 px one framed the panel and streaked)
        }
        Loader {
            anchors.fill: parent
            active: win.shown === "quick" && box.visible
            sourceComponent: SerpQuickPanel {
                screenName: win.screenName
                progress: win.progress
            }
        }
        Loader {
            anchors.fill: parent
            active: win.shown === "notifs" && box.visible
            sourceComponent: SerpNotifPanel {
                screenName: win.screenName
                progress: win.progress
            }
        }
        Loader {
            anchors.fill: parent
            active: win.shown === "media" && box.visible
            sourceComponent: SerpMediaPanel {
                screenName: win.screenName
                progress: win.progress
            }
        }
        Loader {
            anchors.fill: parent
            active: win.shown === "net" && box.visible
            sourceComponent: SerpNetPanel {
                screenName: win.screenName
                progress: win.progress
                tab: Serp.panelTab || "wifi"
            }
        }
        Loader {
            anchors.fill: parent
            active: win.shown === "sound" && box.visible
            sourceComponent: SerpSoundPanel {
                screenName: win.screenName
                progress: win.progress
            }
        }
        Loader {
            anchors.fill: parent
            active: win.shown === "weather" && box.visible
            sourceComponent: SerpWeatherPanel {
                screenName: win.screenName
                progress: win.progress
            }
        }
        Loader {
            anchors.fill: parent
            active: win.shown === "eq" && box.visible
            sourceComponent: SerpEqPanel {
                screenName: win.screenName
                progress: win.progress
            }
        }
        Loader {
            anchors.fill: parent
            active: win.shown === "calendar" && box.visible
            sourceComponent: SerpCalendarPanel {
                screenName: win.screenName
                progress: win.progress
            }
        }
    }

    RightClickGuard {}
}
