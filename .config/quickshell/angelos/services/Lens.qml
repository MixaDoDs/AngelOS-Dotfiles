pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The lens at the pointer (modules/lens/LensOverlay): a round (or square) magnifier
// that follows the mouse, like KDE's Magnifier. niri has no zoom of its own and
// shows nobody the screen under a client's surface, so the lens magnifies a
// picture of the screen taken when it opens (grim); a click, R or Config.lens.refresh
// takes a new one (the lens hides for that frame). The rest of the screen stays live.
//   keys (niri, Settings → Keyboard and mouse): Mod+Alt+= closer (opens it),
//   Mod+Alt+- farther (closes at 1×), Mod+Alt+0 / Esc / right click close.
//   inside: wheel = zoom, Shift+wheel = size, left click / R = new picture.
// `angelos lens in|out|close|toggle|refresh [screen]`
Singleton {
    id: root

    property bool open: false
    property bool hidden: false              // for the frame a new picture is taken
    property string screenName: ""
    property real zoom: 2
    property int size: Config.lens.size
    property string snapUrl: ""
    property int shot: 0
    readonly property var steps: [1.5, 2, 3, 4, 6, 8, 12]
    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos"

    function cmd(c, screen) {
        if (liveMode || live)
            return liveCmd(c, screen);
        if (c === "in") {
            if (!open)
                show(screen);
            else
                zoom = steps.find(s => s > zoom + 0.01) || steps[steps.length - 1];
        } else if (c === "out") {
            if (!open)
                return;
            const lower = steps.filter(s => s < zoom - 0.01);
            if (!lower.length)
                close();
            else
                zoom = lower[lower.length - 1];
        } else if (c === "toggle") {
            open ? close() : show(screen);
        } else if (c === "refresh") {
            refresh();
        } else {
            close();
        }
    }
    // ---- the live lens (Config.lens.mode "live", the default): a glass beside the pointer
    // that shows the screen frame by frame — extras/lens-live, a quickshell process of its
    // own (ScreencopyView may crash Qt; then only the lens goes). It takes the mouse and
    // the keys itself; the niri keys reach it through a control file.
    readonly property bool liveMode: Config.lens.mode !== "snapshot"
    property bool live: false
    property int ctlSerial: 0
    readonly property string ctlFile: runtimeDir + "/lens-live.json"
    function liveCmd(c, screen) {
        if (c === "in")
            live ? tell("in") : liveShow(screen);
        else if (c === "toggle")
            live ? tell("close") : liveShow(screen);
        else if (c === "out") {
            if (live)
                tell("out");
        } else if (c !== "refresh" && live)
            tell("close");
    }
    function tell(what) {
        ctlSerial++;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s" "$3" > "$2.tmp" && mv -f "$2.tmp" "$2"', "sh", runtimeDir, ctlFile, JSON.stringify({
                "serial": ctlSerial,
                "cmd": what
            })]);
    }
    function liveShow(screen) {
        if (liveProc.running || Shell.dev)
            return;
        const name = screen || Niri.focusedOutput || (Quickshell.screens[0] ? Quickshell.screens[0].name : "");
        const here = Pointer.screen === name;
        tell("open");                       // the serial it starts from
        liveProc.environment = {
            "ANGELOS_LENS": JSON.stringify({
                "screen": name,
                "x": here ? Pointer.x : -1,
                "y": here ? Pointer.y : -1,
                "zoom": Math.max(1.5, Config.lens.zoom || 2),
                "size": Config.lens.size,
                "shape": Config.lens.shape,
                "crisp": Config.lens.crisp,
                "u": Theme.u,
                "accent": Theme.hex(Theme.accent),
                "edge": Theme.hex(Theme.edge),
                "selectText": Theme.hex(Theme.selectText),
                "font": Theme.fontBody,
                "fontPx": Theme.sizeTiny,
                "control": ctlFile
            })
        };
        screenName = name;
        live = true;
        liveProc.running = true;
    }
    Process {
        id: liveProc
        command: ["sh", "-c", 'exec "$(command -v qs || echo "$HOME/.local/bin/qs")" -p "$1"', "sh", Quickshell.shellDir + "/extras/lens-live"]
        onExited: root.live = false
    }

    function show(screen) {
        Achievements.note("lens.open");
        screenName = screen || Niri.focusedOutput || (Quickshell.screens[0] ? Quickshell.screens[0].name : "");
        zoom = Math.max(1.5, Config.lens.zoom || 2);
        size = Config.lens.size;
        capture(true);
    }
    function close() {
        open = false;
        hidden = false;
        refreshTimer.stop();
    }
    function refresh() {
        if (!open || grab.running)
            return;
        hidden = true;              // the lens leaves the picture for a frame
        afterHide.restart();
    }
    function wheel(steps_, shift) {
        if (shift)
            size = Math.max(120, Math.min(900, size + steps_ * 40));
        else
            cmd(steps_ > 0 ? "in" : "out");
    }
    Timer {
        id: afterHide
        interval: 60
        onTriggered: root.capture(false)
    }
    function capture(opening) {
        shot = (shot + 1) % 2;
        const file = runtimeDir + "/lens-" + shot + ".ppm";
        grab.opening = opening;
        grab.file = file;
        grab.command = ["sh", "-c", 'mkdir -p "$1" && grim -o "$2" -t ppm "$3"', "sh", runtimeDir, screenName, file];
        grab.running = true;
    }
    Process {
        id: grab
        property bool opening: false
        property string file: ""
        onExited: code => {
            root.hidden = false;
            if (code !== 0) {
                if (opening)
                    root.open = false;
                return;
            }
            // a fresh URL each time: Image caches by URL
            root.snapUrl = "file://" + file + "?" + Date.now();
            if (opening)
                root.open = true;
            if (Config.lens.refresh > 0)
                refreshTimer.restart();
        }
    }
    Timer {
        id: refreshTimer
        interval: Math.max(1, Config.lens.refresh) * 1000
        onTriggered: root.refresh()
    }

    // ---- the niri keys (cfg/angelos-windows.kdl through window-config.py, like Alt+Tab) ----
    property bool niriKeys: false
    property bool niriRead: false
    property string log: ""
    function sync() {
        if (!Shell.dev && Config.ready && niriRead && niriKeys !== !!Config.lens.keys && !writer.running) {
            writer.command = ["python3", Quickshell.shellDir + "/scripts/window-config.py", JSON.stringify({
                    "lens": !!Config.lens.keys
                })];
            writer.running = true;
        }
    }
    readonly property bool wantKeys: !!Config.lens.keys
    onWantKeysChanged: sync()
    Connections {
        target: Config
        function onReadyChanged() {
            root.sync();
        }
    }
    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/window-config.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.niriKeys = !!JSON.parse(text).lens;
                    root.niriRead = true;
                    root.sync();
                } catch (e) {}
            }
        }
    }
    Process {
        id: writer
        stderr: StdioCollector {
            onStreamFinished: root.log = text.trim()
        }
        onExited: reader.running = true
    }
}
