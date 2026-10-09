pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// The demon punched the desktop (Angel.punched): where, what broke and how far it has spread.
// Drawn by modules/y2k/ScreenCracks inside the wallpaper's own surface (the backdrop), so the
// glass stays exactly where her fist landed: the same screen, the same corner, through workspace
// switches (niri slides every Background/Bottom layer surface with the workspace, except the one
// placed within the backdrop), the overview, widgets resizing and her moving to another screen.
// The spot is chosen once per punch — the corner square that overlaps the least of the bar, the
// desktop widgets and her — and kept until the glass falls out (Angel.shattered).
// Settings → Y2K → Angel or demon: cracks full | weak | off, and what she breaks
// (Config.y2k.breakage): circle (the default: one of the circle's own set, story/circles.json →
// breakage — Limbo's fog, Treachery's frost…) | any one kind always (HellLook.breakageKinds:
// glass, tv, burn, claws, sigil, fog, whirl, ooze, coin, ripple, spatter, pitch, frost) |
// random (any kind, another one each punch) — all but the glass drawn by shaders/breakage.frag.
// A new circle under the glass breaks it again in its own way. Hidden under fullscreen windows
// and on streamed screens.
Singleton {
    id: root

    property string screenName: ""
    property bool on: false                  // cracks on the glass
    property bool falling: false             // the angel is back: shards drop out
    property real grow: 0                    // 0..1 how far the cracks have spread
    property real fall: 0                    // 0..1 of the drop
    property int seed: 1
    readonly property bool weak: Config.y2k.cracks === "weak"
    // what this punch broke: glass | tv | burn | claws | sigil
    readonly property var kinds: HellLook.breakageKinds
    property string kind: "glass"
    // the next punch breaks this kind whatever the settings say (the debug panel), once
    property string forceKind: ""
    // one of `from`, not the one there is now if there is another
    function oneOf(from) {
        const others = from.filter(k => k !== kind);
        const pool = others.length ? others : from;
        return pool[Math.floor(Math.random() * pool.length)];
    }
    function pickKind() {
        const b = Config.y2k.breakage || "circle";
        if (b === "random")
            return oneOf(kinds);
        if (b === "circle")
            return oneOf(HellLook.breakage);
        return kinds.includes(b) ? b : "glass";
    }
    // a new choice in the settings shows at once
    Connections {
        target: Config.y2k
        function onBreakageChanged() {
            if (root.on && !root.falling && Config.y2k.breakage !== "random")
                root.kind = root.pickKind();
        }
    }
    // a new circle under the glass: it breaks in that circle's way (the same corner)
    Connections {
        target: HellLook
        function onCircleChanged() {
            if (root.on && !root.falling && (Config.y2k.breakage || "circle") === "circle" && !HellLook.breakage.includes(root.kind)) {
                root.kind = root.pickKind();
                root.seed = Math.floor(Math.random() * 100000) + 1;
                root.grow = 0;
                anim.restart();
            }
        }
    }
    // older settings: "glass" was the default before the circles had their own marks — it
    // becomes "circle" once (a later "glass" is the player's own choice and stays). A beat
    // after Config is ready: the file's values land in the settings just after `ready`
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                migrateSoon.restart();
        }
    }
    Component.onCompleted: if (Config.ready)
        migrateSoon.restart()
    Timer {
        id: migrateSoon
        interval: 400
        onTriggered: root.migrate()
    }
    function migrate() {
        if (!Config.ready || Config.y2k.breakageByCircle)
            return;
        if (Config.y2k.breakage === "glass")
            Config.y2k.breakage = "circle";
        Config.y2k.breakageByCircle = true;
    }
    // the shader's clock for the marks that keep moving (5 steps a second, 10 fps inside the
    // shader's own time); the still ones spread and stop
    property real clock: 0
    Timer {
        running: root.wanted && HellLook.breakageLiving.includes(root.kind) && !Motion.still
        interval: 200
        repeat: true
        onTriggered: root.clock = (root.clock + 0.2) % 1000
    }

    // ---- where: fixed at the punch ----
    property string corner: "tl"             // tl | tr | bl | br
    property int insetTop: 0                 // the bar's room above / below the square then
    property int insetBottom: 0
    readonly property bool atTop: corner[0] === "t"
    readonly property bool atLeft: corner[1] === "l"
    // where her fist landed in that square: near the screen's corner
    readonly property point impact: Qt.point(atLeft ? 0.14 : 0.86, atTop ? 0.08 : 0.92)
    function sideOn(scr) {
        return Math.round((scr ? Math.min(scr.width, scr.height) : 800) * (weak ? 0.24 : 0.36));
    }
    function place() {
        const scr = Shell.screenByName(screenName);
        const bar = Theme.u * 24;
        insetTop = BarLayout.edge === "top" ? bar : 0;
        insetBottom = BarLayout.edge === "bottom" ? bar : 0;
        if (!scr) {
            corner = "tl";
            return;
        }
        const W = scr.width, H = scr.height;
        const side = sideOn(scr);
        const busy = [];
        // the bar's strip, on whichever edge it stands (Config.bar.edge)
        busy.push(({
                "bottom": [0, H - bar, W, bar],
                "top": [0, 0, W, bar],
                "left": [0, 0, bar, H],
                "right": [W - bar, 0, bar, H]
            })[BarLayout.edge]);
        if (Angel.screenName === screenName)
            busy.push([W - Theme.u * 176, H - Theme.u * 160, Theme.u * 176, Theme.u * 160]);
        const faces = DesktopWidgets.faces;
        for (const w of DesktopWidgets.widgets) {
            const f = faces[w.uid];
            if (f && DesktopWidgets.screenOf(w) === screenName && f.width > 0)
                busy.push([f.x, f.y, f.width, f.height]);
        }
        const overlap = (a, b) => Math.max(0, Math.min(a[0] + a[2], b[0] + b[2]) - Math.max(a[0], b[0])) * Math.max(0, Math.min(a[1] + a[3], b[1] + b[3]) - Math.max(a[1], b[1]));
        let best = "tl", bestArea = Infinity;
        // ties go in this order
        for (const c of ["tl", "tr", "bl", "br"]) {
            const top = c[0] === "t", leftSide = c[1] === "l";
            const y = top ? insetTop : H - side - insetBottom;
            const sq = [leftSide ? 0 : W - side, y, side, side];
            const area = busy.reduce((sum, b) => sum + overlap(sq, b), 0);
            if (area < bestArea) {
                bestArea = area;
                best = c;
            }
        }
        corner = best;
    }
    // the square on a screen of this size: {x, y, side} in the screen's pixels
    function rect(scr) {
        const side = sideOn(scr);
        const W = scr ? scr.width : side, H = scr ? scr.height : side;
        return {
            "x": atLeft ? 0 : W - side,
            "y": atTop ? insetTop : H - side - insetBottom,
            "side": side
        };
    }
    readonly property bool wanted: on && Config.y2k.cracks !== "off" && screenName !== "" && StreamMode.effectsOn(screenName) && !Shell.fullscreenOn(screenName) && !Shell.locked

    Connections {
        target: Angel
        function onPunched(name, sound) {
            root.screenName = name;
            root.seed = Math.floor(Math.random() * 100000) + 1;
            root.kind = root.kinds.includes(root.forceKind) ? root.forceKind : root.pickKind();
            root.forceKind = "";
            root.place();
            root.falling = false;
            root.fall = 0;
            root.grow = 0;
            root.on = true;
            anim.restart();
            if (sound)
                Sounds.play(sound);
        }
        function onShattered(name) {
            root.shatter();
        }
        // the character changed some other way (settings): the glass goes with her
        function onDemonChanged() {
            if (!Angel.demon && !Angel.transition)
                root.on = false;
        }
        // the angel is back but the glass could not fall out where she is (stream mode, a
        // fullscreen game): it must not stay in heaven
        function onTransitionChanged() {
            if (!Angel.transition && !Angel.demon)
                leftover.restart();
        }
    }
    Timer {
        id: leftover
        interval: 1600
        onTriggered: if (root.on && !root.falling && !Angel.demon)
            root.on = false
    }
    function shatter() {
        if (!on || falling)
            return;
        falling = true;
        anim.restart();
    }
    // stepped like everything pixel: 12 fps
    Timer {
        id: anim
        interval: 83
        repeat: true
        onTriggered: {
            if (root.falling) {
                root.fall = Math.min(1, root.fall + interval / 450);
                if (root.fall >= 1) {
                    stop();
                    root.on = false;
                    root.falling = false;
                }
            } else {
                root.grow = Math.min(1, root.grow + interval / 500);
                if (root.grow >= 1)
                    stop();
            }
        }
    }
}
