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

    // live apply (not persisted)
    function apply() {
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
            onStreamFinished: root.log = text ? text : I18n.t("применено ♡ (до перезапуска niri — сохрани, чтобы запомнить)", "Applied ♡ Save to config to keep changes after restarting niri.")
        }
        onExited: refreshTimer.restart()
    }
    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: root.refresh()
    }

    function kdl() {
        let out = "// Generated by angelOS on " + new Date().toISOString().slice(0, 19).replace("T", " ") + ".\n// Edit through angelOS → Настройки → Экран.\n";
        for (const name of Object.keys(draft).sort()) {
            const d = draft[name];
            out += '\noutput "' + name + '" {\n';
            if (d.off) {
                out += "    off\n}\n";
                continue;
            }
            if (d.mode)
                out += '    mode "' + d.mode + '"\n';
            out += "    scale " + Number(d.scale).toFixed(2).replace(/0$/, "") + "\n";
            out += '    transform "' + d.transform + '"\n';
            out += "    position x=" + Math.round(d.x) + " y=" + Math.round(d.y) + "\n";
            if (d.vrr)
                out += "    variable-refresh-rate\n";
            if (name === Config.system.primaryScreen)
                out += "    focus-at-startup\n";
            out += "}\n";
        }
        return out;
    }

    // persist: backup into a fresh timestamped folder, write, validate, roll back on failure
    function save() {
        saver.command = ["sh", "-c", 'set -e; f="$1"; b="$2/backups/$(date +%Y%m%d-%H%M%S)-monitor"; mkdir -p "$b"; [ -f "$f" ] && cp -n "$f" "$b/"; printf "%s" "$3" > "$f.angelos-new"; cp "$f.angelos-new" "$f"; rm -f "$f.angelos-new"; if ! niri validate >/dev/null 2>"$b/validate.log"; then cp "$b/monitor.kdl" "$f"; echo "niri validate не прошёл, откатил: $(cat "$b/validate.log")" >&2; exit 1; fi; echo "сохранено, бэкап: $b"', "sh", monitorFile, Config.stateDir, kdl()];
        saver.running = true;
    }
    Process {
        id: saver
        stdout: StdioCollector {
            onStreamFinished: if (text)
                root.log = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (text)
                root.log = text.trim()
        }
    }
}
