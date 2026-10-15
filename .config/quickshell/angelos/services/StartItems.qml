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
    // reboot / power off / log out go through the session menu (it asks, plays the goodbye)
    readonly property var power: [
        {
            "label": I18n.t("Заблокировать", "Lock"),
            "icon": "lock",
            "run": () => Shell.lock()
        },
        {
            "label": I18n.t("Сон", "Sleep"),
            "icon": "moon",
            "run": () => Shell.exec(["systemctl", "suspend"])
        },
        {
            "label": I18n.t("Выход, перезагрузка, выключение…", "Log out, restart, power off…"),
            "icon": "power",
            "run": () => Shell.sessionOpen = true
        }
    ]

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
