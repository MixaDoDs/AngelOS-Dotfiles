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
    // Settings → Windows → Floating windows: every new window floats (a niri rule, ThemeExport;
    // Golden Gate's own switch is Config.mac.floating), and the open ones follow right away.
    // Off: the windows this floated go back to the columns; the ones floating before stay.
    readonly property bool floatAll: GoldenGate.on ? Config.mac.floating : Config.windows.floatAll
    property var _floatedByUs: []
    function setFloatAll(on) {
        if (GoldenGate.on)
            Config.mac.floating = on;
        else
            Config.windows.floatAll = on;
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
