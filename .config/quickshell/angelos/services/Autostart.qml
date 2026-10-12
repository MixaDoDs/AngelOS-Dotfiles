pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Apps started at login (Settings → Apps → Autostart, `angelos autostart`): the freedesktop
// entries of ~/.config/autostart over the system's (scripts/autostart.py). The session's own
// systemd starts them, so they come up with or without angelOS.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/autostart.py"
    property var entries: []        // [{id, name, icon, exec, on, source, system, fits}]
    property bool works: true       // the session starts autostart entries at all
    property bool loaded: false
    property string error: ""       // why the last change didn't happen
    readonly property var mine: entries.filter(e => !e.system)
    readonly property var system: entries.filter(e => e.system && e.fits)
    property var _queue: []

    function refresh() {
        if (!lister.running)
            lister.running = true;
    }
    function act(args) {
        _queue = _queue.concat([args]);
        pump();
    }
    function pump() {
        if (runner.running || !_queue.length)
            return;
        const args = _queue[0];
        _queue = _queue.slice(1);
        error = "";
        runner.command = ["python3", script].concat(args);
        runner.running = true;
    }
    function has(desktopId) {
        const fid = desktopId.endsWith(".desktop") ? desktopId : desktopId + ".desktop";
        return entries.some(e => e.id === fid && e.on);
    }
    function add(desktopId) {
        act(["add", desktopId]);
    }
    function addCommand(name, command) {
        if (String(name).trim() && String(command).trim())
            act(["add-command", String(name).trim(), String(command).trim()]);
    }
    // the switch answers at once; the list is read again when the file is written
    function setOn(id, on) {
        entries = entries.map(e => e.id !== id ? e : Object.assign({}, e, {
                "on": on
            }));
        act([on ? "on" : "off", id]);
    }
    function remove(id) {
        entries = entries.filter(e => e.id !== id || e.source !== "user");
        act(["remove", id]);
    }

    Process {
        id: lister
        command: ["python3", root.script, "list"]
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.entries = d.entries || [];
                    root.works = d.works !== false;
                    root.loaded = true;
                } catch (e) {}
            }
        }
    }
    Process {
        id: runner
        stderr: StdioCollector {
            id: runnerErr
        }
        onExited: code => {
            if (code !== 0)
                root.error = runnerErr.text.trim().split("\n").pop() || "autostart.py " + code;
            if (root._queue.length)
                root.pump();
            else
                lister.running = true;
        }
    }
}
