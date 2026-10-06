pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Keyboard / mouse settings living in niri's cfg/input.kdl. Edits are line-level so comments survive.
Singleton {
    id: root

    readonly property string file: Config.home + "/.config/niri/cfg/input.kdl"
    property string text: ""
    property string log: ""
    readonly property bool loaded: text !== ""

    readonly property string layouts: match(/^\s*layout\s+"([^"]*)"/m) || "us"
    readonly property string options: match(/^\s*options\s+"([^"]*)"/m) || ""
    readonly property int repeatDelay: parseInt(match(/^\s*repeat-delay\s+(\d+)/m) || "600")
    readonly property int repeatRate: parseInt(match(/^\s*repeat-rate\s+(\d+)/m) || "25")
    readonly property bool numlock: /^\s*numlock\b/m.test(block("keyboard"))
    readonly property string accelProfile: (block("mouse").match(/^\s*accel-profile\s+"([^"]*)"/m) || [])[1] || "adaptive"
    readonly property real accelSpeed: parseFloat((block("mouse").match(/^\s*accel-speed\s+(-?[\d.]+)/m) || [])[1] || "0")
    readonly property bool focusFollowsMouse: /^\s*focus-follows-mouse\b/m.test(text)

    readonly property var switchOptions: [
        {
            "label": "Caps Lock",
            "value": "grp:caps_toggle"
        },
        {
            "label": "Alt+Shift",
            "value": "grp:alt_shift_toggle"
        },
        {
            "label": "Ctrl+Shift",
            "value": "grp:ctrl_shift_toggle"
        },
        {
            "label": "Win+Space",
            "value": "grp:win_space_toggle"
        },
        {
            "label": "Alt+Space",
            "value": "grp:alt_space_toggle"
        },
        {
            "label": I18n.t("Правый Alt", "Right Alt"),
            "value": "grp:toggle"
        },
        {
            "label": I18n.t("Правый Ctrl", "Right Ctrl"),
            "value": "grp:rctrl_toggle"
        },
        {
            "label": I18n.t("не переключать", "Do not switch"),
            "value": ""
        }
    ]
    readonly property var extraOptions: [
        {
            "label": I18n.t("Caps Lock = Escape", "Caps Lock = Escape"),
            "value": "caps:escape"
        },
        {
            "label": "Caps Lock = Ctrl",
            "value": "ctrl:nocaps"
        },
        {
            "label": I18n.t("Compose на правом Alt", "Compose on Right Alt"),
            "value": "compose:ralt"
        },
        {
            "label": I18n.t("Индикатор раскладки на Scroll Lock", "Layout indicator on Scroll Lock"),
            "value": "grp_led:scroll"
        }
    ]
    readonly property var knownLayouts: ["us", "ru", "ua", "by", "kz", "de", "fr", "es", "it", "pl", "cz", "gb", "jp", "kr", "cn", "tr", "ge", "am", "il", "gr"]

    function match(re) {
        const m = text.match(re);
        return m ? m[1] : "";
    }
    // body of `name { ... }` (first occurrence), for scoped edits
    function blockRange(name, src) {
        src = src === undefined ? text : src;
        const m = new RegExp("^\\s*" + name + "\\s*\\{", "m").exec(src);
        if (!m)
            return null;
        let depth = 0;
        for (let i = m.index + m[0].length - 1; i < src.length; i++) {
            if (src[i] === "{")
                depth++;
            else if (src[i] === "}" && --depth === 0)
                return [m.index + m[0].length, i];
        }
        return null;
    }
    function block(name) {
        const r = blockRange(name);
        return r ? text.slice(r[0], r[1]) : "";
    }

    function setLine(src, re, line, blockName) {
        if (blockName) {
            const r = blockRange(blockName, src);
            if (!r)
                return src;
            let inner = src.slice(r[0], r[1]);
            inner = re.test(inner) ? inner.replace(re, (m, indent) => indent + line) : inner.replace(/\s*$/, "\n        " + line + "\n    ");
            return src.slice(0, r[0]) + inner + src.slice(r[1]);
        }
        return re.test(src) ? src.replace(re, (m, indent) => indent + line) : src;
    }
    // `name { }` inside `parent { … }` when it isn't there yet: the shipped input.kdl
    // has no mouse block (only a commented example), and a setting can't be put into
    // a block that doesn't exist (issue #27: acceleration and speed did nothing)
    function ensureBlock(src, name, parent) {
        if (blockRange(name, src))
            return src;
        const r = blockRange(parent, src);
        if (!r)
            return src;
        const inner = src.slice(r[0], r[1]).replace(/\s*$/, "\n\n    " + name + " {\n    }\n");
        return src.slice(0, r[0]) + inner + src.slice(r[1]);
    }
    function removeLine(src, re) {
        return src.replace(re, "");
    }

    // changes: {layouts, options, repeatDelay, repeatRate, numlock, accelProfile, accelSpeed, focusFollowsMouse}
    function save(ch) {
        let t = text;
        if (ch.layouts !== undefined)
            t = setLine(t, /^(\s*)layout\s+"[^"]*"/m, 'layout "' + ch.layouts + '"');
        if (ch.options !== undefined) {
            if (/^\s*options\s+"[^"]*"/m.test(t))
                t = t.replace(/^(\s*)options\s+"[^"]*"/m, (m, i) => i + 'options "' + ch.options + '"');
            else
                t = t.replace(/^(\s*)(layout\s+"[^"]*".*)$/m, (m, i, l) => i + l + "\n" + i + 'options "' + ch.options + '"');
        }
        // a file without the line gets it in `keyboard { }` (before, the slider moved and
        // nothing was written: back to the old value on the next open)
        if (ch.repeatDelay !== undefined || ch.repeatRate !== undefined)
            t = ensureBlock(t, "keyboard", "input");
        if (ch.repeatDelay !== undefined)
            t = setLine(t, /^(\s*)repeat-delay\s+\d+/m, "repeat-delay " + Math.round(ch.repeatDelay), "keyboard");
        if (ch.repeatRate !== undefined)
            t = setLine(t, /^(\s*)repeat-rate\s+\d+/m, "repeat-rate " + Math.round(ch.repeatRate), "keyboard");
        if (ch.numlock)
            numlockKick.restart();          // turn it on now too, not only at the next login
        if (ch.numlock !== undefined) {
            const kr = blockRange("keyboard", t);
            const has = kr ? /^\s*numlock\b/m.test(t.slice(kr[0], kr[1])) : false;
            if (ch.numlock && !has)
                t = setLine(t, /^(\s*)numlock\b.*$/m, "numlock", "keyboard");
            else if (!ch.numlock && has)
                t = t.replace(/^\s*numlock\b.*\n/m, "");
        }
        if (ch.accelProfile !== undefined || ch.accelSpeed !== undefined)
            t = ensureBlock(t, "mouse", "input");
        if (ch.accelProfile !== undefined)
            t = setLine(t, /^(\s*)accel-profile\s+"[^"]*"/m, 'accel-profile "' + ch.accelProfile + '"', "mouse");
        if (ch.accelSpeed !== undefined)
            t = setLine(t, /^(\s*)accel-speed\s+-?[\d.]+/m, "accel-speed " + Number(ch.accelSpeed).toFixed(2), "mouse");
        if (ch.focusFollowsMouse !== undefined) {
            const has = /^\s*focus-follows-mouse\b/m.test(t);
            if (ch.focusFollowsMouse && !has)
                t = t.replace(/^(\s*)(workspace-auto-back-and-forth.*)$/m, (m, i, l) => i + "focus-follows-mouse\n" + i + l);
            else if (!ch.focusFollowsMouse && has)
                t = t.replace(/^\s*focus-follows-mouse\b.*\n/m, "");
        }
        write(t);
    }

    function write(t) {
        writer.command = ["sh", "-c", 'set -e; f="$1"; b="$2/backups/$(date +%Y%m%d-%H%M%S)-input"; mkdir -p "$b"; cp -n "$f" "$b/"; printf "%s" "$3" > "$f"; if ! niri validate >/dev/null 2>"$b/validate.log"; then cp "$b/input.kdl" "$f"; echo "niri validate не прошёл, откатил" >&2; exit 1; fi; echo "сохранено ♡ (бэкап: $b)"', "sh", file, Config.stateDir, t];
        writer.running = true;
    }

    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: if (text)
                root.log = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (text)
                root.log = text.trim()
        }
        onExited: view.reload()
    }

    // NumLock on login, for real: niri's `numlock` only acts when niri starts and
    // is not honoured everywhere (issue #12), so once per login (and right after
    // switching it on) scripts/numlock.py taps NumLock if its LED is off
    property string numlockState: ""
    Timer {
        id: numlockKick
        interval: 1200
        onTriggered: if (!Shell.dev)
            numlocker.running = true
    }
    Timer {
        running: root.loaded && root.numlock && !Shell.dev
        interval: 3000
        onTriggered: numlockOnce.running = true
    }
    Process {
        id: numlockOnce
        command: ["sh", "-c", 'm="${XDG_RUNTIME_DIR:-/tmp}/angelos-numlock"; [ -e "$m" ] && exit 1; : > "$m"']
        onExited: code => {
            if (code === 0)
                numlocker.running = true;
        }
    }
    Process {
        id: numlocker
        command: ["python3", Quickshell.shellDir + "/scripts/numlock.py", "ensure"]
        stdout: StdioCollector {
            onStreamFinished: root.numlockState = text.trim()
        }
    }

    FileView {
        id: view
        path: root.file
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.text = text()
    }
}
