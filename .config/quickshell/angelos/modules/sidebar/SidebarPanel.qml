pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.desktop
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

    readonly property var toggles: quick.list
    SidebarToggles {
        id: quick
    }

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
                MusicPlayer {
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
                awake: Sidebar.open
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
