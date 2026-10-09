pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Monitor configuration through niri: live apply via `niri msg output`, persist to monitor.kdl.
// The main screen: angelOS's own (Config.system.primaryScreen → Shell.primaryScreen), and
// niri focuses it at login (`focus-at-startup`, scripts/primary-output.py).
Singleton {
    id: root

    property var niriFocused: []      // outputs with focus-at-startup in niri's config
    property string primaryLog: ""
    // "" = automatic (the widest screen); niri is left as it is then
    function setPrimary(name) {
        Config.system.primaryScreen = name;
        primaryLog = "";
        if (!name || Shell.dev)
            return;
        primary.command = ["python3", Quickshell.shellDir + "/scripts/primary-output.py", "set", name];
        primary.running = true;
    }
    Process {
        id: primary
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (r.error)
                        root.primaryLog = I18n.t("niri: ", "niri: ") + r.error;
                    else if (r.focused)
                        root.niriFocused = r.focused;
                    else if (r.ok)
                        root.primaryLog = r.changed.length ? I18n.t("niri теперь фокусирует его при входе (", "niri now focuses it at login (") + r.changed.join(", ") + ")" : "";
                } catch (e) {}
            }
        }
        onExited: if (command[2] === "set")
            Qt.callLater(root.primaryStatus)
    }
    function primaryStatus() {
        if (primary.running)
            return;
        primary.command = ["python3", Quickshell.shellDir + "/scripts/primary-output.py", "status"];
        primary.running = true;
    }

    readonly property string monitorFile: Config.home + "/.config/niri/monitor.kdl"
    property var outputs: ({})        // name -> niri output json
    property var draft: ({})          // name -> {mode, scale, transform, x, y, vrr, off}
    property var live: ({})           // the same as niri runs it now (the last query)
    property string log: ""
    property bool busy: applier.running || saver.running

    readonly property var transforms: [
        {
            "label": I18n.t("обычная", "Normal"),
            "value": "normal"
        },
        {
            "label": "90°",
            "value": "90"
        },
        {
            "label": "180°",
            "value": "180"
        },
        {
            "label": "270°",
            "value": "270"
        },
        {
            "label": I18n.t("зеркально", "Flipped"),
            "value": "flipped"
        },
        {
            "label": I18n.t("зеркально 90°", "Flipped 90°"),
            "value": "flipped-90"
        },
        {
            "label": I18n.t("зеркально 180°", "Flipped 180°"),
            "value": "flipped-180"
        },
        {
            "label": I18n.t("зеркально 270°", "Flipped 270°"),
            "value": "flipped-270"
        }
    ]

    // how the monitor stands: the turn without the mirror, and the mirror on its own
    readonly property var turns: [
        {
            "label": I18n.t("Как обычно", "Normal"),
            "hint": I18n.t("горизонтально", "landscape"),
            "value": "0"
        },
        {
            "label": I18n.t("На боку ↻", "On its side ↻"),
            "hint": I18n.t("90°, вертикально", "90°, portrait"),
            "value": "90"
        },
        {
            "label": I18n.t("Вверх ногами", "Upside down"),
            "hint": "180°",
            "value": "180"
        },
        {
            "label": I18n.t("На боку ↺", "On its side ↺"),
            "hint": I18n.t("270°, вертикально", "270°, portrait"),
            "value": "270"
        }
    ]
    function turnOf(t) {
        const m = String(t || "normal").match(/(\d+)$/);
        return m ? m[1] : "0";
    }
    function mirroredOf(t) {
        return String(t || "").startsWith("flipped");
    }
    function transformOf(turn, mirrored) {
        return turn === "0" ? (mirrored ? "flipped" : "normal") : (mirrored ? "flipped-" : "") + turn;
    }
    // turn (or mirror) a monitor right away; it comes back unless kept (keep) within 15 s
    function turn(name, transform) {
        set(name, "transform", transform);
        apply();
    }

    function transformFromJson(t) {
        return ({
                "Normal": "normal",
                "90": "90",
                "180": "180",
                "270": "270",
                "_90": "90",
                "_180": "180",
                "_270": "270",
                "Flipped": "flipped",
                "Flipped90": "flipped-90",
                "Flipped180": "flipped-180",
                "Flipped270": "flipped-270"
            })[t] || "normal";
    }
    function modeString(m) {
        return m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3);
    }
    function modeLabel(m) {
        return m.width + "×" + m.height + " @ " + (m.refresh_rate / 1000).toFixed(2) + I18n.t(" Гц", " Hz") + (m.is_preferred ? " ★" : "");
    }

    function refresh() {
        query.running = true;
        primaryStatus();
    }
    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text);
                    root.outputs = o;
                    const d = {};
                    for (const name in o) {
                        const out = o[name];
                        const cur = out.current_mode !== null && out.current_mode !== undefined ? out.modes[out.current_mode] : null;
                        d[name] = {
                            "mode": cur ? root.modeString(cur) : "",
                            "scale": out.logical ? out.logical.scale : 1,
                            "transform": out.logical ? root.transformFromJson(out.logical.transform) : "normal",
                            "x": out.logical ? out.logical.x : 0,
                            "y": out.logical ? out.logical.y : 0,
                            "vrr": !!out.vrr_enabled,
                            "off": !out.logical
                        };
                    }
                    root.draft = d;
                    root.live = JSON.parse(JSON.stringify(d));
                } catch (e) {
                    root.log = I18n.t("не удалось прочитать niri outputs: ", "Could not read niri outputs: ") + e;
                }
            }
        }
    }

    function set(name, key, value) {
        const d = Object.assign({}, draft);
        d[name] = Object.assign({}, d[name]);
        d[name][key] = value;
        draft = d;
    }

    // live apply (not persisted). A turned, switched off or re-moded screen may be unreadable:
    // it comes back as it was in 15 s unless kept (keep) — the Windows way
    property var undo: null           // the layout before such a change, until kept or put back
    property int confirmLeft: 0
    property bool reverting: false
    function apply() {
        const risky = Object.keys(draft).some(n => {
            const a = draft[n], b = live[n];
            return b && (a.transform !== b.transform || a.mode !== b.mode || a.scale !== b.scale || a.off !== b.off);
        });
        if (risky && !undo)
            undo = JSON.parse(JSON.stringify(live));
        _run();
        if (undo) {
            confirmLeft = 15;
            confirmTimer.restart();
        }
    }
    function keep() {
        undo = null;
        confirmLeft = 0;
        confirmTimer.stop();
    }
    function revert() {
        if (!undo)
            return;
        draft = undo;
        keep();
        reverting = true;
        _run();
    }
    Timer {
        id: confirmTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.confirmLeft--;
            if (root.confirmLeft <= 0)
                root.revert();
        }
    }
    function _run() {
        const cmds = [];
        for (const name in draft) {
            const d = draft[name];
            const q = s => "'" + String(s).replace(/'/g, "'\\''") + "'";
            if (d.off) {
                cmds.push("niri msg output " + q(name) + " off");
                continue;
            }
            cmds.push("niri msg output " + q(name) + " on");
            if (d.mode)
                cmds.push("niri msg output " + q(name) + " mode " + q(d.mode));
            cmds.push("niri msg output " + q(name) + " scale " + q(d.scale));
            cmds.push("niri msg output " + q(name) + " transform " + q(d.transform));
            cmds.push("niri msg output " + q(name) + " position set " + Math.round(d.x) + " " + Math.round(d.y));
            cmds.push("niri msg output " + q(name) + " vrr " + (d.vrr ? "on" : "off"));
        }
        applier.command = ["sh", "-c", cmds.join(" && ")];
        applier.running = true;
    }

    Process {
        id: applier
        stderr: StdioCollector {
            onStreamFinished: {
                root.log = text ? text : root.reverting ? I18n.t("вернула как было ♡", "Put back as it was ♡") : I18n.t("применено ♡ (до перезапуска niri — сохрани, чтобы запомнить)", "Applied ♡ Save to config to keep changes after restarting niri.");
                root.reverting = false;
            }
        }
        onExited: refreshTimer.restart()
    }
    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: root.refresh()
    }

    // persist through scripts/niri_outputs.py: monitor.kdl with "Make Model Serial" names and the
    // exact modes niri lists, `include "monitor.kdl"` moved first in config.kdl when another block
    // would win (niri uses the first matching one), checked on a staged copy, backed up first
    function save() {
        saver.command = ["python3", Quickshell.shellDir + "/scripts/niri_outputs.py", "save", JSON.stringify({
                "outputs": draft,
                "primary": Config.system.primaryScreen || ""
            })];
        saver.running = true;
    }
    function noteText(n) {
        if (n.code === "include")
            return I18n.t("config.kdl теперь подключает monitor.kdl первым — иначе niri брал другой блок и сбрасывал герцы", "config.kdl now includes monitor.kdl first; before, niri used another block and dropped the refresh rate");
        if (n.code === "ignored")
            return n.output + I18n.t(": блок в ", ": the block in ") + n.files.join(", ") + I18n.t(" больше не действует (niri берёт первый)", " no longer applies (niri uses the first one)");
        if (n.code === "mode")
            return n.output + ": " + n.from + " → " + n.to + I18n.t(" (точная частота из списка niri)", " (the exact rate niri lists)");
        return "";
    }
    Process {
        id: saver
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (r.error)
                        root.log = I18n.t("не сохранено: ", "Not saved: ") + r.error;
                    else
                        root.log = [I18n.t("сохранено ♡ переживёт перезагрузку. Бэкап: ", "Saved ♡ it survives a reboot. Backup: ") + r.backup].concat(r.notes.map(root.noteText).filter(s => s)).join("\n");
                } catch (e) {
                    root.log = text.trim();
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("niri_outputs.py: " + text.trim())
        }
        onExited: Qt.callLater(root.primaryStatus)
    }
}
