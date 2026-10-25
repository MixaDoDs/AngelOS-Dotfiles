pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What the right-click menus hold (Settings → Personalization → Right-click menu): each target
// has its own menu — the wallpaper (DesktopMenu), the bar (PanelMenu), a window's button
// (WindowMenu), a desktop widget (DesktopMenu.openWidget) — in one shape: a row of the everyday
// actions as signed icons on top (`quick`, up to 6), a short list under it (`items`, up to 8),
// no submenus, «Настроить меню» last. The pieces are ids: the built-in actions (`builtins`, each
// says which targets it suits), the user's own on the desktop ("custom:<n>": an app, a command, a
// folder or a link) and the plugins' (hidden until switched on, Config.menus.plugins). The middle
// button on the wallpaper opens the ring: eight fixed directions (Config.menus.ring), a flick
// picks one (RadialMenu).
Singleton {
    id: root

    // the pids X11 windows show in niri (xwayland-satellite's): «End task» is not offered there
    property var x11Pids: []
    Process {
        id: x11Lookup
        command: ["pidof", "xwayland-satellite", "Xwayland"]
        stdout: StdioCollector {
            onStreamFinished: root.x11Pids = text.trim().split(/\s+/).filter(x => x).map(Number)
        }
    }
    readonly property int windowCount: Niri.windows.length
    onWindowCountChanged: x11Lookup.running = true

    // the wallpaper menu's looks: list (the usual) · wings · harp (heaven's own, earned) ·
    // pentagram (hell's own). While the demon rules, Y2K → Hell → "Right-click menu" takes over
    // (the circle's own unless turned off).
    readonly property var styles: ["list", "wings", "harp", "pentagram"]
    // heaven's own: feathers of two wings under a halo, the strings of a harp on a cloud
    readonly property var heavenly: ["wings", "harp"]
    // the pentagram is hell's own: in heaven only once the portal is open (Angel.hellAllowed)
    // heaven's own are earned (services/Heaven): a locked one stays picked, the list shows meanwhile
    readonly property string chosen: !styles.includes(Config.desktop.menuStyle) || (Config.desktop.menuStyle === "pentagram" && !Angel.hellAllowed) || !Heaven.menuOk(Config.desktop.menuStyle) ? "list" : Config.desktop.menuStyle
    // in hell (Y2K → Hell → "Right-click menu"): "circle" is the circle's own (story/circles.json
    // → dress: the pentagram before any circle, then one of the circles' looks), or one look always
    readonly property string hellPick: Config.y2k.hellMenu === "circle" ? HellLook.dressMenu : Config.y2k.hellMenu
    readonly property bool hellPickOk: !heavenly.includes(hellPick) && (styles.includes(hellPick) || HellLook.dressMenuIds.includes(hellPick))
    // heaven's own looks stay in heaven: "as usual" with one of them chosen gets the circle's own
    readonly property bool hellish: Angel.demon && (hellPickOk || heavenly.includes(chosen))
    readonly property string style: !hellish ? chosen : hellPickOk ? hellPick : HellLook.dressMenu
    // everything but the list is a full-screen popup (RadialMenu)
    readonly property bool overlay: style !== "list"
    readonly property string overlayLook: style
    function styleLabel(s) {
        return ({
                "list": I18n.t("Обычное", "Default"),
                "wings": I18n.t("Крылья", "Wings"),
                "harp": I18n.t("Арфа", "Harp"),
                "pentagram": I18n.t("Пентаграмма", "Pentagram"),
                "circle": I18n.t("Свой у каждого круга", "Each circle's own"),
                "queue": I18n.t("Талоны", "Tickets"),
                "whirl": I18n.t("Вихрь", "Whirlwind"),
                "plate": I18n.t("Тарелка", "Plate"),
                "roulette": I18n.t("Рулетка", "Roulette"),
                "ripples": I18n.t("Круги на воде", "Ripples"),
                "tombs": I18n.t("Гробницы", "Tombs"),
                "blades": I18n.t("Клинки", "Blades"),
                "masks": I18n.t("Маски", "Masks"),
                "shards": I18n.t("Лёд", "Ice")
            })[s] || s;
    }
    // the old defaults (the pentagram, the grimoire) become "circle" once; a later pick of
    // either is the player's own and stays. A beat after Config is ready: the file's values
    // land just after `ready`
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
        onTriggered: {
            if (!Config.ready || Config.y2k.hellDressByCircle)
                return;
            if (Config.y2k.hellMenu === "pentagram")
                Config.y2k.hellMenu = "circle";
            if (Config.y2k.hellSettings === "grimoire")
                Config.y2k.hellSettings = "circle";
            Config.y2k.hellDressByCircle = true;
        }
    }

    // ---- the targets and what suits them ----
    readonly property var targets: ["desktop", "panel", "task", "widget"]
    function targetLabel(t) {
        return ({
                "desktop": I18n.t("Рабочий стол", "Desktop"),
                "panel": I18n.t("Панель", "Taskbar"),
                "task": I18n.t("Окно", "Window"),
                "widget": I18n.t("Виджет", "Widget"),
                "ring": I18n.t("Кольцо", "Ring")
            })[t] || t;
    }
    // the target the settings page edits (its «Настроить меню» sets it)
    property string editTarget: "desktop"
    readonly property int quickMax: 6
    readonly property int itemsMax: 8
    // built-in entries: {label, short (the quick row's caption), icon, on: the targets}; the
    // actions are run by build()/run()
    readonly property var builtins: ({
            // the desktop (and the ring)
            "clipboard": {
                "label": I18n.t("Буфер обмена", "Clipboard"),
                "short": I18n.t("Буфер", "Clipboard"),
                "icon": "document",
                "on": ["desktop", "ring"]
            },
            "screenshot": {
                "label": I18n.t("Скриншот", "Screenshot"),
                "icon": "image",
                "on": ["desktop", "ring"]
            },
            "circle": {
                "label": I18n.t("Обвести и найти", "Circle to search"),
                "short": "Circle",
                "icon": "search",
                "on": ["desktop", "ring"]
            },
            "record": {
                "label": I18n.t("Запись экрана", "Screen recording"),
                "short": I18n.t("Запись", "Record"),
                "icon": "play",
                "on": ["desktop", "ring"]
            },
            "terminal": {
                "label": I18n.t("Терминал", "Terminal"),
                "icon": "terminal",
                "on": ["desktop", "ring"]
            },
            "files": {
                "label": I18n.t("Файлы", "Files"),
                "icon": "folder",
                "on": ["desktop", "ring"]
            },
            "browser": {
                "label": I18n.t("Браузер", "Browser"),
                "icon": "wifi",
                "on": ["desktop", "ring"]
            },
            "halo": {
                "label": I18n.t("Нимб", "Halo"),
                "icon": "sparkleStar",
                "on": ["desktop", "ring"]
            },
            "nextWallpaper": {
                "label": I18n.t("Следующие обои", "Next wallpaper"),
                "short": I18n.t("Обои ↻", "Wallpaper ↻"),
                "icon": "arrowRight",
                "on": ["desktop", "ring"]
            },
            "randomWallpaper": {
                "label": I18n.t("Случайные обои", "Random wallpaper"),
                "short": I18n.t("Обои ↻", "Wallpaper ↻"),
                "icon": "rotate",
                "on": ["desktop", "ring"]
            },
            "wallpaperPick": {
                "label": I18n.t("Выбрать обои…", "Choose wallpaper…"),
                "short": I18n.t("Обои", "Wallpaper"),
                "icon": "image",
                "on": ["desktop", "ring"]
            },
            "addWidget": {
                "label": I18n.t("Добавить виджет", "Add a widget"),
                "short": I18n.t("Виджет", "Widget"),
                "icon": "layers",
                "on": ["desktop", "ring"]
            },
            "editWidgets": {
                "label": I18n.t("Править виджеты", "Edit widgets"),
                "short": I18n.t("Виджеты", "Widgets"),
                "icon": "layers",
                "on": ["desktop", "ring"]
            },
            "note": {
                "label": I18n.t("Новая заметка", "New note"),
                "short": I18n.t("Заметка", "Note"),
                "icon": "document",
                "on": ["desktop", "ring"]
            },
            "displaySettings": {
                "label": I18n.t("Экран и мониторы", "Display and monitors"),
                "short": I18n.t("Экран", "Display"),
                "icon": "monitor",
                "on": ["desktop", "ring"]
            },
            "personalize": {
                "label": I18n.t("Персонализация", "Personalization"),
                "short": I18n.t("Облик", "Look"),
                "icon": "palette",
                "on": ["desktop", "ring"]
            },
            "settings": {
                "label": I18n.t("Настройки", "Settings"),
                "icon": "gear",
                "on": ["desktop", "ring"]
            },
            "launcher": {
                "label": I18n.t("Выполнить…", "Run…"),
                "icon": "search",
                "on": ["desktop", "ring"]
            },
            "start": {
                "label": I18n.t("Меню «Пуск»", "Start menu"),
                "short": I18n.t("Пуск", "Start"),
                "icon": "pill",
                "on": ["desktop", "ring"]
            },
            "lock": {
                "label": I18n.t("Заблокировать", "Lock"),
                "icon": "lock",
                "on": ["desktop", "ring"]
            },
            "session": {
                "label": I18n.t("Выключение…", "Power…"),
                "short": I18n.t("Питание", "Power"),
                "icon": "power",
                "on": ["desktop", "ring"]
            },
            // the desktop and the bar
            "monitor": {
                "label": I18n.t("Диспетчер задач", "Task manager"),
                "short": I18n.t("Диспетчер", "Tasks"),
                "icon": "chip",
                "on": ["desktop", "panel", "ring"]
            },
            "showDesktop": {
                "label": I18n.t("Показать стол", "Show the desktop"),
                "short": I18n.t("Стол", "Desktop"),
                "icon": "monitor",
                "on": ["panel", "desktop", "ring"]
            },
            // the bar
            "barSettings": {
                "label": I18n.t("Настройки панели", "Taskbar settings"),
                "short": I18n.t("Настройки", "Settings"),
                "icon": "gear",
                "on": ["panel"]
            },
            "autoHide": {
                "label": I18n.t("Автоскрытие", "Auto-hide"),
                "icon": "window",
                "on": ["panel"]
            },
            "barContents": {
                "label": I18n.t("Что на панели…", "What's on the bar…"),
                "icon": "grid",
                "on": ["panel"]
            },
            "chooseMonitor": {
                "label": I18n.t("Выбрать системный монитор…", "Choose system monitor…"),
                "icon": "chip",
                "on": ["panel"]
            },
            // a window (its button on the bar)
            "minimize": {
                "label": I18n.t("Свернуть", "Minimize"),
                "icon": "minimize",
                "on": ["task"]
            },
            "maximize": {
                "label": I18n.t("На весь экран", "Maximize"),
                "short": I18n.t("На весь", "Maximize"),
                "icon": "maximize",
                "on": ["task"]
            },
            "float": {
                "label": I18n.t("Плавающее", "Floating"),
                "icon": "window",
                "on": ["task"]
            },
            "close": {
                "label": I18n.t("Закрыть", "Close"),
                "icon": "close",
                "on": ["task"]
            },
            "fullscreen": {
                "label": I18n.t("Полный экран", "Fullscreen"),
                "icon": "maximize",
                "on": ["task"]
            },
            "toDesk": {
                "label": I18n.t("На стол", "To desk"),
                "icon": "grid",
                "on": ["task"]
            },
            "toMonitor": {
                "label": I18n.t("На другой монитор", "To another monitor"),
                "icon": "monitor",
                "on": ["task"]
            },
            "width": {
                "label": I18n.t("Ширина", "Width"),
                "icon": "width",
                "on": ["task"]
            },
            "pinTask": {
                "label": I18n.t("Закрепить на панели", "Pin to taskbar"),
                "short": I18n.t("На панель", "Pin"),
                "icon": "pin",
                "on": ["task"]
            },
            "pinStart": {
                "label": I18n.t("Закрепить в «Пуске»", "Pin to Start"),
                "short": I18n.t("Закрепить", "Pin"),
                "icon": "star",
                "on": ["task"]
            },
            "shotWindow": {
                "label": I18n.t("Скриншот окна", "Window screenshot"),
                "short": I18n.t("Скриншот", "Screenshot"),
                "icon": "image",
                "on": ["task"]
            },
            "closeAll": {
                "label": I18n.t("Закрыть все окна программы", "Close all its windows"),
                "icon": "close",
                "on": ["task"]
            },
            "kill": {
                "label": I18n.t("Убить процесс", "End task"),
                "icon": "warn",
                "on": ["task"]
            },
            // angel-niri's Desktop: rolled up into the title bar, above everything, on every desk
            "shade": {
                "label": I18n.t("Свернуть в заголовок", "Roll up into the title"),
                "short": I18n.t("Шторка", "Shade"),
                "icon": "height",
                "on": ["task"]
            },
            "onTop": {
                "label": I18n.t("Поверх всего", "Always on top"),
                "short": I18n.t("Поверх", "On top"),
                "icon": "arrowUp",
                "on": ["task"]
            },
            "sticky": {
                "label": I18n.t("Показывать на всех столах", "Show on every desk"),
                "short": I18n.t("Все столы", "All desks"),
                "icon": "allDesks",
                "on": ["task"]
            },
            // a desktop widget
            "size": {
                "label": I18n.t("Размер", "Size"),
                "icon": "maximize",
                "on": ["widget"]
            },
            "depth": {
                "label": I18n.t("Глубина", "Depth"),
                "icon": "layers",
                "on": ["widget"]
            },
            "widgetSettings": {
                "label": I18n.t("Настроить", "Settings"),
                "icon": "gear",
                "on": ["widget"]
            },
            "removeWidget": {
                "label": I18n.t("Убрать", "Remove"),
                "icon": "trash",
                "on": ["widget"]
            },
            "lockWidget": {
                "label": I18n.t("Закрепить на месте", "Lock in place"),
                "short": I18n.t("Закрепить", "Lock"),
                "icon": "lock",
                "on": ["widget"]
            },
            "widgetScreen": {
                "label": I18n.t("На другой монитор", "To another monitor"),
                "icon": "monitor",
                "on": ["widget"]
            },
            "frame": {
                "label": I18n.t("Рамка", "Frame"),
                "icon": "window",
                "on": ["widget"]
            },
            "sep": {
                "label": I18n.t("— разделитель —", "— separator —"),
                "icon": "minus",
                "on": ["desktop", "panel", "task", "widget"]
            }
        })
    // what a target's menu holds before you change it (the owner's pick, 21.10)
    readonly property var defaults: ({
            "desktop": {
                "quick": ["clipboard", "screenshot", "terminal", "nextWallpaper"],
                "items": ["addWidget", "note", "wallpaperPick", "displaySettings", "personalize"]
            },
            "panel": {
                "quick": ["monitor", "showDesktop", "barSettings"],
                "items": ["autoHide", "barContents"]
            },
            "task": {
                "quick": ["minimize", "maximize", "float", "close"],
                "items": ["shade", "onTop", "sticky", "toDesk", "toMonitor", "pinTask", "shotWindow", "kill"]
            },
            "widget": {
                "quick": ["size", "depth", "widgetSettings", "removeWidget"],
                "items": ["lockWidget", "widgetScreen"]
            }
        })
    // the ring's eight directions, clockwise from the top
    readonly property var ringDefault: ["terminal", "browser", "screenshot", "circle", "halo", "randomWallpaper", "clipboard", "files"]

    // the ids a target may hold, in the order the settings offer them (the desktop: its own too)
    function catalog(target) {
        const ids = Object.keys(builtins).filter(id => builtins[id].on.includes(target));
        return target === "desktop" || target === "ring" ? ids.concat(custom.map(c => c.id)) : ids;
    }
    readonly property var custom: Config.desktop.menuCustom || []
    function entry(id) {
        if (String(id).startsWith("custom:")) {
            const c = custom.find(x => x.id === id);
            return c ? {
                "label": c.label || "?",
                "icon": c.icon || "heart",
                "custom": c
            } : null;
        }
        return builtins[id] || null;
    }
    function known(id, target) {
        const e = entry(id);
        return !!e && (!!e.custom ? target === "desktop" || target === "ring" : e.on.includes(target));
    }
    // a target's layout as configured: {quick, items}, unknown ids dropped, the limits kept
    // (the desktop's in Config.desktop.menuQuick/menuItems, the rest in Config.menus.layouts)
    function layout(target) {
        const d = defaults[target] || {
            "quick": [],
            "items": []
        };
        const own = target === "desktop" ? {
            "quick": Config.desktop.menuQuick,
            "items": Config.desktop.menuItems
        } : ((Config.menus.layouts || {})[target] || {});
        const q = (own.quick || d.quick).filter((id, i, a) => known(id, target) && id !== "sep" && a.indexOf(id) === i).slice(0, quickMax);
        const it = (own.items || d.items).filter((id, i, a) => known(id, target) && (id === "sep" || a.indexOf(id) === i)).slice(0, itemsMax);
        return {
            "quick": q,
            "items": it
        };
    }
    function setLayout(target, part, list) {
        if (target === "desktop") {
            if (part === "quick")
                Config.desktop.menuQuick = list;
            else
                Config.desktop.menuItems = list;
            return;
        }
        const all = Object.assign({}, Config.menus.layouts || {});
        all[target] = Object.assign({}, layout(target), all[target] || {});
        all[target][part] = list;
        Config.menus.layouts = all;
    }
    function resetLayout(target) {
        if (target === "desktop") {
            Config.desktop.menuQuick = defaults.desktop.quick.slice();
            Config.desktop.menuItems = defaults.desktop.items.slice();
            return;
        }
        const all = Object.assign({}, Config.menus.layouts || {});
        delete all[target];
        Config.menus.layouts = all;
    }
    readonly property var ring: {
        const r = (Config.menus.ring || []).slice(0, 8);
        return ringDefault.map((d, i) => r[i] && known(r[i], "ring") ? r[i] : d);
    }
    function setRing(i, id) {
        const r = ring.slice();
        r[i] = id;
        Config.menus.ring = r;
    }

    // ---- the plugins' entries: shown only once switched on (Settings → Right-click menu) ----
    function pluginKey(e, i) {
        return e.plugin + ":" + i;
    }
    readonly property var pluginEntries: {
        const out = [], count = {};
        for (const e of Plugins.menuEntries) {
            const i = count[e.plugin] || 0;
            count[e.plugin] = i + 1;
            out.push(Object.assign({
                "key": pluginKey(e, i)
            }, e));
        }
        return out;
    }
    function pluginOn(key) {
        return (Config.menus.plugins || []).includes(key);
    }
    function setPluginOn(key, on) {
        const l = (Config.menus.plugins || []).filter(k => k !== key);
        Config.menus.plugins = on ? l.concat([key]) : l;
    }

    // ---- one menu, put together: {quick: [entries], items: [entries]} in PxMenu's schema ----
    // ctx: {screen, win (a niri window, the task's), uid (the widget's)}; an entry that has
    // nothing to do there (one monitor, no process) is left out
    function menu(target, ctx) {
        const l = layout(target);
        const quick = l.quick.map(id => build(target, id, ctx)).filter(x => !!x);
        let items = l.items.map(id => build(target, id, ctx)).filter(x => !!x);
        items = items.concat(extras(target, ctx));
        if (target === "desktop")
            items = items.concat(pluginEntries.filter(e => pluginOn(e.key)).map(e => ({
                    "label": I18n.label(e.label || "?"),
                    "icon": e.icon || "heart",
                    "hint": e.hint || "",
                    "run": () => Plugins.run(e)
                })));
        // no line first or last, never two in a row
        items = items.filter((e, i, a) => !e.separator || (i > 0 && i < a.length - 1 && !a[i - 1].separator));
        items.push({
            "separator": true
        }, {
            "label": I18n.t("Настроить меню…", "Customize the menu…"),
            "icon": "gear",
            "run": () => {
                root.editTarget = target;
                Shell.openSettings("deskmenu");
            }
        });
        return {
            "quick": quick,
            "items": items
        };
    }
    // what is there only sometimes, not chosen: a window's cobweb, a widget's own settings
    function extras(target, ctx) {
        const out = [];
        if (target === "task" && ctx.win && Cobweb.alive(ctx.win.id) > 0) {
            const w = ctx.win;
            out.push({
                "label": I18n.t("Стряхнуть паутину", "Shake the web off"),
                "icon": "spider",
                "run": () => Cobweb.inside && Cobweb.rectOf(w.id) ? Cobweb.startQte(w.id) : Cobweb.sweep(w.id)
            });
        }
        // the program's place (Settings → Windows → Program places), while that is on
        if (target === "task" && ctx.win && ctx.win.app_id && WindowConfig.remember && WindowConfig.placeOf(ctx.win)) {
            const w = ctx.win;
            const pin = WindowConfig.placeFor(w.app_id);
            out.push({
                "label": I18n.t("Всегда открывать здесь", "Always open here"),
                "icon": "pin",
                "hint": pin ? I18n.t("стол ", "desk ") + pin.idx + " · " + pin.output : "",
                "checkable": true,
                "checked": () => !!WindowConfig.places[w.app_id],
                "run": () => WindowConfig.setPlace(w.app_id, WindowConfig.places[w.app_id] ? null : WindowConfig.placeOf(w))
            });
        }
        if (target === "widget" && ctx.uid)
            return out.concat(widgetOwn(ctx.uid));
        return out;
    }
    // a widget's own entries: the clock's seconds, the picture's file, the note's colour
    function widgetOwn(uid) {
        const w = DesktopWidgets.byUid(uid);
        if (!w)
            return [];
        const st = () => (DesktopWidgets.byUid(uid) || {}).settings || {};
        const toggle = (key, label, icon, dflt) => ({
                "label": label,
                "icon": icon,
                "checkable": true,
                "checked": () => st()[key] === undefined ? dflt : !!st()[key],
                "keepOpen": true,
                "run": () => DesktopWidgets.setSetting(uid, key, !(st()[key] === undefined ? dflt : !!st()[key]))
            });
        if (w.type === "clock")
            return [toggle("seconds", I18n.t("Секунды", "Seconds"), "clock", false), toggle("weather", I18n.t("Погода", "Weather"), "sun", true)];
        if (w.type === "picture") {
            const out = [
                {
                    "label": I18n.t("Выбрать картинку…", "Choose a picture…"),
                    "icon": "image",
                    "run": () => {
                        DesktopWidgets.setSetting(uid, "mode", "file");
                        DesktopWidgets.pick(uid, "file", false);
                    }
                },
                {
                    "label": I18n.t("Слайд-шоу из папки…", "Slideshow from a folder…"),
                    "icon": "folder",
                    "run": () => {
                        DesktopWidgets.setSetting(uid, "mode", "folder");
                        DesktopWidgets.pick(uid, "folder", true);
                    }
                }
            ];
            if (st().mode === "folder" && st().folder)
                out.push({
                    "label": I18n.t("Следующая", "Next"),
                    "icon": "next",
                    "keepOpen": true,
                    "run": () => DesktopWidgets.request(uid, "next")
                });
            return out;
        }
        if (w.type === "note")
            return [
                {
                    "label": I18n.t("Редактировать", "Edit"),
                    "icon": "note",
                    "run": () => DesktopWidgets.request(uid, "edit")
                },
                {
                    "label": I18n.t("Цвет", "Colour"),
                    "icon": "palette",
                    "choices": [0, 1, 2, 3].map(i => ({
                                "label": [I18n.t("Роз", "Pnk"), I18n.t("Гол", "Cyn"), I18n.t("Жёл", "Yel"), "4"][i],
                                "checked": () => (st().tint || 0) === i,
                                "run": () => DesktopWidgets.setSetting(uid, "tint", i)
                            }))
                }
            ];
        return [];
    }

    // one entry of a target's menu, made for where it opened
    function build(target, id, ctx) {
        if (id === "sep")
            return {
                "separator": true
            };
        const e = entry(id);
        if (!e)
            return null;
        const base = {
            "id": id,
            "label": e.label,
            "short": e.short || e.label,
            "icon": e.icon
        };
        const with_ = o => Object.assign(base, o);
        const screen = ctx.screen || "";
        if (target === "task")
            return ctx.win ? taskEntry(id, ctx.win, with_) : null;
        if (target === "widget")
            return ctx.uid ? widgetEntry(id, ctx, with_) : null;
        switch (id) {
        case "autoHide":
            return with_({
                "checkable": true,
                "checked": () => Config.bar.autoHide,
                "keepOpen": true,
                "run": () => Config.bar.autoHide = !Config.bar.autoHide
            });
        case "monitor":
            return with_({
                "enabled": () => DesktopActions.available,
                "run": () => DesktopActions.launchMonitor()
            });
        }
        return with_({
            "run": () => run(id, screen)
        });
    }
    function taskEntry(id, w, with_) {
        const ws = Niri.workspaceById(w.workspace_id);
        switch (id) {
        case "minimize":
            {
                const back = Minimize.isMinimized(w);
                return with_({
                    "label": back ? I18n.t("Развернуть", "Restore") : I18n.t("Свернуть", "Minimize"),
                    "short": back ? I18n.t("Вернуть", "Restore") : I18n.t("Свернуть", "Minimize"),
                    "run": () => back ? Minimize.restore(w.id) : Minimize.request(w.id, "menu")
                });
            }
        case "maximize":
            return with_({
                "run": () => Niri.maximizeWindow(w.id)
            });
        case "fullscreen":
            return with_({
                "run": () => Niri.fullscreenWindow(w.id)
            });
        case "float":
            // Desktop: every window floats already (WindowConfig)
            if (Niri.nativeMinimize && WindowConfig.floatAll)
                return null;
            return with_({
                "checkable": true,
                "checked": w.is_floating,
                "run": () => Niri.toggleFloating(w.id)
            });
        case "close":
            return with_({
                "hint": Config.bar.taskMiddleClose ? I18n.t("средняя кнопка", "middle click") : "",
                "run": () => Niri.closeWindow(w.id)
            });
        case "toDesk":
            {
                if (!ws)
                    return null;
                const n = Math.min(9, Math.max(Niri.workspacesOn(ws.output).length, ws.idx + 1));
                const desks = [];
                for (let i = 1; i <= n; i++) {
                    const idx = i;
                    desks.push({
                        "label": String(idx),
                        "checked": ws.idx === idx,
                        "run": () => Niri.moveWindowToWorkspace(w.id, idx)
                    });
                }
                return with_({
                    "choices": desks
                });
            }
        case "toMonitor":
            {
                const outs = Niri.workspaces.map(x => x.output).filter((o, i, a) => o && a.indexOf(o) === i && (!ws || o !== ws.output));
                if (!outs.length)
                    return null;
                if (outs.length === 1)
                    return with_({
                        "hint": outs[0],
                        "run": () => Niri.moveWindowToMonitor(w.id, outs[0])
                    });
                return with_({
                    "choices": outs.map(o => ({
                                "label": o,
                                "run": () => Niri.moveWindowToMonitor(w.id, o)
                            }))
                });
            }
        case "width":
            return w.is_floating ? null : with_({
                "choices": WindowConfig.choices.map(c => ({
                            "label": c.label,
                            "run": () => Quickshell.execDetached(["niri", "msg", "action", "set-window-width", "--id", String(w.id), WindowConfig.niriArg(c.value)])
                        }))
            });
        case "pinTask":
            {
                if (!w.app_id)
                    return null;
                const pins = Config.bar.taskPinned || [];
                const on = pins.includes(w.app_id);
                return with_({
                    "checkable": true,
                    "checked": on,
                    "run": () => Config.bar.taskPinned = on ? pins.filter(k => k !== w.app_id) : pins.concat([w.app_id])
                });
            }
        case "pinStart":
            {
                const app = StartApps.apps.find(a => a.id === w.app_id || a.id === w.app_id + ".desktop" || String(a.id).toLowerCase() === String(w.app_id).toLowerCase());
                return app ? with_({
                    "checkable": true,
                    "checked": StartApps.isPinned(app),
                    "run": () => StartApps.togglePin(app)
                }) : null;
            }
        case "shotWindow":
            return with_({
                "run": () => Quickshell.execDetached(["niri", "msg", "action", "screenshot-window", "--id", String(w.id)])
            });
        case "closeAll":
            {
                const sib = Niri.windows.filter(x => x.app_id && x.app_id === w.app_id);
                return sib.length > 1 ? with_({
                    "hint": String(sib.length),
                    "run": () => sib.forEach(x => Niri.closeWindow(x.id))
                }) : null;
            }
        case "shade":
        case "onTop":
        case "sticky":
            {
                // Desktop on angel-niri only, floating windows; shading needs niri's title bar
                const field = {
                    "shade": "is_shaded",
                    "onTop": "is_on_top",
                    "sticky": "is_sticky"
                }[id];
                const arg = {
                    "shade": "shaded",
                    "onTop": "on_top",
                    "sticky": "sticky"
                }[id];
                if (!Niri.nativeMinimize || !WindowConfig.floatAll || !w.is_floating || (id === "shade" && !w.has_title_bar))
                    return null;
                return with_({
                    "checkable": true,
                    "checked": !!w[field],
                    "run": () => {
                        const a = {
                            "id": w.id
                        };
                        a[arg] = !w[field];
                        Niri.action("SetWindowFlags", a);
                    }
                });
            }
        case "kill":
            // not for angelOS's own windows: their pid is the shell itself; not for X11 ones: niri
            // knows only xwayland-satellite's pid for them, and killing it took every X11 app (#116).
            // Checked once more when it runs, in case the list is behind
            return w.pid && w.pid !== Shell.pid && Shell.pid > 0 && !root.x11Pids.includes(w.pid) ? with_({
                "hint": "pid " + w.pid,
                "run": () => Shell.exec(["sh", "-c", 'case "$(cat /proc/$1/comm)" in xwayland-sat*|Xwayland) exit 1 ;; esac; kill "$1"', "kill", String(w.pid)])
            }) : null;
        }
        return null;
    }
    function widgetEntry(id, ctx, with_) {
        const uid = ctx.uid;
        const w = DesktopWidgets.byUid(uid);
        const info = w ? DesktopWidgets.typeInfo(w.type) : null;
        if (!info)
            return null;
        const cur = () => DesktopWidgets.byUid(uid) || {};
        switch (id) {
        case "size":
            {
                const sizes = DesktopWidgets.macLook ? [] : DesktopWidgets.sizesOf(info);
                return sizes.length ? with_({
                    "choices": sizes.map(z => ({
                                "label": z.toUpperCase(),
                                "checked": () => DesktopWidgets.sizeOf(cur()) === z,
                                "keepOpen": true,
                                "run": () => DesktopWidgets.setSize(uid, z)
                            }))
                }) : null;
            }
        case "depth":
            {
                // on a layered wallpaper only: a click steps to the next depth (the things of the
                // scene it can stand behind included), its name under the icon
                const ws = Niri.activeWorkspace(ctx.screen);
                if (!Wallpapers.sceneOf(Wallpapers.resolve(ctx.screen, ws ? ws.idx : 1)))
                    return null;
                const kinds = DesktopWidgets.depthKinds.concat((ctx.depthThings || []).map(l => "behind:" + l.id));
                const now = DesktopWidgets.depthOf(cur());
                const next = kinds[(kinds.indexOf(now) + 1) % kinds.length];
                const thing = (ctx.depthThings || []).find(l => "behind:" + l.id === now);
                return with_({
                    "short": thing ? I18n.t("За: ", "Behind: ") + (thing.label_ru || thing.id).toLowerCase() : DesktopWidgets.depthLabel(now),
                    "hint": DesktopWidgets.depthLabel(now),
                    "keepOpen": true,
                    "run": () => DesktopWidgets.setDepth(uid, next)
                });
            }
        case "widgetSettings":
            return with_({
                "run": () => Shell.openSettings("widgets")
            });
        case "removeWidget":
            return with_({
                "run": () => DesktopWidgets.remove(uid)
            });
        case "lockWidget":
            return with_({
                "checkable": true,
                "checked": () => !!cur().locked,
                "keepOpen": true,
                "run": () => DesktopWidgets.setLocked(uid, !cur().locked)
            });
        case "widgetScreen":
            {
                const others = Shell.screens.map(s => s.name).filter(n => n !== w.screen);
                if (!others.length)
                    return null;
                return others.length === 1 ? with_({
                    "hint": others[0],
                    "run": () => DesktopWidgets.setScreen(uid, others[0])
                }) : with_({
                    "choices": others.map(n => ({
                                "label": n,
                                "run": () => DesktopWidgets.setScreen(uid, n)
                            }))
                });
            }
        case "frame":
            return DesktopWidgets.macLook ? null : with_({
                "choices": ["", "window", "plate", "none"].map(f => ({
                            "label": DesktopWidgets.frameLabel(f),
                            "checked": () => (DesktopWidgets.frameKinds.includes(cur().frame) ? cur().frame : "") === f,
                            "keepOpen": true,
                            "run": () => DesktopWidgets.setFrame(uid, f)
                        }))
            });
        }
        return null;
    }

    function wsIdx(screen) {
        const ws = Niri.activeWorkspace(screen);
        return ws ? ws.idx : 1;
    }
    // «Показать стол»: the windows of the screen's desktop minimized, again: back — only the ones
    // it hid (a window minimized by hand before stays down), as on Windows
    property var deskHidden: ({})
    function showDesktop(screen) {
        const ws = Niri.activeWorkspace(screen);
        const here = Niri.windows.filter(w => ws && Minimize.wsOf(w) === ws.id && !Minimize.isAppHidden(w));
        const open = here.filter(w => !Minimize.isMinimized(w));
        if (open.length) {
            deskHidden[screen] = open.map(w => w.id);
            open.forEach(w => Minimize.request(w.id, "menu"));
        } else {
            const hid = here.filter(w => (deskHidden[screen] || []).includes(w.id));
            (hid.length ? hid : here).forEach(w => Minimize.restore(w.id));
            delete deskHidden[screen];
        }
    }
    // run an action entry of the desktop, the bar or the ring
    function run(id, screen) {
        const e = entry(id);
        if (e && e.custom)
            return runCustom(e.custom);
        switch (id) {
        case "terminal":
            return Shell.terminal();
        case "files":
            return DesktopActions.openDirectory("HOME");
        case "browser":
            return Shell.sh("gtk-launch \"$(xdg-settings get default-web-browser)\" || xdg-open about:blank");
        case "monitor":
            return DesktopActions.launchMonitor();
        case "chooseMonitor":
            return Shell.openSettings("taskmanager");
        case "showDesktop":
            return showDesktop(screen);
        case "barSettings":
            return Shell.openSettings("taskbar");
        case "barContents":
            return Shell.openSettings("taskbar");
        case "wallpaperPick":
            return Shell.openSettings("wallpaper");
        case "settings":
            return Shell.openSettings();
        case "displaySettings":
            return Shell.openSettings("display");
        case "personalize":
            return Shell.openSettings("cat:personal");
        case "addWidget":
            return Shell.openSettings("widgets");
        case "screenshot":
            return Capture.screenshot(screen);
        case "circle":
            return Config.capture.classic ? Capture.screenshot(screen) : CircleHost.toggle(screen);
        case "record":
            return Capture.record();
        case "clipboard":
            return Qt.callLater(() => Shell.clipboardOpen = true);
        case "halo":
            return Halo.openOn(screen);
        case "launcher":
            return Qt.callLater(() => Shell.launcherOpen = true);
        case "start":
            return Qt.callLater(() => Shell.openStart(screen));
        case "lock":
            return Shell.lock();
        case "session":
            return Qt.callLater(() => Shell.sessionOpen = true);
        case "nextWallpaper":
            return Wallpapers.next(screen, wsIdx(screen), 1);
        case "randomWallpaper":
            return Wallpapers.shuffle(screen, wsIdx(screen));
        case "note":
            return DesktopActions.newText();
        case "editWidgets":
            return DesktopWidgets.toggleEdit(screen);
        }
    }
    // the user's own entries: {id, label, icon, kind: app|command|path|url, target}
    function runCustom(c) {
        const t = String(c.target || "").trim();
        if (!t)
            return;
        if (c.kind === "app") {
            const app = DesktopEntries.applications.values.find(a => a.id === t || a.id === t + ".desktop");
            if (app)
                StartApps.launch(app);
        } else if (c.kind === "command") {
            Shell.sh(t);
        } else {
            Shell.openPath(c.kind === "path" ? Config.expand(t) : t);
        }
    }
    function addCustom(label, icon, kind, target) {
        const list = custom.slice();
        let n = 1;
        while (list.some(x => x.id === "custom:" + n))
            n++;
        const id = "custom:" + n;
        list.push({
            "id": id,
            "label": label,
            "icon": icon || "heart",
            "kind": kind,
            "target": target
        });
        Config.desktop.menuCustom = list;
        const items = layout("desktop").items;
        if (items.length < itemsMax)
            Config.desktop.menuItems = items.concat([id]);
        return id;
    }
    function removeCustom(id) {
        Config.desktop.menuCustom = custom.filter(x => x.id !== id);
        Config.desktop.menuItems = (Config.desktop.menuItems || []).filter(x => x !== id);
        Config.desktop.menuQuick = (Config.desktop.menuQuick || []).filter(x => x !== id);
    }
    // settings helpers: move within a list
    function moved(list, id, step) {
        const l = (list || []).slice(), i = l.indexOf(id), j = i + step;
        if (i < 0 || j < 0 || j >= l.length)
            return l;
        l.splice(i, 1);
        l.splice(j, 0, id);
        return l;
    }
}
