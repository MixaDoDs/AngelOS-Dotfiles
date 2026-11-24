pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.desktop
import "widgets" as SerpW
import "../../widgets/MacIcons.js" as MacIcons

// serp-skin: the sidebar (the heart tab at the edge) in Serpantinum's look — an island full height
// at the tab's edge (on a top / bottom edge: as tall as it needs, by the tab), the same blocks as
// modules/sidebar/SidebarPanel (Sidebar.has: toggles, media, sound, system, plugin widgets) as
// rounded surface0 cards. SidebarHost loads it in the panel's window instead of SidebarPanel while
// the skin is on (and Sidebar.phone is false then: services/Sidebar hunk). Shared Px* controls
// inside (plugin widgets, the level meter) see settingsSkin "goldengate": the modern look.
Item {
    id: root

    property var host: null                  // SidebarHost's panelWin (slideAt, anchorAlong)
    property string edge: "right"
    property string screenName: ""
    property var toggles: []                 // SidebarToggles.list
    readonly property string settingsSkin: "goldengate"

    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property int gap: Serp.px(8)
    readonly property int pad: Serp.px(12)
    readonly property real slideAt: host ? host.slideAt : 0
    readonly property real along: host ? host.anchorAlong : 0
    readonly property alias island: island

    focus: true
    Keys.onEscapePressed: Sidebar.open = false
    Component.onCompleted: forceActiveFocus()

    // the wallpaper for the liquid glass: the window spans the screen under the bar's zone
    SerpBackdrop {
        id: back
        screenName: root.screenName
        origin: Qt.point(0, Math.max(0, Serp.zoneNow))
    }

    Item {
        id: island
        readonly property real w: Serp.px(360)
        readonly property real h: root.vertical ? root.height - root.gap * 2 : Math.min(head.height + flick.contentHeight + root.pad * 3, root.height - root.gap * 2)
        readonly property real restX: root.edge === "left" ? root.gap : root.edge === "right" ? root.width - w - root.gap : Math.max(root.gap, Math.min(root.width - w - root.gap, root.along - w / 2))
        readonly property real restY: root.vertical || root.edge === "top" ? root.gap : root.height - h - root.gap
        width: w
        height: h
        x: restX + (root.edge === "left" ? -1 : root.edge === "right" ? 1 : 0) * root.slideAt * (w + root.gap * 2)
        y: restY + (root.edge === "top" ? -1 : root.edge === "bottom" ? 1 : 0) * root.slideAt * (h + root.gap * 2)
        opacity: 1 - root.slideAt * 0.6

        SGlass {
            anchors.fill: parent
            backdrop: back
            radius: Math.min(Serp.radius * 1.4, Serp.px(24))
        }
        // a click on the island is not a click beside it (the window's catcher shuts it)
        MouseArea {
            anchors.fill: parent
        }

        // ---- the head: the name and ×
        Item {
            id: head
            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            height: Serp.px(28)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Serp.px(8)
                SIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "panel-left"
                    color: Serp.accent
                }
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t("Боковая панель", "Sidebar")
                    size: Serp.px(14)
                    bold: true
                }
            }
            SButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Sidebar.open = false
                SIcon {
                    name: "x"
                    size: Serp.px(14)
                    color: Serp.subtext1
                }
            }
        }

        Flickable {
            id: flick
            anchors.top: head.bottom
            anchors.topMargin: root.pad
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.pad
            anchors.rightMargin: root.pad
            anchors.bottomMargin: root.pad
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: flick.width
                spacing: Serp.px(10)

                // ---- quick toggles: rounded tiles, the accent when on
                SerpSidebarCard {
                    visible: Sidebar.has("toggles")
                    width: col.width
                    title: I18n.t("Быстрые", "Quick")
                    Grid {
                        id: tiles
                        width: parent.width
                        columns: 3
                        spacing: Serp.px(6)
                        Repeater {
                            model: root.toggles
                            Rectangle {
                                id: tile
                                required property var modelData
                                readonly property bool on: !!modelData.on
                                width: (tiles.width - tiles.spacing * 2) / 3
                                height: Serp.px(62)
                                radius: Serp.radiusSmall
                                color: on ? Serp.accent : tileMouse.containsMouse ? Qt.lighter(Serp.surface1, 1.15) : Serp.surface1
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Serp.quick
                                    }
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: Serp.px(5)
                                    scale: tileMouse.pressed ? 0.94 : 1
                                    SIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: root.lucide(tile.modelData)
                                        size: Serp.px(18)
                                        color: tile.on ? Serp.onAccent : Serp.text
                                    }
                                    SText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: tile.width - Serp.px(8)
                                        horizontalAlignment: Text.AlignHCenter
                                        text: tile.modelData.label
                                        size: Serp.smallSize
                                        color: tile.on ? Serp.onAccent : Serp.subtext1
                                    }
                                }
                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: tile.modelData.act()
                                }
                            }
                        }
                    }
                }

                // ---- media
                SerpSidebarCard {
                    visible: Sidebar.has("media") && !!Lyrics.player && Lyrics.title !== ""
                    width: col.width
                    title: I18n.t("Музыка", "Music")
                    MusicPlayer {
                        width: parent.width
                        height: implicitHeight
                        screenName: root.screenName
                    }
                    SText {
                        visible: Lyrics.hasLyrics && Lyrics.current !== ""
                        width: parent.width
                        text: "♪ " + Lyrics.current
                        color: Serp.accent
                    }
                }

                // ---- sound: the output and the microphone
                SerpSidebarCard {
                    visible: Sidebar.has("sound")
                    width: col.width
                    title: I18n.t("Звук", "Sound")
                    Repeater {
                        model: [
                            {
                                "icon": Audio.muted ? "volume-x" : "volume-2",
                                "muted": Audio.muted,
                                "value": Audio.volume,
                                "ready": Audio.ready,
                                "set": v => Audio.setVolume(v),
                                "mute": () => Audio.toggleMute()
                            },
                            {
                                "icon": "mic",
                                "muted": Audio.micMuted,
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
                            width: parent.width
                            spacing: Serp.px(8)
                            enabled: modelData.ready
                            opacity: enabled ? 1 : 0.5
                            SButton {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Serp.px(34)
                                height: Serp.px(34)
                                radius: height / 2
                                flat: false
                                ground: vol.modelData.muted ? Qt.alpha(Serp.red, 0.25) : Serp.surface1
                                onClicked: vol.modelData.mute()
                                SIcon {
                                    name: vol.modelData.icon
                                    color: vol.modelData.muted ? Serp.red : Serp.text
                                }
                            }
                            SSlider {
                                anchors.verticalCenter: parent.verticalCenter
                                width: vol.width - x
                                value: vol.modelData.value
                                onMoved: v => vol.modelData.set(v)
                            }
                        }
                    }
                    // the microphone's level (the pixel meter reads, a rounded bar shows)
                    Rectangle {
                        width: parent.width
                        height: Serp.px(6)
                        radius: height / 2
                        color: Serp.surface1
                        opacity: Audio.micMuted ? 0.4 : 1
                        PxLevelMeter {
                            id: meter
                            visible: false
                            node: Audio.source
                            active: Sidebar.open && Sidebar.has("sound")
                        }
                        Rectangle {
                            width: Math.max(parent.height, parent.width * meter.shown)
                            height: parent.height
                            radius: parent.radius
                            visible: meter.shown > 0.01
                            color: meter.clipping ? Serp.red : meter.shown > 0.8 ? Serp.yellow : Serp.green
                        }
                    }
                }

                // ---- system: the skin's own face of the monitor
                SerpSidebarCard {
                    visible: Sidebar.has("system")
                    width: col.width
                    title: I18n.t("Система", "System")
                    SerpW.SysmonWidget {
                        anchors.horizontalCenter: parent.horizontalCenter
                        screenName: root.screenName
                        size: "m"
                        awake: Sidebar.open
                        width: Math.min(parent.width, implicitWidth)
                        height: visible ? implicitHeight : 0
                    }
                }

                // ---- AI limits and other plugin blocks (manifest "sidebarWidget")
                Repeater {
                    model: Sidebar.has("ai") ? Plugins.sidebarWidgets : []
                    SerpSidebarCard {
                        id: block
                        required property var modelData
                        width: col.width
                        title: I18n.label(block.modelData.name)
                        Loader {
                            width: parent.width
                            Component.onCompleted: setSource(Plugins.url(block.modelData, block.modelData.sidebarWidget), {
                                "plugin": Plugins.context(block.modelData),
                                "width": block.width - Serp.px(24)
                            })
                        }
                    }
                }
            }
        }
    }

    // SidebarToggles' pixel icon names → Lucide (widgets/MacIcons.js)
    function lucide(t) {
        const byId = {
            "dnd": Config.notifications.dnd ? "bell-off" : "bell",
            "stream": "monitor",
            "awake": "sun-dim",
            "theme": Theme.dark ? "moon" : "sun",
            "night": "moon-star",
            "wifi": t.on ? "wifi" : "wifi-off",
            "bluetooth": "bluetooth",
            "quickshare": "airplay",
            "lyrics": "music",
            "blur": "sparkles",
            "mic": "mic",
            "shot": "scan",
            "rec": "circle-dot",
            "idle": "moon"
        };
        return byId[t.id] || MacIcons.fromPixel(t.icon) || "circle-help";
    }
}
