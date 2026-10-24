pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root
    property int gaps: 16
    property string center: "never"
    property string defaultWidth: ""      // "proportion 0.5" | "fixed 1200" | "" (niri default)
    property var presets: []              // Mod+R cycle
    property string frame: "focus"        // focus (niri's ring around the focused one) | all (a pixel border on every window) | none
    property var apps: ({})               // app-id -> width
    property var taskmgr: null            // task manager floating rule as written (window-config.py)
    property bool loaded: false
    property string log: ""

    // "proportion 0.5" -> "50%", "fixed 900" -> "900" (niri msg action set-window-width)
    function niriArg(w) {
        const m = String(w).match(/^(proportion|fixed)\s+([\d.]+)$/);
        if (!m)
            return "";
        return m[1] === "proportion" ? Math.round(parseFloat(m[2]) * 1000) / 10 + "%" : String(Math.round(parseFloat(m[2])));
    }
    function label(w) {
        const m = String(w || "").match(/^(proportion|fixed)\s+([\d.]+)$/);
        if (!m)
            return I18n.t("как у niri", "niri default");
        if (m[1] === "fixed")
            return m[2] + " px";
        const p = parseFloat(m[2]);
        const known = {
            "0.25": "1/4",
            "0.33333": "1/3",
            "0.5": "1/2",
            "0.66667": "2/3",
            "0.75": "3/4",
            "1": I18n.t("вся ширина", "full")
        };
        return known[String(Math.round(p * 100000) / 100000)] || Math.round(p * 100) + "%";
    }
    readonly property var choices: [
        {
            "label": "1/4",
            "value": "proportion 0.25"
        },
        {
            "label": "1/3",
            "value": "proportion 0.33333"
        },
        {
            "label": "1/2",
            "value": "proportion 0.5"
        },
        {
            "label": "2/3",
            "value": "proportion 0.66667"
        },
        {
            "label": "3/4",
            "value": "proportion 0.75"
        },
        {
            "label": I18n.t("вся", "full"),
            "value": "proportion 1.0"
        }
    ]

    // remember a width for an app and resize its open windows right away
    function setAppWidth(appId, width) {
        const a = {};
        a[appId] = width || null;
        save({
            "apps": a
        });
        if (width)
            applyLive(appId, width);
    }
    function applyLive(appId, width) {
        const arg = niriArg(width);
        if (!arg)
            return;
        for (const w of Niri.windows.filter(w => w.app_id === appId && !w.is_floating))
            Quickshell.execDetached(["niri", "msg", "action", "set-window-width", "--id", String(w.id), arg]);
    }
    // Settings → Windows → Desktop: every new window floats (a niri rule, ThemeExport), and the
    // open ones follow right away. Off (the Strip): the windows this floated go back to the
    // columns; the ones floating before stay. On angel-niri the same switch is the stacking mode
    // (niri floats the windows itself, gives them title bars and puts the columns back after);
    // Mod+Ctrl+Shift+M and the bar's mode button flip it too. Golden Gate is always Desktop and
    // leaves the switch alone, so the pixel skins get back what they had.
    readonly property bool floatAll: GoldenGate.on || Config.windows.floatAll
    // the OSD and the first-time hint (modules/osd/Osd.qml): a flip by hand, not a skin change
    signal modeFlipped(bool desktop, bool locked)
    property var _floatedByUs: []
    function setFloatAll(on) {
        if (GoldenGate.on) {
            modeFlipped(true, true);
            return;
        }
        if (Config.windows.floatAll === on)
            return;
        Config.windows.floatAll = on;
        modeFlipped(on, false);
        if (Niri.nativeMinimize)
            return;
        if (on) {
            const ids = Niri.windows.filter(w => !w.is_floating).map(w => w.id);
            _floatedByUs = ids;
            for (const id of ids)
                Quickshell.execDetached(["niri", "msg", "action", "move-window-to-floating", "--id", String(id)]);
        } else {
            const open = Niri.windows.map(w => w.id);
            for (const id of _floatedByUs.filter(i => open.includes(i)))
                Quickshell.execDetached(["niri", "msg", "action", "move-window-to-tiling", "--id", String(id)]);
            _floatedByUs = [];
        }
    }
    // write the task manager rule only when it differs from what is in the file
    property var _pendingTaskmgr: undefined
    function setTaskManager(spec) {
        if (!loaded) {
            _pendingTaskmgr = spec;
            return;
        }
        if (JSON.stringify(spec || null) === JSON.stringify(taskmgr || null))
            return;
        if (writer.running) {
            _pendingTaskmgr = spec;
            return;
        }
        _pendingTaskmgr = undefined;
        save({
            "taskmgr": spec
        });
    }
    // angel-niri (our fork, Niri.nativeMinimize): square windows get pixel staircase corners —
    // two steps of one 2 px art pixel, the corner the GTK and Qt themes draw (templates/niri.kdl).
    // Not in Golden Gate, whose windows round like a Mac's
    readonly property bool pixelCorners: Niri.nativeMinimize && Config.windows.pixelCorners && !GoldenGate.on
    function applyCorners() {
        if (Niri.nativeMinimize)
            Niri.action("SetPixelCorners", {
                "pixel": pixelCorners ? 2 : 0,
                "steps": 2
            });
    }
    onPixelCornersChanged: applyCorners()
    // angel-niri: window shadows as dithered 2 px dots, the focused one in the accent (its glow);
    // colours and softness are templates/niri.kdl's `shadow` (no `on` there: stock niri draws none)
    readonly property bool pixelShadow: Niri.nativeMinimize && Config.windows.pixelShadow && !GoldenGate.on
    function applyShadow() {
        if (Niri.nativeMinimize)
            Niri.action("SetPixelShadow", {
                "pixel": pixelShadow ? 2 : 0
            });
    }
    onPixelShadowChanged: applyShadow()
    // angel-niri: the overview in pixels — sharp thumbnails, a pixel frame and
    // the desk's number in the title font (its native size × the art pixel) by each workspace
    readonly property bool pixelOverview: Niri.nativeMinimize && Config.windows.pixelOverview && !GoldenGate.on
    readonly property string overviewFont: Theme.fontTitle + " " + (Theme.fontNative[Theme.fontTitle] || 9) * Theme.u
    function applyOverview() {
        if (Niri.nativeMinimize)
            Niri.action("SetPixelOverview", {
                "pixel": pixelOverview ? 2 : 0,
                "font": overviewFont
            });
    }
    onPixelOverviewChanged: applyOverview()
    // angel-niri: a sparse grid of dark dots over every window but the focused one
    readonly property bool inactiveDim: Niri.nativeMinimize && Config.windows.inactiveDim && !GoldenGate.on
    function applyDim() {
        if (Niri.nativeMinimize)
            Niri.action("SetInactiveDim", {
                "pixel": inactiveDim ? 2 : 0,
                "alpha": 0.5,
                "outputs": dimOutputs
            });
    }
    onInactiveDimChanged: applyDim()
    // only on these monitors (the others are for work); empty: every one
    readonly property var dimOutputs: Config.windows.dimOutputs || []
    onDimOutputsChanged: applyDim()
    // angel-niri: a program pinned by hand opens its first window on its monitor and desk, and the
    // view goes there (Settings → Windows → Program places, a window's right-click menu). niri
    // keeps the pins itself; off, they are kept but not used
    readonly property bool remember: Niri.nativeMinimize && Config.windows.remember
    function applyRemember() {
        if (Niri.nativeMinimize)
            Niri.action("SetRememberWindows", {
                "on": remember
            });
    }
    onRememberChanged: applyRemember()
    property var places: ({})            // app-id -> {output, workspace (a name or null), workspace_idx (from 0), floating}
    // where a window is now: {output, idx (from 1), name, floating}; null when minimized
    function placeOf(w) {
        const ws = w ? Niri.workspaceById(w.workspace_id) : null;
        return ws && !Niri.isHidden(ws) ? {
            "output": ws.output,
            "idx": ws.idx,
            "name": ws.name || "",
            "floating": !!w.is_floating
        } : null;
    }
    // pin a program's place (as placeOf gives it); null forgets it
    function setPlace(appId, p) {
        const args = {
            "app_id": appId
        };
        const all = Object.assign({}, places);
        if (p) {
            Object.assign(args, {
                "output": p.output,
                "workspace": p.idx,
                "workspace_name": p.name || null,
                "floating": !!p.floating
            });
            all[appId] = {
                "output": p.output,
                "workspace": p.name || null,
                "workspace_idx": p.idx - 1,
                "floating": !!p.floating
            };
        } else {
            delete all[appId];
        }
        Niri.action("SetAppPlace", args);
        places = all;
    }
    // a pin as placeOf gives it
    function placeFor(appId) {
        const s = places[appId];
        return s ? {
            "output": s.output,
            "idx": s.workspace_idx + 1,
            "name": s.workspace || "",
            "floating": !!s.floating
        } : null;
    }
    FileView {
        path: Config.home + "/.local/state/angel-niri/windows.json"
        printErrors: false
        onLoaded: {
            try {
                root.places = JSON.parse(text()).pins || {};
            } catch (e) {
                root.places = {};
            }
        }
    }
    // angel-niri: a minimized window goes with the close animation (Golden Gate flies it into
    // the Dock instead)
    readonly property bool minimizeFade: Niri.nativeMinimize && !GoldenGate.on && Minimize.flightMs === 0
    function applyMinimizeFade() {
        if (Niri.nativeMinimize)
            Niri.action("SetMinimizeFade", {
                "on": minimizeFade
            });
    }
    onMinimizeFadeChanged: applyMinimizeFade()
    // angel-niri: the clipboard outlives the program it was copied from (niri keeps a copy in memory)
    readonly property bool clipboardKeep: Niri.nativeMinimize && Config.windows.clipboardKeep
    function applyClipboardKeep() {
        if (Niri.nativeMinimize)
            Niri.action("SetClipboardKeep", {
                "on": clipboardKeep
            });
    }
    onClipboardKeepChanged: applyClipboardKeep()
    // angel-niri: throwing floating windows — they fly on after a drag, bounce, squash, sway
    readonly property var windowThrow: {
        const w = Config.windows;
        const on = Niri.nativeMinimize && w.throwOn;
        return {
            "strength": on ? w.throwStrength : 0,
            "bounce": on ? w.throwBounce : 0,
            "squash": on ? w.throwSquash : 0,
            "wobble": on ? w.throwWobble : 0
        };
    }
    function applyThrow() {
        if (Niri.nativeMinimize)
            Niri.action("SetWindowThrow", windowThrow);
    }
    onWindowThrowChanged: applyThrow()
    onOverviewFontChanged: {
        applyOverview();
        applyStacking();
    }
    function applyStacking() {
        if (Niri.nativeMinimize)
            Niri.action("SetStackingMode", {
                "on": floatAll,
                "title_font": overviewFont,
                // the pixel bars: "light" in a light heaven, the inactive ones pale instead of dark
                "title_style": GoldenGate.on ? "mac" : !Theme.dark && !Angel.demon ? "light" : "win98"
            });
    }
    onFloatAllChanged: applyStacking()
    Connections {
        target: Theme
        function onDarkChanged() {
            root.applyStacking();
        }
    }
    Connections {
        target: Angel
        function onDemonChanged() {
            root.applyStacking();
        }
    }
    // the title bars' look follows the skin even when the mode stays; the OSD says what the
    // windows are now (not while the shell starts and the skin comes up)
    Connections {
        target: GoldenGate
        function onOnChanged() {
            root.applyStacking();
            if (root._settled)
                root.modeFlipped(root.floatAll, GoldenGate.on);
        }
    }
    property bool _settled: false
    Timer {
        interval: 5000
        running: true
        onTriggered: root._settled = true
    }
    Connections {
        target: Niri
        function onMinimizeProbedChanged() {
            root.applyCorners();
            root.applyShadow();
            root.applyOverview();
            root.applyDim();
            root.applyRemember();
            root.applyMinimizeFade();
            root.applyThrow();
            root.applyClipboardKeep();
            root.applyStacking();
        }
    }

    readonly property bool busy: writer.running
    function save(changes) {
        if (writer.running)
            return;
        writer.command = ["python3", Quickshell.shellDir + "/scripts/window-config.py", JSON.stringify(changes)];
        writer.running = true;
    }
    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/window-config.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text);
                    root.gaps = v.gaps;
                    root.center = v.center;
                    root.defaultWidth = v.defaultWidth || "";
                    root.presets = v.presets || [];
                    root.frame = v.frame || "focus";
                    root.apps = v.apps || {};
                    root.taskmgr = v.taskmgr || null;
                    root.loaded = true;
                    if (root._pendingTaskmgr !== undefined)
                        root.setTaskManager(root._pendingTaskmgr);
                } catch (e) {
                    root.log = String(e);
                }
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: root.log = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.log = text.trim()
        }
        onExited: reader.running = true
    }
}
