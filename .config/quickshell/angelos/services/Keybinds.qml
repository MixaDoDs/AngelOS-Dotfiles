pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// niri key bindings for Settings → Shortcuts: read and edited through
// scripts/keybinds.py — the key profile of the theme in front (cfg/keybinds-pixel.kdl or
// cfg/keybinds-macos.kdl, services/KeyProfile), validated, backed up, rolled back.
Singleton {
    id: root

    property string profile: ""             // pixel | macos ("" — a config from before profiles)
    property string theme: ""               // its name in words
    property string file: ""
    property var binds: []
    property var sections: []
    property bool loaded: false
    property string log: ""
    property bool failed: false
    readonly property bool busy: writer.running
    readonly property string ipc: "qs -c angelos ipc call angelos "

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }
    function apply(ops) {
        if (writer.running)
            return;
        if (Shell.dev && Quickshell.env("HOME") === "/home/" + (Quickshell.env("USER") || "")) {
            log = I18n.t("В dev-режиме конфиг niri не изменяется", "Dev mode does not modify niri");
            failed = true;
            return;
        }
        writer.command = ["python3", Quickshell.shellDir + "/scripts/keybinds.py", JSON.stringify(ops)];
        writer.running = true;
    }

    // ---- key names ----
    readonly property var modNames: ({
            "mod": "Mod",
            "super": "Mod",
            "win": "Mod",
            "ctrl": "Ctrl",
            "control": "Ctrl",
            "shift": "Shift",
            "alt": "Alt"
        })
    function normKey(key) {
        const parts = String(key || "").split("+");
        const mods = parts.slice(0, -1).map(p => (modNames[p.toLowerCase()] || p).toLowerCase()).sort();
        return mods.concat([(parts[parts.length - 1] || "").toLowerCase()]).join("+");
    }
    function bindFor(key, exceptId) {
        const k = normKey(key);
        // the common file's keys are read before the profile: binding one here replaces it for
        // this theme, it is no clash
        return binds.find(b => b.id !== exceptId && b.after !== false && normKey(b.key) === k) || null;
    }
    // evdev key codes (Wayland scan code − 8) → niri/xkb key names, US layout, so
    // the combination is the same whatever layout is active while recording
    readonly property var scanNames: ({
            "1": "Escape", "2": "1", "3": "2", "4": "3", "5": "4", "6": "5", "7": "6", "8": "7", "9": "8", "10": "9", "11": "0",
            "12": "Minus", "13": "Equal", "14": "BackSpace", "15": "Tab",
            "16": "Q", "17": "W", "18": "E", "19": "R", "20": "T", "21": "Y", "22": "U", "23": "I", "24": "O", "25": "P",
            "26": "BracketLeft", "27": "BracketRight", "28": "Return",
            "30": "A", "31": "S", "32": "D", "33": "F", "34": "G", "35": "H", "36": "J", "37": "K", "38": "L",
            "39": "Semicolon", "40": "Apostrophe", "41": "Grave", "43": "Backslash",
            "44": "Z", "45": "X", "46": "C", "47": "V", "48": "B", "49": "N", "50": "M", "51": "Comma", "52": "Period", "53": "Slash",
            "55": "KP_Multiply", "57": "Space", "58": "Caps_Lock",
            "59": "F1", "60": "F2", "61": "F3", "62": "F4", "63": "F5", "64": "F6", "65": "F7", "66": "F8", "67": "F9", "68": "F10",
            "69": "Num_Lock", "70": "Scroll_Lock", "71": "KP_7", "72": "KP_8", "73": "KP_9", "74": "KP_Subtract", "75": "KP_4", "76": "KP_5",
            "77": "KP_6", "78": "KP_Add", "79": "KP_1", "80": "KP_2", "81": "KP_3", "82": "KP_0", "83": "KP_Decimal",
            "87": "F11", "88": "F12", "96": "KP_Enter", "98": "KP_Divide", "99": "Print", "102": "Home", "103": "Up", "104": "Page_Up",
            "105": "Left", "106": "Right", "107": "End", "108": "Down", "109": "Page_Down", "110": "Insert", "111": "Delete",
            "113": "XF86AudioMute", "114": "XF86AudioLowerVolume", "115": "XF86AudioRaiseVolume", "119": "Pause", "127": "Menu",
            "163": "XF86AudioNext", "164": "XF86AudioPlay", "165": "XF86AudioPrev", "166": "XF86AudioStop",
            "183": "F13", "184": "F14", "185": "F15", "186": "F16", "187": "F17", "188": "F18", "189": "F19", "190": "F20",
            "224": "XF86MonBrightnessDown", "225": "XF86MonBrightnessUp"
        })
    // modifier-only presses are not a key
    function isModifier(e) {
        return [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_Hyper_L, Qt.Key_Hyper_R].includes(e.key);
    }
    function keyName(e) {
        const n = scanNames[String(e.nativeScanCode - 8)];
        if (n)
            return n;
        if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z)
            return String.fromCharCode(e.key);
        if (e.key >= Qt.Key_0 && e.key <= Qt.Key_9)
            return String.fromCharCode(e.key);
        if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F24)
            return "F" + (e.key - Qt.Key_F1 + 1);
        return "";
    }
    function mods(e) {
        const m = e.modifiers;
        return {
            "mod": !!(m & Qt.MetaModifier),
            "ctrl": !!(m & Qt.ControlModifier),
            "shift": !!(m & Qt.ShiftModifier),
            "alt": !!(m & Qt.AltModifier)
        };
    }
    function compose(m, key) {
        if (!key)
            return "";
        return (m.mod ? "Mod+" : "") + (m.ctrl ? "Ctrl+" : "") + (m.alt ? "Alt+" : "") + (m.shift ? "Shift+" : "") + key;
    }
    // "Mod+Shift+T" as chips-friendly text
    function pretty(key) {
        return String(key || "").split("+").map(p => {
            const l = p.toLowerCase();
            return l === "mod" || l === "super" || l === "win" ? "Win" : l === "ctrl" || l === "control" ? "Ctrl" : l === "shift" ? "Shift" : l === "alt" ? "Alt" : p.replace(/^XF86Audio/, "♪ ").replace(/^XF86MonBrightness/, "☀ ").replace(/^WheelScroll/, I18n.t("Колесо ", "Wheel ")).replace("ESCAPE", "Esc").replace("Escape", "Esc");
        }).join(" + ");
    }

    // ---- what an action does, in words ----
    readonly property var niriNames: ({
            "close-window": I18n.t("Закрыть окно", "Close window"),
            "fullscreen-window": I18n.t("Окно во весь экран", "Fullscreen window"),
            "toggle-window-floating": I18n.t("Плавающее / в сетке", "Toggle floating"),
            "switch-focus-between-floating-and-tiling": I18n.t("Фокус: плавающие ↔ сетка", "Focus floating ↔ tiling"),
            "maximize-column": I18n.t("Развернуть колонку", "Maximize column"),
            "maximize-window-to-edges": I18n.t("Развернуть окно до краёв", "Maximize window to edges"),
            "toggle-overview": I18n.t("Обзор", "Overview"),
            "show-hotkey-overlay": I18n.t("Шпаргалка по хоткеям", "Hotkey overlay"),
            "screenshot": I18n.t("Скриншот (niri)", "Screenshot (niri)"),
            "screenshot-screen": I18n.t("Скриншот экрана", "Screenshot screen"),
            "screenshot-window": I18n.t("Скриншот окна", "Screenshot window"),
            "power-off-monitors": I18n.t("Выключить мониторы", "Power off monitors"),
            "quit": I18n.t("Выйти из niri", "Quit niri"),
            "toggle-keyboard-shortcuts-inhibit": I18n.t("Вернуть хоткеи у игры/окна", "Toggle shortcut inhibit"),
            "focus-column-left": I18n.t("Фокус: колонка слева", "Focus column left"),
            "focus-column-right": I18n.t("Фокус: колонка справа", "Focus column right"),
            "focus-window-up": I18n.t("Фокус: окно выше", "Focus window up"),
            "focus-window-down": I18n.t("Фокус: окно ниже", "Focus window down"),
            "move-column-left": I18n.t("Колонку влево", "Move column left"),
            "move-column-right": I18n.t("Колонку вправо", "Move column right"),
            "move-window-up": I18n.t("Окно выше", "Move window up"),
            "move-window-down": I18n.t("Окно ниже", "Move window down"),
            "focus-column-first": I18n.t("Фокус: первая колонка", "Focus first column"),
            "focus-column-last": I18n.t("Фокус: последняя колонка", "Focus last column"),
            "move-column-to-first": I18n.t("Колонку в начало", "Move column to first"),
            "move-column-to-last": I18n.t("Колонку в конец", "Move column to last"),
            "focus-monitor-left": I18n.t("Фокус: монитор слева", "Focus monitor left"),
            "focus-monitor-right": I18n.t("Фокус: монитор справа", "Focus monitor right"),
            "focus-monitor-up": I18n.t("Фокус: монитор выше", "Focus monitor up"),
            "focus-monitor-down": I18n.t("Фокус: монитор ниже", "Focus monitor down"),
            "move-column-to-monitor-left": I18n.t("Колонку на монитор слева", "Column to monitor left"),
            "move-column-to-monitor-right": I18n.t("Колонку на монитор справа", "Column to monitor right"),
            "move-column-to-monitor-up": I18n.t("Колонку на монитор выше", "Column to monitor up"),
            "move-column-to-monitor-down": I18n.t("Колонку на монитор ниже", "Column to monitor down"),
            "consume-or-expel-window-left": I18n.t("Окно в колонку слева / из неё", "Consume/expel window left"),
            "consume-or-expel-window-right": I18n.t("Окно в колонку справа / из неё", "Consume/expel window right"),
            "consume-window-into-column": I18n.t("Забрать окно в колонку", "Consume window into column"),
            "expel-window-from-column": I18n.t("Вынуть окно из колонки", "Expel window from column"),
            "switch-preset-column-width": I18n.t("Следующая ширина колонки", "Next column width"),
            "switch-preset-column-width-back": I18n.t("Предыдущая ширина колонки", "Previous column width"),
            "switch-preset-window-height": I18n.t("Следующая высота окна", "Next window height"),
            "reset-window-height": I18n.t("Сбросить высоту окна", "Reset window height"),
            "focus-workspace-down": I18n.t("Стол ниже", "Workspace down"),
            "focus-workspace-up": I18n.t("Стол выше", "Workspace up"),
            "focus-workspace-previous": I18n.t("Предыдущий стол", "Previous workspace"),
            "move-column-to-workspace-down": I18n.t("Колонку на стол ниже", "Column to workspace down"),
            "move-column-to-workspace-up": I18n.t("Колонку на стол выше", "Column to workspace up"),
            "focus-workspace": I18n.t("Стол", "Workspace"),
            "move-column-to-workspace": I18n.t("Колонку на стол", "Column to workspace"),
            "move-window-to-workspace": I18n.t("Окно на стол", "Window to workspace"),
            "expand-column-to-available-width": I18n.t("Растянуть колонку на свободное место", "Expand column"),
            "center-column": I18n.t("Колонку в центр", "Center column"),
            "center-visible-columns": I18n.t("Видимые колонки в центр", "Center visible columns"),
            "set-column-width": I18n.t("Ширина колонки", "Column width"),
            "set-window-height": I18n.t("Высота окна", "Window height"),
            "toggle-column-tabbed-display": I18n.t("Колонка вкладками", "Tabbed column"),
            "switch-layout": I18n.t("Раскладка клавиатуры", "Keyboard layout")
        })
    // angelOS actions that can be put on a key (label, ipc call, icon)
    readonly property var angelosActions: [
        {
            "id": "launcher",
            "label": I18n.t("Программы (лаунчер)", "Apps (launcher)"),
            "call": "launcher",
            "icon": "search"
        },
        {
            "id": "startMenu",
            "label": I18n.t("Меню «Пуск»", "Start menu"),
            "call": "startMenu \"\"",
            "icon": "pill"
        },
        {
            "id": "settings",
            "label": I18n.t("Настройки angelOS", "angelOS settings"),
            "call": "settings appearance",
            "icon": "gear"
        },
        {
            "id": "shortcuts",
            "label": I18n.t("Настройки: горячие клавиши", "Settings: shortcuts"),
            "call": "settings shortcuts",
            "icon": "keyboard"
        },
        {
            "id": "clipboard",
            "label": I18n.t("Буфер обмена", "Clipboard"),
            "call": "clipboard",
            "icon": "document"
        },
        {
            "id": "lock",
            "label": I18n.t("Заблокировать", "Lock"),
            "call": "lock",
            "icon": "lock"
        },
        {
            "id": "session",
            "label": I18n.t("Меню выключения", "Power menu"),
            "call": "session",
            "icon": "power"
        },
        {
            "id": "idle",
            "label": I18n.t("Заставка", "Idle screen"),
            "call": "idle",
            "icon": "moon"
        },
        {
            "id": "wallpaper",
            "label": I18n.t("Случайные обои", "Random wallpaper"),
            "call": "wallpaper random",
            "icon": "image"
        },
        {
            "id": "theme",
            "label": I18n.t("Светлая / тёмная тема", "Light / dark theme"),
            "call": "theme toggle",
            "icon": "sun"
        },
        {
            "id": "lyrics",
            "label": I18n.t("Лирика вкл/выкл", "Lyrics on/off"),
            "call": "lyrics",
            "icon": "mic"
        },
        {
            "id": "sidebar",
            "label": I18n.t("Сайдбар", "Sidebar"),
            "call": "sidebar",
            "icon": "layers"
        },
        {
            "id": "mediaToggle",
            "label": I18n.t("Музыка: пауза / играть", "Media: play / pause"),
            "call": "media toggle",
            "icon": "play"
        },
        {
            "id": "mediaNext",
            "label": I18n.t("Музыка: следующий трек", "Media: next track"),
            "call": "media next",
            "icon": "next"
        },
        {
            "id": "mediaPrev",
            "label": I18n.t("Музыка: предыдущий трек", "Media: previous track"),
            "call": "media previous",
            "icon": "prev"
        },
        {
            "id": "volumeUp",
            "label": I18n.t("Громче", "Volume up"),
            "call": "volumeUp",
            "icon": "speaker"
        },
        {
            "id": "volumeDown",
            "label": I18n.t("Тише", "Volume down"),
            "call": "volumeDown",
            "icon": "speaker"
        },
        {
            "id": "mute",
            "label": I18n.t("Звук вкл/выкл", "Mute"),
            "call": "mute",
            "icon": "speakerMute"
        },
        {
            "id": "micMute",
            "label": I18n.t("Микрофон вкл/выкл", "Mute microphone"),
            "call": "micMute",
            "icon": "micMute"
        },
        {
            "id": "taskmgr",
            "label": I18n.t("Диспетчер задач", "Task Manager"),
            "call": "taskManager",
            "icon": "chip"
        }
    ]
    // niri actions offered when adding a shortcut
    readonly property var niriActions: ["close-window", "fullscreen-window", "maximize-column", "maximize-window-to-edges", "toggle-window-floating", "toggle-overview", "center-column", "toggle-column-tabbed-display", "switch-preset-column-width", "focus-workspace-previous", "screenshot", "screenshot-screen", "screenshot-window", "power-off-monitors", "show-hotkey-overlay"]
    readonly property var catalog: angelosActions.map(a => ({
                "label": "angelOS · " + a.label,
                "action": "spawn-sh " + JSON.stringify(ipc + a.call),
                "icon": a.icon
            })).concat(niriActions.map(n => ({
                "label": "niri · " + niriNames[n],
                "action": n,
                "icon": "window"
            })))

    function appFor(argv) {
        const exe = String(argv[0] || "").split("/").pop();
        if (exe === "gtk-launch" && argv[1])
            return StartApps.apps.find(a => a.id === argv[1] || a.id === argv[1].replace(/\.desktop$/, "")) || null;
        // the app that *is* this program, not one that merely runs in it ("kitty -e climp")
        const same = StartApps.apps.filter(a => a.command && a.command.length && String(a.command[0]).split("/").pop() === exe);
        return same.find(a => String(a.id).toLowerCase().split(".").pop() === exe.toLowerCase()) || same.find(a => a.command.filter(x => !/^%/.test(x)).length === 1) || StartApps.apps.find(a => String(a.id).toLowerCase() === exe.toLowerCase()) || null;
    }
    function args(action) {
        const out = [];
        const re = /"((?:[^"\\]|\\.)*)"|(\S+)/g;
        let m;
        while ((m = re.exec(action)))
            out.push(m[1] !== undefined ? m[1].replace(/\\(.)/g, "$1") : m[2]);
        return out;
    }
    // {label, detail, icon, appId}
    function describe(b) {
        const a = args(b.action);
        const name = a[0] || "";
        if (name === "spawn-sh" || name === "spawn") {
            const cmd = name === "spawn-sh" ? a[1] || "" : a.slice(1).join(" ");
            const m = cmd.match(/(?:qs -c angelos ipc call angelos|angelos) (\S+)(.*)$/);
            if (m) {
                const call = (m[1] + m[2]).trim();
                const known = angelosActions.find(x => x.call === call || x.call.split(" ")[0] === m[1] && !x.call.includes(" "));
                return {
                    "label": known ? known.label : (b.title || call).replace(/^angelOS:\s*/, ""),
                    "detail": "angelOS · " + call,
                    "icon": known ? known.icon : "heart",
                    "appId": ""
                };
            }
            const app = name === "spawn" ? appFor(a.slice(1)) : null;
            return {
                "label": app ? app.name : b.title || cmd,
                "detail": cmd,
                "icon": "terminal",
                "appId": app ? app.id : (name === "spawn" ? String(a[1] || "").split("/").pop() : "")
            };
        }
        const base = niriNames[name];
        return {
            "label": base ? base + (a.length > 1 ? " " + a.slice(1).join(" ") : "") : b.title || b.action,
            "detail": b.action,
            "icon": "window",
            "appId": ""
        };
    }

    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/keybinds.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text);
                    if (v.error) {
                        root.log = v.error;
                        root.failed = true;
                        return;
                    }
                    root.binds = v.binds || [];
                    root.sections = v.sections || [];
                    root.profile = v.profile || "";
                    root.theme = v.theme || "";
                    root.file = v.file || "";
                    root.loaded = true;
                } catch (e) {
                    root.log = String(e);
                }
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.failed = !!r.error;
                    root.log = r.error ? r.error : r.ok || "";
                } catch (e) {
                    root.failed = true;
                    root.log = text.trim();
                }
            }
        }
        onExited: reader.running = true
    }
}
