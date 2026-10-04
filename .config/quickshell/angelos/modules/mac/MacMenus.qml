pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// Which menu of the Golden Gate menu bar is open, on which screen, and where (MacMenuHost draws
// it, MacMenuBar's titles open it). ←/→ walk the bar's menus like on a Mac; moving the pointer
// over another title while one is open opens that one. The menus are live: the app changes its
// own, Wi-Fi turns on — the open menu follows. Here are also the emblem's menu (the Apple menu
// of macOS, angelOS's here: About This Computer, System Settings, Updates, Force Quit, Sleep,
// Restart, Shut Down, Lock Screen, Log Out) and the menus of the bar's status items (Wi-Fi,
// Bluetooth, sound, the input source, a tray icon).
Singleton {
    id: root

    property string screen: ""               // the screen with an open menu, "" = none
    property int index: -1                   // the bar's menu that is open (-1: a status menu)
    property string statusKind: ""           // wifi | bluetooth | sound | input | tray
    property var trayItem: null              // the tray icon whose menu is open
    property real x: 0                       // its left edge (or right edge, alignRight) in screen px
    property bool alignRight: false
    property var titleX: ({})                // screen -> [left x of each title], from the bar
    property bool fromKeyboard: false        // opened from the keyboard: the first item is selected
    readonly property var barMenus: [angelMenu].concat(AppMenu.menus)
    readonly property var menu: screen === "" ? null : index >= 0 ? barMenus[index] || null : statusKind ? statusMenu(statusKind) : null
    readonly property bool isOpen: menu !== null

    function open(screenName, i, xPos, keyboard) {
        if (!barMenus[i])
            return;
        if (!isOpen)
            Shell.closeTransient();
        fromKeyboard = !!keyboard;
        statusKind = "";
        x = xPos;
        alignRight = false;
        index = i;
        screen = screenName;
    }
    // a status item's menu: right-aligned under it
    function openStatus(screenName, kind, rightX, tray) {
        if (!isOpen)
            Shell.closeTransient();
        fromKeyboard = false;
        index = -1;
        trayItem = tray || null;
        statusKind = kind;
        x = rightX;
        alignRight = true;
        screen = screenName;
    }
    function close() {
        screen = "";
        index = -1;
        statusKind = "";
        trayItem = null;
    }
    function toggle(screenName, i, xPos) {
        if (isOpen && screen === screenName && index === i)
            close();
        else
            open(screenName, i, xPos);
    }
    function toggleStatus(screenName, kind, rightX, tray) {
        if (isOpen && screen === screenName && statusKind === kind && trayItem === (tray || null))
            close();
        else
            openStatus(screenName, kind, rightX, tray);
    }
    // ←/→ from the keyboard: the bar's menus in a ring
    function step(d) {
        if (index < 0)
            return;
        const n = barMenus.length;
        const i = (index + d + n) % n;
        const xs = titleX[screen] || [];
        open(screen, i, xs[i] !== undefined ? xs[i] : x, true);
    }
    function activate(item) {
        close();
        Qt.callLater(() => AppMenu.trigger(item));
    }
    Connections {
        target: Shell
        function onDismissMenus() {
            root.close();
        }
    }
    // another app came to the front: its menus are others (the menu bar taking the keyboard is
    // not that: AppMenu.window stays the frontmost window then)
    readonly property int frontId: AppMenu.window ? AppMenu.window.id : -1
    onFrontIdChanged: if (index > 0)
        close()

    function fn(id, label, f, extra) {
        return AppMenu.item(id, label, {
            "kind": "fn",
            "fn": f
        }, extra);
    }
    function header(id, label) {
        return {
            "id": id,
            "label": label,
            "type": "header"
        };
    }
    function settingsItem(id, label, page) {
        return fn(id, label, () => Shell.openSettings(page));
    }

    // the apps that run, one row per app (Force Quit)
    readonly property var runningApps: {
        const seen = {};
        const out = [];
        for (const w of Niri.windows) {
            if (!w.pid || seen[w.pid])
                continue;
            seen[w.pid] = true;
            const e = DesktopEntries.byId(w.app_id) || DesktopEntries.heuristicLookup(w.app_id);
            out.push({
                "pid": w.pid,
                "name": e && e.name ? e.name : AppMenu.prettyName(w.app_id)
            });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var angelMenu: ({
            "id": "m:angel",
            "title": "angelOS",
            "emblem": true,
            "items": AppMenu.tidy([fn("a:about", I18n.t("Об этом компьютере", "About This Computer"), () => Shell.openSettings("about")), AppMenu.sep("a1"), fn("a:settings", I18n.t("Системные настройки…", "System Settings…"), () => Shell.openSettings()), fn("a:updates", Updates.available ? I18n.t("Обновления — есть новое", "Updates — something new") : I18n.t("Обновления…", "Updates…"), () => Shell.openSettings("updates")), AppMenu.sep("a2"), AppMenu.submenu("a:force", I18n.t("Завершить принудительно", "Force Quit"), runningApps.map(a => fn("a:kill" + a.pid, a.name, () => Quickshell.execDetached(["kill", "-KILL", String(a.pid)])))), AppMenu.sep("a3"), fn("a:sleep", I18n.t("Сон", "Sleep"), () => Quickshell.execDetached(["systemctl", "suspend"])), fn("a:restart", I18n.t("Перезагрузить…", "Restart…"), () => Shell.sessionOpen = true), fn("a:off", I18n.t("Выключить…", "Shut Down…"), () => Shell.sessionOpen = true), AppMenu.sep("a4"), fn("a:lock", I18n.t("Заблокировать экран", "Lock Screen"), () => Shell.lock(), {
                    "keys": Config.mac.keys ? ["ctrl", "logo", "q"] : []
                }), fn("a:logout", I18n.t("Завершить сеанс ", "Log Out ") + StartApps.userName + "…", () => Shell.sessionOpen = true)])
        })

    // ---- the status items' menus ----
    function statusMenu(kind) {
        switch (kind) {
        case "wifi":
            return {
                "id": "s:wifi",
                "items": wifiItems()
            };
        case "bluetooth":
            return {
                "id": "s:bt",
                "items": btItems()
            };
        case "sound":
            return {
                "id": "s:sound",
                "items": soundItems()
            };
        case "input":
            return {
                "id": "s:input",
                "items": inputItems()
            };
        case "tray":
            return trayItem && trayItem.menu ? {
                "id": "s:tray",
                "tray": trayItem.menu
            } : null;
        }
        return null;
    }
    function wifiItems() {
        const out = [
            {
                "id": "w:sw",
                "label": "Wi-Fi",
                "type": "switch",
                "checked": Wifi.enabled,
                "enabled": Wifi.hardwareEnabled,
                "keepOpen": true,
                "act": {
                    "kind": "fn",
                    "fn": () => Wifi.setEnabled(!Wifi.enabled)
                }
            }
        ];
        if (Wifi.enabled) {
            const nets = Wifi.networks.slice(0, 12);
            if (nets.length)
                out.push(AppMenu.sep("w1"), header("w:h", I18n.t("Сети", "Networks")));
            for (const n of nets)
                out.push(fn("w:n" + n.name, n.name, () => n.connected ? null : Wifi.needsPassword(n) ? Shell.openSettings("network") : Wifi.connect(n), {
                    "toggle": "check",
                    "checked": n.connected
                }));
        }
        out.push(AppMenu.sep("w2"), settingsItem("w:set", I18n.t("Настройки Wi-Fi…", "Wi-Fi Settings…"), "network"));
        return out;
    }
    function btItems() {
        const out = [
            {
                "id": "b:sw",
                "label": "Bluetooth",
                "type": "switch",
                "checked": Bt.enabled,
                "enabled": !Bt.blocked,
                "keepOpen": true,
                "act": {
                    "kind": "fn",
                    "fn": () => Bt.setEnabled(!Bt.enabled)
                }
            }
        ];
        if (Bt.enabled && Bt.paired.length) {
            out.push(AppMenu.sep("b1"), header("b:h", I18n.t("Устройства", "Devices")));
            for (const d of Bt.paired)
                out.push(fn("b:d" + d.address, d.name || d.deviceName || d.address, () => Bt.toggleConnect(d), {
                    "toggle": "check",
                    "checked": d.connected
                }));
        }
        out.push(AppMenu.sep("b2"), settingsItem("b:set", I18n.t("Настройки Bluetooth…", "Bluetooth Settings…"), "bluetooth"));
        return out;
    }
    function soundItems() {
        const out = [header("v:h", I18n.t("Звук", "Sound"))];
        if (Audio.ready)
            out.push({
                "id": "v:vol",
                "type": "slider",
                "icon": Audio.muted || Audio.volume === 0 ? "volume-x" : Audio.volume < 0.5 ? "volume-1" : "volume-2",
                "value": Audio.volume,
                "set": v => Audio.setVolume(v)
            });
        if (Audio.sinks.length > 1) {
            out.push(AppMenu.sep("v1"), header("v:o", I18n.t("Выход", "Output")));
            for (const s of Audio.sinks)
                out.push(fn("v:s" + s.id, Audio.nodeName(s), () => Audio.setDefaultSink(s), {
                    "toggle": "radio",
                    "checked": Audio.sink === s
                }));
        }
        out.push(AppMenu.sep("v2"), settingsItem("v:set", I18n.t("Настройки звука…", "Sound Settings…"), "sound"));
        return out;
    }
    function inputItems() {
        const out = [];
        const names = Niri.keyboardLayouts;
        for (let i = 0; i < names.length; i++)
            out.push(fn("i:" + i, names[i], () => Niri.action("SwitchLayout", {
                        "layout": {
                            "Index": i
                        }
                    }), {
                "toggle": "radio",
                "checked": Niri.currentLayout === i
            }));
        out.push(AppMenu.sep("i1"), settingsItem("i:set", I18n.t("Настройки клавиатуры…", "Keyboard Settings…"), "keyboard"));
        return out;
    }
}
