import QtQuick
import qs.config
import qs.services

// The sidebar's quick toggles, the same for its two looks: the panel's grid (SidebarPanel) and
// the phone's keypad (Phone, a key each: 1…9, *, 0, #). {id, icon, label, on?, act, show?}
QtObject {
    id: root

    readonly property var nightlight: Plugins.enabledPlugins.find(p => p.id === "nightlight") || null
    readonly property var list: [
        {
            "id": "dnd",
            "icon": Config.notifications.dnd ? "bellOff" : "bell",
            "label": I18n.t("Тишина", "Silence"),
            "on": Config.notifications.dnd,
            "act": () => Config.notifications.dnd = !Config.notifications.dnd
        },
        {
            // stream mode (services/StreamMode): on by hand; OBS switches it by itself
            "id": "stream",
            "icon": "monitor",
            "label": StreamMode.active ? I18n.t("В эфире", "Live") : I18n.t("Стрим", "Stream"),
            "on": StreamMode.active,
            "act": () => StreamMode.set("toggle")
        },
        {
            // services/Awake: no idle screen, lock or sleep; also on by itself while streaming or full-screen
            "id": "awake",
            "icon": "coffee",
            "label": Awake.active && !Awake.manual ? I18n.t("Не сплю (авто)", "Awake (auto)") : I18n.t("Не спать", "Stay awake"),
            "on": Awake.active,
            "act": () => Awake.set("toggle")
        },
        {
            "id": "theme",
            "icon": Theme.dark ? "moon" : "sun",
            "label": Theme.dark ? I18n.t("Тёмная", "Dark") : I18n.t("Светлая", "Light"),
            "on": Theme.dark,
            "act": () => Config.appearance.mode = Theme.dark ? "light" : "dark"
        },
        {
            "id": "night",
            "show": !!root.nightlight,
            "icon": "sun",
            "label": I18n.t("Ночник", "Night light"),
            "on": root.nightlight ? Plugins.context(root.nightlight).get("on", true) : false,
            "act": () => {
                const c = Plugins.context(root.nightlight);
                c.set("on", !c.get("on", true));
            }
        },
        {
            "id": "wifi",
            "show": Wifi.hasWifi && Config.network.showWifi,
            "icon": Wifi.enabled ? "wifi" : "wifiOff",
            "label": Wifi.connected ? Wifi.connected.name : "Wi-Fi",
            "on": Wifi.enabled,
            "act": () => Wifi.setEnabled(!Wifi.enabled)
        },
        {
            "id": "bluetooth",
            "show": Bt.available && Config.network.showBluetooth,
            "icon": "bluetooth",
            "label": Bt.connectedDevices.length ? Bt.connectedDevices[0].name : "Bluetooth",
            "on": Bt.enabled,
            "act": () => Bt.setEnabled(!Bt.enabled)
        },
        {
            // Quick Share (LocalSend devices nearby): the radar, files dropped or picked there
            "id": "quickshare",
            "show": Config.quickshare.enabled,
            "icon": "plane",
            "label": I18n.t("Отправить рядом", "Quick Share"),
            "act": () => {
                Sidebar.hide();
                QuickShare.share([], "");
            }
        },
        {
            "id": "lyrics",
            "icon": "mic",
            "label": I18n.t("Лирика", "Lyrics"),
            "on": Config.lyrics.enabled,
            "act": () => Config.lyrics.enabled = !Config.lyrics.enabled
        },
        {
            "id": "blur",
            "icon": "sparkle",
            "label": I18n.t("Блюр", "Blur"),
            "on": Config.appearance.blur,
            "act": () => Config.appearance.blur = !Config.appearance.blur
        },
        {
            "id": "mic",
            "icon": Audio.micMuted ? "micMute" : "mic",
            "label": I18n.t("Микрофон", "Microphone"),
            "on": !Audio.micMuted,
            "act": () => Audio.toggleMic()
        },
        {
            "id": "shot",
            "icon": "image",
            "label": I18n.t("Скриншот", "Screenshot"),
            "act": () => {
                Sidebar.hide();
                Capture.screenshot();
            }
        },
        {
            "id": "rec",
            "icon": "play",
            "label": I18n.t("Запись", "Record"),
            "act": () => {
                Sidebar.hide();
                Capture.record();
            }
        },
        {
            "id": "idle",
            "icon": "moon",
            "label": I18n.t("Заставка", "Idle"),
            "act": () => {
                Sidebar.hide();
                Idle.start();
            }
        }
    ].filter(t => t.show === undefined || t.show)
}
