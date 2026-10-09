pragma Singleton

import QtQuick
import Quickshell
import qs.config

// What the right-click menu on the wallpaper holds (Settings → Right-click menu), for both
// looks: the ring (modules/background/RadialMenu) and the Windows 11-like list
// (DesktopMenu). Entries are ids: actions, flyouts (view, new, wallpaper, open, more),
// "sep" (a line in the list) and the user's own ("custom:<n>": an app, a command, a folder
// or a link). The order and what is shown live in Config.desktop.menu*.
Singleton {
    id: root

    readonly property var flyouts: ["view", "new", "wallpaper", "open", "more"]
    // looks: list (the usual, Windows 11-like) · radial (a ring around the pointer) · y2k (a
    // glossy chrome bubble) · tiles (a Control Center grid) · wings · harp (heaven's own) ·
    // pentagram (hell's own). While the demon rules, Y2K → Hell → "Right-click menu" takes
    // over (the circle's own unless turned off).
    readonly property var styles: ["list", "radial", "y2k", "tiles", "wings", "harp", "pentagram"]
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
    // the ring, the tiles, heaven's and hell's own looks share one full-screen popup (RadialMenu)
    readonly property bool overlay: style !== "list" && style !== "y2k"
    readonly property string overlayLook: style === "radial" ? "ring" : style
    function styleLabel(s) {
        return ({
                "list": I18n.t("Обычный", "Default"),
                "radial": I18n.t("Кольцо", "Ring"),
                "y2k": I18n.t("Y2K глянец", "Y2K gloss"),
                "tiles": I18n.t("Плитки", "Tiles"),
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
    // built-in entries: {label, icon, hint}; the actions are run by run(id, screen)
    readonly property var builtins: ({
            "terminal": {
                "label": I18n.t("Терминал", "Terminal"),
                "icon": "terminal"
            },
            "files": {
                "label": I18n.t("Файлы", "Files"),
                "icon": "folder"
            },
            "monitor": {
                "label": I18n.t("Диспетчер задач", "Task manager"),
                "short": I18n.t("Диспетчер", "Tasks"),
                "icon": "chip"
            },
            "wallpaperPick": {
                "label": I18n.t("Выбрать обои", "Choose wallpaper"),
                "short": I18n.t("Обои", "Wallpaper"),
                "icon": "image"
            },
            "settings": {
                "label": I18n.t("Настройки", "Settings"),
                "icon": "gear"
            },
            "displaySettings": {
                "label": I18n.t("Параметры экрана", "Display settings"),
                "short": I18n.t("Экран", "Display"),
                "icon": "monitor"
            },
            "personalize": {
                "label": I18n.t("Персонализация", "Personalize"),
                "short": I18n.t("Тема", "Theme"),
                "icon": "palette"
            },
            "screenshot": {
                "label": I18n.t("Скриншот области", "Region screenshot"),
                "short": I18n.t("Скриншот", "Screenshot"),
                "icon": "image"
            },
            "record": {
                "label": I18n.t("Запись экрана", "Screen recording"),
                "short": I18n.t("Запись", "Record"),
                "icon": "play"
            },
            "clipboard": {
                "label": I18n.t("Буфер обмена", "Clipboard"),
                "short": I18n.t("Буфер", "Clipboard"),
                "icon": "document"
            },
            "launcher": {
                "label": I18n.t("Выполнить…", "Run…"),
                "icon": "search"
            },
            "start": {
                "label": I18n.t("Меню «Пуск»", "Start menu"),
                "short": I18n.t("Пуск", "Start"),
                "icon": "pill"
            },
            "lock": {
                "label": I18n.t("Заблокировать", "Lock"),
                "icon": "lock"
            },
            "session": {
                "label": I18n.t("Выключение…", "Power…"),
                "short": I18n.t("Питание", "Power"),
                "icon": "power"
            },
            "nextWallpaper": {
                "label": I18n.t("Следующие обои", "Next wallpaper"),
                "short": I18n.t("Дальше", "Next"),
                "icon": "arrowRight"
            },
            "randomWallpaper": {
                "label": I18n.t("Случайные обои", "Random wallpaper"),
                "short": I18n.t("Случайные", "Random"),
                "icon": "sparkle"
            },
            "note": {
                "label": I18n.t("Текстовая заметка", "Text note"),
                "short": I18n.t("Заметка", "Note"),
                "icon": "document"
            },
            "editWidgets": {
                "label": I18n.t("Править виджеты", "Edit widgets"),
                "short": I18n.t("Виджеты", "Widgets"),
                "icon": "layers"
            },
            "view": {
                "label": I18n.t("Вид", "View"),
                "icon": "layers",
                "flyout": true
            },
            "new": {
                "label": I18n.t("Создать", "New"),
                "icon": "plus",
                "flyout": true
            },
            "wallpaper": {
                "label": I18n.t("Обои", "Wallpaper"),
                "icon": "image",
                "flyout": true
            },
            "open": {
                "label": I18n.t("Открыть", "Open"),
                "icon": "folder",
                "flyout": true
            },
            "more": {
                "label": I18n.t("Показать больше", "Show more options"),
                "short": I18n.t("Ещё", "More"),
                "icon": "sparkle",
                "flyout": true
            },
            "sep": {
                "label": I18n.t("— разделитель —", "— separator —"),
                "icon": "minus"
            }
        })
    // the order the settings offer them in
    readonly property var catalog: ["terminal", "files", "monitor", "wallpaperPick", "settings", "displaySettings", "personalize", "screenshot", "record", "clipboard", "launcher", "start", "lock", "session", "nextWallpaper", "randomWallpaper", "note", "editWidgets", "view", "new", "wallpaper", "open", "more", "sep"]

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
    function known(id) {
        return !!entry(id);
    }
    // the configured layout, unknown ids dropped
    readonly property var quick: (Config.desktop.menuQuick || []).filter(id => known(id) && id !== "sep").slice(0, 6)
    readonly property var items: (Config.desktop.menuItems || []).filter(id => known(id))

    function wsIdx(screen) {
        const ws = Niri.activeWorkspace(screen);
        return ws ? ws.idx : 1;
    }
    // run an action entry (flyouts are opened by the menus themselves)
    function run(id, screen) {
        const e = entry(id);
        if (e && e.custom)
            return runCustom(e.custom);
        switch (id) {
        case "terminal":
            return Shell.terminal();
        case "files":
            return DesktopActions.openDirectory("HOME");
        case "monitor":
            return DesktopActions.launchMonitor();
        case "wallpaperPick":
            return Shell.openSettings("wallpaper");
        case "settings":
            return Shell.openSettings();
        case "displaySettings":
            return Shell.openSettings("monitor");
        case "personalize":
            return Shell.openSettings("appearance");
        case "screenshot":
            return Capture.screenshot();
        case "record":
            return Capture.record();
        case "clipboard":
            return Qt.callLater(() => Shell.clipboardOpen = true);
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
        Config.desktop.menuItems = (Config.desktop.menuItems || []).concat([id]);
        return id;
    }
    function removeCustom(id) {
        Config.desktop.menuCustom = custom.filter(x => x.id !== id);
        Config.desktop.menuItems = (Config.desktop.menuItems || []).filter(x => x !== id);
        Config.desktop.menuQuick = (Config.desktop.menuQuick || []).filter(x => x !== id);
    }
    // settings helpers: move within a list, add, remove
    function moved(list, id, step) {
        const l = (list || []).slice(), i = l.indexOf(id), j = i + step;
        if (i < 0 || j < 0 || j >= l.length)
            return l;
        l.splice(i, 1);
        l.splice(j, 0, id);
        return l;
    }
}
