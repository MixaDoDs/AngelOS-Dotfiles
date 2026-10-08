pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Which widget sits where on the bar. Edited in Settings → Панель.
Singleton {
    id: root

    readonly property var sections: ["left", "center", "right"]
    // the bar's looks (Settings → Bar → Style) and the ones along the bottom edge (their
    // popups and menus open upwards)
    readonly property var styles: ["taskbar", "top", "island", "dock", "capsules", "windose"]
    readonly property string style: styles.includes(Config.bar.style) ? Config.bar.style : "taskbar"
    readonly property bool bottom: style === "taskbar" || style === "dock" || style === "windose"
    // while the demon rules the looks have hell versions of their own (Y2K → Bar in hell):
    // the content re-inked (shaders/hell_ink.frag), the frame each style's own — not the dock
    readonly property bool hell: Config.ready && Angel.demon && Config.y2k.hellBar
    readonly property var defaults: ({
            "left": ["start", "workspaces", "tasks"],
            "center": ["lyrics"],
            "right": ["media", "tray", "layout", "wired", "wifi", "bluetooth", "battery", "volume", "bell", "clock"]
        })
    readonly property var meta: ({
            "start": {
                "label": I18n.t("Пуск", "Start"),
                "icon": "pill"
            },
            "workspaces": {
                "label": I18n.t("Воркспейсы", "Workspaces"),
                "icon": "heart"
            },
            "tasks": {
                "label": I18n.t("Окна", "Windows"),
                "icon": "window"
            },
            "lyrics": {
                "label": I18n.t("Лирика", "Lyrics"),
                "icon": "mic"
            },
            "media": {
                "label": I18n.t("Плеер", "Player"),
                "icon": "music"
            },
            "tray": {
                "label": I18n.t("Трей", "Tray"),
                "icon": "sparkle"
            },
            "layout": {
                "label": I18n.t("Раскладка", "Layout"),
                "icon": "keyboard"
            },
            "volume": {
                "label": I18n.t("Громкость", "Volume"),
                "icon": "speaker"
            },
            "bell": {
                "label": I18n.t("Уведомления", "Notifications"),
                "icon": "bell"
            },
            // issue #19: network status with a panel each; hidden where there is no such hardware
            "wired": {
                "label": I18n.t("Проводная сеть", "Wired network"),
                "icon": "ethernet",
                "before": "volume"
            },
            "wifi": {
                "label": "Wi-Fi",
                "icon": "wifi",
                "before": "volume"
            },
            "bluetooth": {
                "label": "Bluetooth",
                "icon": "bluetooth",
                "before": "volume"
            },
            // laptops: hidden where there is no battery
            "battery": {
                "label": I18n.t("Батарея", "Battery"),
                "icon": "battery",
                "before": "volume"
            },
            "clock": {
                "label": I18n.t("Часы", "Clock"),
                "icon": "calendar"
            }
        })

    readonly property var pluginIds: Plugins.barWidgets.map(p => "plugin:" + p.id)
    readonly property var hidden: (Config.bar.hidden || []).filter(id => valid(id))

    function valid(id) {
        return id.startsWith("plugin:") ? pluginIds.includes(id) : !!meta[id];
    }
    function info(id) {
        if (id.startsWith("plugin:")) {
            const p = Plugins.byId(id.slice(7));
            return {
                "label": p ? I18n.label(p.name) : id.slice(7),
                "icon": p ? (p.icon || "plug") : "plug"
            };
        }
        return meta[id] || {
            "label": id,
            "icon": "heart"
        };
    }

    readonly property var effective: {
        const cfg = Config.bar.layout || {};
        const base = cfg.left || cfg.center || cfg.right ? cfg : defaults;
        const hid = Config.bar.hidden || [];
        const out = {};
        const placed = {};
        for (const s of sections) {
            out[s] = (base[s] || []).filter(id => valid(id) && !hid.includes(id) && !placed[id]);
            for (const id of out[s])
                placed[id] = true;
        }
        // newly enabled plugins land at the start of the right side,
        // built-ins missing from an older saved layout at its end
        const custom = !!(cfg.left || cfg.center || cfg.right);
        const fresh = pluginIds.filter(id => !placed[id] && !hid.includes(id));
        const missing = custom ? Object.keys(meta).filter(id => !placed[id] && !hid.includes(id)) : [];
        out.right = fresh.concat(out.right);
        // a new built-in with a place of its own ("before") goes there, the rest to the end
        for (const id of missing) {
            const at = meta[id].before ? out.right.indexOf(meta[id].before) : -1;
            if (at >= 0)
                out.right.splice(at, 0, id);
            else
                out.right.push(id);
        }
        return out;
    }
    readonly property var all: effective.left.concat(effective.center, effective.right)
    function has(id) {
        return all.includes(id);
    }

    // move `id` to `section` ("left" | "center" | "right" | "hidden") at `index`
    function move(id, section, index) {
        const cur = {
            "left": effective.left.slice(),
            "center": effective.center.slice(),
            "right": effective.right.slice()
        };
        for (const s of sections)
            cur[s] = cur[s].filter(x => x !== id);
        let hid = (Config.bar.hidden || []).filter(x => x !== id);
        if (section === "hidden")
            hid.push(id);
        else {
            const list = cur[section];
            list.splice(Math.max(0, Math.min(index, list.length)), 0, id);
        }
        Config.bar.layout = cur;
        Config.bar.hidden = hid;
    }
    function reset() {
        Config.bar.layout = ({});
        Config.bar.hidden = [];
    }
}
