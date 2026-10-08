pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.desktop.widgets

// Sidebar contents: quick toggles, media + sound, system stats, AI limits.
PxWindow {
    id: root

    title: I18n.exe("sidebar")
    icon: "layers"
    compact: true
    width: Theme.u * 150
    implicitHeight: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 8
    onCloseClicked: Sidebar.open = false

    readonly property var nightlight: Plugins.enabledPlugins.find(p => p.id === "nightlight") || null
    readonly property var toggles: [
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
                Sidebar.open = false;
                Capture.screenshot();
            }
        },
        {
            "id": "rec",
            "icon": "play",
            "label": I18n.t("Запись", "Record"),
            "act": () => {
                Sidebar.open = false;
                Capture.record();
            }
        },
        {
            "id": "idle",
            "icon": "moon",
            "label": I18n.t("Заставка", "Idle"),
            "act": () => {
                Sidebar.open = false;
                Idle.start();
            }
        }
    ].filter(t => t.show === undefined || t.show)

    PxScroll {
        anchors.fill: parent
        contentHeight: col.implicitHeight

        Column {
            id: col
            width: parent.width
            spacing: Theme.u * 6

            // ---- quick toggles ----
            Grid {
                visible: Sidebar.has("toggles")
                width: parent.width
                columns: 3
                spacing: Theme.u * 2
                Repeater {
                    model: root.toggles
                    PxButton {
                        id: tgl
                        required property var modelData
                        width: (col.width - Theme.u * 4) / 3
                        height: Theme.u * 26
                        checked: !!modelData.on
                        onClicked: modelData.act()
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.u * 2
                            PxIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: tgl.modelData.icon
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: tgl.width - Theme.u * 4
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: tgl.modelData.label
                                kind: "tiny"
                            }
                        }
                    }
                }
            }

            // ---- media ----
            Column {
                visible: Sidebar.has("media") && !!Lyrics.player && Lyrics.title !== ""
                width: parent.width
                spacing: Theme.u * 2
                NowPlayingWidget {
                    width: parent.width
                    height: implicitHeight
                }
                PxText {
                    visible: Lyrics.hasLyrics && Lyrics.current !== ""
                    width: parent.width
                    elide: Text.ElideRight
                    text: "♪ " + Lyrics.current
                    color: Theme.accent
                }
            }

            // ---- sound ----
            Column {
                visible: Sidebar.has("sound")
                width: parent.width
                spacing: Theme.u * 3
                Repeater {
                    model: [
                        {
                            "icon": Audio.muted ? "speakerMute" : "speaker",
                            "value": Audio.volume,
                            "ready": Audio.ready,
                            "set": v => Audio.setVolume(v),
                            "mute": () => Audio.toggleMute()
                        },
                        {
                            "icon": Audio.micMuted ? "micMute" : "mic",
                            "value": Audio.micVolume,
                            "ready": !!Audio.source && !!Audio.source.audio,
                            "set": v => {
                                if (Audio.source && Audio.source.audio)
                                    Audio.source.audio.volume = v;
                            },
                            "mute": () => Audio.toggleMic()
                        }
                    ]
                    Row {
                        id: vol
                        required property var modelData
                        width: col.width
                        spacing: Theme.u * 3
                        enabled: modelData.ready
                        PxButton {
                            compact: true
                            icon: vol.modelData.icon
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: vol.modelData.mute()
                        }
                        PxSlider {
                            width: vol.width - x
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 1
                            stepSize: 0.01
                            value: vol.modelData.value
                            valueScale: 100
                            suffix: "%"
                            onMoved: v => vol.modelData.set(v)
                        }
                    }
                }
                PxLevelMeter {
                    width: parent.width
                    height: Theme.u * 5
                    node: Audio.source
                    active: Sidebar.open && Sidebar.has("sound")
                    opacity: Audio.micMuted ? 0.4 : 1
                }
            }

            // ---- system ----
            SysmonWidget {
                visible: Sidebar.has("system")
                width: parent.width
                height: visible ? implicitHeight : 0
            }

            // ---- AI limits and other plugin blocks (manifest "sidebarWidget") ----
            Repeater {
                model: Sidebar.has("ai") ? Plugins.sidebarWidgets : []
                Column {
                    id: block
                    required property var modelData
                    width: col.width
                    spacing: Theme.u * 2
                    PxText {
                        text: "✧ " + I18n.label(block.modelData.name)
                        kind: "tiny"
                        dim: true
                    }
                    Loader {
                        width: parent.width
                        Component.onCompleted: setSource(Plugins.url(block.modelData, block.modelData.sidebarWidget), {
                            "plugin": Plugins.context(block.modelData),
                            "width": block.width
                        })
                    }
                }
            }
        }
    }
}
