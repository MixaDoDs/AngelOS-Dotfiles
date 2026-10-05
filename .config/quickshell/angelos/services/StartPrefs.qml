pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Deep settings of every Start look (Settings → Bar → Start → "Fine-tune"), kept apart
// per look in Config.bar.startPrefs: {"win11": {"columns": 8, …}, "wii": {…}}. A look
// reads its resolved set with StartPrefs.of("win11") — every key, the user's value or
// the default — and binds to it; keys a look doesn't use are not offered for it.
//   size & grid   width, height, columns, rows, iconScale, labels, scale
//   sections      user (avatar + name), pinned, recommended, power, search, clock, extras
//   look          opacity, accent, shadow
//   animation     anim, animSpeed, animKind, sound
//   behaviour     sort, openOn, clickOutside, typeSearch
// Also the user block every look can show: the avatar (Config.bar.avatar — a copy in
// ~/.local/share/angelos, picked in Settings; else AccountsService's icon or ~/.face)
// and the name (Config.bar.userName, else $USER).
Singleton {
    id: root

    readonly property var styles: ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"]
    readonly property var popups: ["classic", "win11", "windose", "spotlight"]   // by the button; the rest fill the screen
    readonly property var all: styles

    // every key: default, range or choices, the looks that use it, and where it is shown
    readonly property var keys: ({
            "width": {
                "def": 100,
                "min": 70,
                "max": 180,
                "step": 5,
                "suffix": "%",
                "styles": ["classic", "win11", "windose", "spotlight"],
                "group": "size"
            },
            "height": {
                "def": 100,
                "min": 70,
                "max": 160,
                "step": 5,
                "suffix": "%",
                "styles": ["windose"],
                "group": "size"
            },
            "columns": {
                "def": 0,
                "min": 0,
                "max": 10,
                "step": 1,
                "auto": true,
                "styles": ["win11", "windose", "fullscreen", "wii"],
                "group": "size"
            },
            "rows": {
                "def": 0,
                "min": 0,
                "max": 6,
                "step": 1,
                "auto": true,
                "styles": ["win11", "fullscreen", "wii"],
                "group": "size"
            },
            "iconScale": {
                "def": 100,
                "min": 60,
                "max": 160,
                "step": 10,
                "suffix": "%",
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "size"
            },
            "labels": {
                "def": true,
                "styles": ["win11", "windose", "fullscreen", "xmb", "wii"],
                "group": "size"
            },
            "scale": {
                "def": 100,
                "min": 80,
                "max": 140,
                "step": 5,
                "suffix": "%",
                "styles": ["classic", "win11", "windose", "spotlight"],
                "group": "size"
            },
            "user": {
                "def": true,
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "sections"
            },
            "pinned": {
                "def": true,
                "styles": ["win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "sections"
            },
            "recommended": {
                "def": true,
                "styles": ["win11"],
                "group": "sections"
            },
            "power": {
                "def": true,
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "sections"
            },
            "search": {
                "def": true,
                "styles": ["win11", "windose", "fullscreen", "xmb", "wii"],
                "group": "sections"
            },
            "clock": {
                "def": true,
                "styles": ["fullscreen", "xmb", "wii"],
                "group": "sections"
            },
            "extras": {
                "def": true,
                "styles": ["classic"],
                "group": "sections"
            },
            "opacity": {
                "def": 0,
                "min": 0,
                "max": 100,
                "step": 5,
                "auto": true,
                "suffix": "%",
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "look"
            },
            "accent": {
                "def": "",
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "look"
            },
            "shadow": {
                "def": true,
                "styles": ["classic", "win11"],
                "group": "look"
            },
            "anim": {
                "def": true,
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "look"
            },
            "animSpeed": {
                "def": 100,
                "min": 50,
                "max": 200,
                "step": 10,
                "suffix": "%",
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "look"
            },
            "animKind": {
                "def": "auto",
                "choices": ["auto", "fade", "slide", "zoom"],
                "styles": ["classic", "win11", "windose", "spotlight"],
                "group": "look"
            },
            "sound": {
                "def": false,
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "look"
            },
            "sort": {
                "def": "az",
                "choices": ["az", "frequent"],
                "styles": ["win11", "windose", "fullscreen", "xmb", "wii"],
                "group": "behavior"
            },
            "openOn": {
                "def": "focused",
                "choices": ["focused", "pointer", "primary"],
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "behavior"
            },
            "clickOutside": {
                "def": true,
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii", "spotlight"],
                "group": "behavior"
            },
            "typeSearch": {
                "def": true,
                "styles": ["classic", "win11", "windose", "fullscreen", "xmb", "wii"],
                "group": "behavior"
            }
        })

    readonly property var stored: Config.bar.startPrefs || ({})
    readonly property string current: styles.includes(Config.bar.startStyle) ? Config.bar.startStyle : "classic"

    function applies(style, key) {
        const k = keys[key];
        return !!k && k.styles.includes(style);
    }
    // the resolved set of a look: every key (the user's value or the default) and a few
    // values worked out from them
    function of(style) {
        const own = stored[style] || {};
        const o = {};
        for (const key in keys) {
            const k = keys[key];
            let v = own[key];
            if (v === undefined || v === null)
                v = key === "width" ? (Config.bar.startWidth || 100) : key === "rows" && style === "win11" ? (Config.bar.startRows || 0) : k.def;
            o[key] = v;
        }
        o.size = Math.max(0.7, Math.min(1.8, o.width / 100));
        o.tall = Math.max(0.7, Math.min(1.6, o.height / 100));
        o.icons = Math.max(0.6, Math.min(1.6, o.iconScale / 100));
        o.zoom = Math.max(0.8, Math.min(1.4, o.scale / 100));
        o.alpha = o.opacity > 0 ? o.opacity / 100 : Theme.panelAlpha;
        o.accentColor = o.accent ? Qt.color(o.accent) : Theme.accent;
        o.speed = Math.max(0.5, Math.min(2, o.animSpeed / 100));
        return o;
    }
    function set(style, key, value) {
        const all = Object.assign({}, stored);
        const own = Object.assign({}, all[style] || {});
        if (value === undefined || value === null)
            delete own[key];
        else
            own[key] = value;
        if (Object.keys(own).length)
            all[style] = own;
        else
            delete all[style];
        Config.bar.startPrefs = all;
    }
    function reset(style) {
        const all = Object.assign({}, stored);
        delete all[style];
        Config.bar.startPrefs = all;
    }
    function changed(style) {
        return Object.keys(stored[style] || {}).length;
    }
    // apps in the look's order: A–Z (as StartApps keeps them) or the most used first
    function sorted(style, list) {
        if (of(style).sort !== "frequent")
            return list;
        const u = Config.launcher.usage || {};
        return list.slice().sort((a, b) => (u[b.id] || 0) - (u[a.id] || 0) || String(a.name).localeCompare(String(b.name)));
    }
    // where Start opens when nothing says (a Meta tap, IPC): where the focus is, under the
    // pointer (as far as angelOS knows it), or on the main screen
    function screenFor() {
        const how = of(current).openOn;
        if (how === "pointer" && Pointer.screen)
            return Pointer.screen;
        if (how === "primary" && Shell.primaryName)
            return Shell.primaryName;
        return "";
    }

    // ---- the user block ----
    readonly property string userName: Config.bar.userName || Quickshell.env("USER") || "angel"
    readonly property string systemAvatar: faceProbe.found
    readonly property string avatar: Config.bar.avatar || systemAvatar
    readonly property string avatarUrl: avatar ? "file://" + avatar : ""
    readonly property string avatarDir: Config.home + "/.local/share/angelos"
    // the picture from the system, when angelOS has none: AccountsService, then ~/.face
    Process {
        id: faceProbe
        property string found: ""
        running: true
        command: ["sh", "-c", 'for f in "/var/lib/AccountsService/icons/$USER" "$HOME/.face" "$HOME/.face.icon"; do [ -r "$f" ] && [ -s "$f" ] && { echo "$f"; exit; }; done']
        stdout: StdioCollector {
            onStreamFinished: faceProbe.found = text.trim()
        }
    }
    // Settings → Bar → Start → Avatar: pick a picture (scripts/pick-file.py: the desktop's own
    // file chooser through the XDG portal, else zenity or kdialog); a copy is kept next to the
    // settings. `pickError` says why nothing opened — there used to be no answer at all
    property bool picking: false
    property string pickError: ""
    function pickAvatar() {
        if (picker.running)
            return;
        picking = true;
        pickError = "";
        picker.running = true;
    }
    function clearAvatar() {
        Config.bar.avatar = "";
    }
    Process {
        id: picker
        command: ["sh", "-c", 'f=$(python3 "$2" "$3" "$4" "*.png" "*.jpg" "*.jpeg" "*.webp" "*.gif" "*.bmp" "*.svg" 2>/dev/null); rc=$?; [ "$rc" = 2 ] && { echo "!none"; exit 2; }; [ -n "$f" ] || exit 1; mkdir -p "$1"; ext="${f##*.}"; ext=$(printf %s "$ext" | tr A-Z a-z); t="$1/avatar-$(date +%s).$ext"; cp -f "$f" "$t" || { echo "!copy"; exit 3; }; for o in "$1"/avatar-*; do [ "$o" = "$t" ] || rm -f "$o"; done; echo "$t"', "sh", root.avatarDir, Quickshell.shellDir + "/scripts/pick-file.py", I18n.t("angelOS — аватарка", "angelOS — avatar"), I18n.t("Картинки", "Pictures")]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p === "!none")
                    root.pickError = I18n.t("Окно выбора файла не открылось: нет ни XDG-портала (xdg-desktop-portal-gnome), ни zenity. Поставь один из них.", "No file chooser opened: there is neither the XDG portal (xdg-desktop-portal-gnome) nor zenity. Install one of them.");
                else if (p === "!copy")
                    root.pickError = I18n.t("Не удалось скопировать картинку в ~/.local/share/angelos", "Couldn't copy the picture into ~/.local/share/angelos");
                else if (p)
                    Config.bar.avatar = p;
            }
        }
        onExited: root.picking = false
    }
}
