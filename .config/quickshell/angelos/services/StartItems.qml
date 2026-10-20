pragma Singleton

import QtQuick
import Quickshell
import qs.config

// What the newer Start looks share besides the apps (services/StartApps): the home
// folders, a few settings pages, power, and the apps sorted into rough groups by
// their .desktop Categories (PSP XMB's columns). Rows: {label, icon, run}.
Singleton {
    id: root

    function folder(name) {
        return Config.home + (name ? "/" + name : "");
    }
    readonly property var places: [
        {
            "label": I18n.t("Домой", "Home"),
            "icon": "folder",
            "run": () => Shell.openPath(folder(""))
        },
        {
            "label": I18n.t("Документы", "Documents"),
            "icon": "document",
            "run": () => Shell.openPath(folder("Documents"))
        },
        {
            "label": I18n.t("Загрузки", "Downloads"),
            "icon": "download",
            "run": () => Shell.openPath(folder("Downloads"))
        },
        {
            "label": I18n.t("Картинки", "Pictures"),
            "icon": "image",
            "run": () => Shell.openPath(folder("Pictures"))
        },
        {
            "label": I18n.t("Музыка", "Music"),
            "icon": "music",
            "run": () => Shell.openPath(folder("Music"))
        },
        {
            "label": I18n.t("Видео", "Videos"),
            "icon": "play",
            "run": () => Shell.openPath(folder("Videos"))
        }
    ]
    readonly property var settings: [
        {
            "label": I18n.t("Все настройки", "All settings"),
            "icon": "gear",
            "run": () => Shell.openSettings("")
        },
        {
            "label": Updates.available ? I18n.t("Обновление готово ♡", "Update available ♡") : I18n.t("Обновление", "Update"),
            "icon": "download",
            "run": () => Shell.openSettings("updates")
        },
        {
            "label": I18n.t("Внешний вид", "Appearance"),
            "icon": "palette",
            "run": () => Shell.openSettings("appearance")
        },
        {
            "label": I18n.t("Обои", "Wallpaper"),
            "icon": "image",
            "run": () => Shell.openSettings("wallpaper")
        },
        {
            "label": I18n.t("Панель", "Bar"),
            "icon": "window",
            "run": () => Shell.openSettings("bar")
        },
        {
            "label": I18n.t("Звук", "Sound"),
            "icon": "speaker",
            "run": () => Shell.openSettings("sound")
        },
        {
            "label": I18n.t("Сеть и Wi-Fi", "Network and Wi-Fi"),
            "icon": "wifi",
            "run": () => Shell.openSettings("network")
        },
        {
            "label": I18n.t("Обслуживание", "Maintenance"),
            "icon": "sparkle",
            "run": () => Care.open()
        },
        {
            "label": "Y2K ✧",
            "icon": "sparkle",
            "run": () => Shell.openSettings("y2k")
        }
    ]
    // ---- Start's buttons: the row along the bottom of a look (modules/bar/StartButtonRow) and
    // the power entries of the list looks (classic, XMB, Spotlight) — which and in what order is
    // Config.bar.startButtons (Settings → Start buttons: modules/settings/StartButtonsEditor).
    // id → {icon, label (short: the tooltip, the shelf), row (the longer label in a list), run}.
    // `run` does it at once: the caller closes Start first (sleep closes every menu itself).
    readonly property var buttonIds: ["downloads", "lock", "sleep", "power", "reboot", "logout", "settings", "home", "terminal", "updates", "idle"]
    readonly property var buttons: ({
            "downloads": {
                "icon": "download",
                "label": I18n.t("Загрузки", "Downloads"),
                "run": () => Shell.openPath(folder("Downloads"))
            },
            "lock": {
                "icon": "lock",
                "label": I18n.t("Замок", "Lock"),
                "row": I18n.t("Заблокировать", "Lock"),
                "run": () => Shell.sessionAction("lock")
            },
            "sleep": {
                "icon": "moon",
                "label": I18n.t("Сон", "Sleep"),
                "run": () => Shell.suspend()
            },
            // the session menu: it asks, plays the goodbye
            "power": {
                "icon": "power",
                "label": I18n.t("Питание", "Power"),
                "row": I18n.t("Выход, перезагрузка, выключение…", "Log out, restart, power off…"),
                "run": () => Shell.sessionOpen = true
            },
            "reboot": {
                "icon": "refresh",
                "label": I18n.t("Перезагрузка", "Restart"),
                "run": () => Shell.sessionAction("reboot")
            },
            "logout": {
                "icon": "logout",
                "label": I18n.t("Выход", "Log out"),
                "run": () => Shell.sessionAction("logout")
            },
            "settings": {
                "icon": "gear",
                "label": I18n.t("Настройки", "Settings"),
                "run": () => Shell.openSettings("")
            },
            "home": {
                "icon": "folder",
                "label": I18n.t("Папка", "Folder"),
                "row": I18n.t("Домашняя папка", "Home folder"),
                "run": () => Shell.openPath(folder(""))
            },
            "terminal": {
                "icon": "terminal",
                "label": I18n.t("Терминал", "Terminal"),
                "run": () => Shell.terminal()
            },
            "updates": {
                "icon": "download",
                "label": Updates.available ? I18n.t("Обновление готово ♡", "Update available ♡") : I18n.t("Обновление", "Update"),
                "accent": Updates.available,
                "run": () => Shell.openSettings("updates")
            },
            "idle": {
                "icon": "sparkle",
                "label": I18n.t("Заставка", "Idle screen"),
                "run": () => Shell.sessionAction("idle")
            }
        })
    // ids → [{id, icon, label, row, accent, run}], unknown and repeated ids skipped
    function buttonsFor(ids) {
        const out = [];
        const list = ids || [];          // (the settings file's list arrives as a Qt sequence)
        for (let i = 0; i < list.length; i++) {
            const id = String(list[i]);
            const b = buttonIds.includes(id) ? buttons[id] : null;
            if (b && !out.some(o => o.id === id))
                out.push(Object.assign({
                    "id": id,
                    "row": b.label,
                    "accent": false
                }, b));
        }
        return out;
    }
    readonly property var chosen: buttonsFor(Config.bar.startButtons)
    // as rows {label, icon, run} for the list looks
    readonly property var power: rowsFor([])
    // the same without the ids a look already shows elsewhere (Spotlight's own actions, …)
    function rowsFor(skip) {
        return chosen.filter(b => !skip.includes(b.id)).map(b => ({
                    "label": b.row,
                    "icon": b.icon,
                    "run": b.run
                }));
    }

    // ---- the apps in rough groups (XMB columns) ----
    function groupOf(app) {
        const c = (app && app.categories ? app.categories : []).join(";");
        if (/Game/.test(c))
            return "games";
        if (/AudioVideo|Audio|Video|Player|Music|Graphics|Photography/.test(c))
            return "media";
        if (/Network|WebBrowser|Chat|InstantMessaging|Email/.test(c))
            return "net";
        if (/System|Settings|Utility|Development|TerminalEmulator|FileManager/.test(c))
            return "tools";
        return "apps";
    }
    function appsIn(group) {
        return StartApps.apps.filter(a => groupOf(a) === group);
    }
}
