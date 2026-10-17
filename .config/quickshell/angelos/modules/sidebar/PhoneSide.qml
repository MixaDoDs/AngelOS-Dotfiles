pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The phone's screen on its side (Phone, Sidebar.turned): a wide screen with three tabs —
// sound (the outputs, the volume, each program's), wallpapers (a click puts one everywhere)
// and theme (light / dark / auto, the palette, blur). ◀ ▶ (keys or arrows) change the tab.
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property bool hell: phone.hell
    readonly property color ink: hell ? Theme.hellText : Theme.text
    readonly property color dimInk: hell ? Theme.hellTextDim : Theme.textDim
    // the tabs are built only while it lies on its side
    readonly property bool live: phone.turn > 0.5

    readonly property var tabs: [["sound", I18n.t("Звук", "Sound"), "speaker"], ["walls", I18n.t("Обои", "Wallpapers"), "image"], ["theme", I18n.t("Тема", "Theme"), "palette"]]
    readonly property int at: Math.max(0, tabs.findIndex(t => t[0] === Sidebar.side))
    function leaf(step) {
        Sidebar.side = tabs[(at + step + tabs.length) % tabs.length][0];
    }

    // ---- the tabs ----
    Rectangle {
        id: bar
        width: parent.width
        height: root.k * 13
        color: Qt.alpha(root.phone.trim, 0.18)
        Row {
            anchors.fill: parent
            Repeater {
                model: root.tabs
                Rectangle {
                    id: tab
                    required property var modelData
                    required property int index
                    width: bar.width / root.tabs.length
                    height: bar.height
                    color: index === root.at ? root.phone.trim : tabMouse.containsMouse ? Qt.alpha(root.phone.trim, 0.3) : "transparent"
                    Row {
                        anchors.centerIn: parent
                        spacing: root.k * 2
                        PxIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: tab.modelData[2]
                            fill: tab.index === root.at ? "#ffffff" : root.phone.trim
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData[1]
                            kind: "tiny"
                            color: tab.index === root.at ? Theme.selectText : root.ink
                        }
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sidebar.side = tab.modelData[0]
                    }
                }
            }
        }
    }

    Loader {
        x: root.k * 3
        y: bar.height + root.k * 3
        width: parent.width - root.k * 6
        height: parent.height - y - root.k * 3
        active: root.live
        sourceComponent: Sidebar.side === "walls" ? walls : Sidebar.side === "theme" ? theme : sound
    }

    // ---- sound: outputs and the volume on the left, the programs on the right ----
    Component {
        id: sound
        Item {
            Column {
                id: outs
                width: parent.width * 0.46
                spacing: root.k * 2
                PxText {
                    text: I18n.t("Выход", "Output")
                    kind: "tiny"
                    color: root.dimInk
                }
                Repeater {
                    model: Audio.sinks.slice(0, 5)
                    PxButton {
                        required property var modelData
                        width: outs.width
                        compact: true
                        hell: root.hell
                        checked: !!Audio.sink && Audio.sink.id === modelData.id
                        icon: checked ? "check" : "speaker"
                        text: Audio.nodeName(modelData)
                        kind: "tiny"
                        onClicked: Audio.setDefaultSink(modelData)
                    }
                }
                Row {
                    width: outs.width
                    spacing: root.k * 2
                    PxButton {
                        compact: true
                        hell: root.hell
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Audio.muted ? "speakerMute" : "speaker"
                        onClicked: Audio.toggleMute()
                    }
                    PxSlider {
                        width: outs.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0
                        to: 1.5
                        value: Audio.volume
                        valueScale: 100
                        suffix: "%"
                        onMoved: v => Audio.setVolume(v)
                    }
                }
            }
            PxScroll {
                id: apps
                x: parent.width * 0.52
                width: parent.width * 0.48
                height: parent.height
                contentHeight: list.implicitHeight
                Column {
                    id: list
                    width: apps.flick.width
                    spacing: root.k * 2
                    PxText {
                        text: Audio.appStreams.length ? I18n.t("Программы", "Programs") : I18n.t("сейчас ничего не звучит", "Nothing is playing")
                        kind: "tiny"
                        color: root.dimInk
                    }
                    Repeater {
                        model: Audio.appStreams
                        Column {
                            id: s
                            required property var modelData
                            width: list.width
                            PxText {
                                width: parent.width
                                elide: Text.ElideRight
                                text: Audio.streamName(s.modelData)
                                kind: "tiny"
                                color: root.ink
                            }
                            PxSlider {
                                width: parent.width
                                from: 0
                                to: 1.5
                                enabled: !!s.modelData.audio
                                value: s.modelData.audio ? s.modelData.audio.volume : 1
                                valueScale: 100
                                suffix: "%"
                                onMoved: v => {
                                    if (s.modelData.audio)
                                        s.modelData.audio.volume = v;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- wallpapers: a grid of them, a click puts one everywhere. A GridView: only the rows in
    // sight are made and decoded (a thousand pictures is a usual folder) ----
    Component {
        id: walls
        GridView {
            id: wallGrid
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: Math.floor(width / 4)
            cellHeight: Math.round(cellWidth * 0.62)
            cacheBuffer: cellHeight * 2
            model: Wallpapers.heads
            delegate: Item {
                id: wall
                required property string modelData
                width: wallGrid.cellWidth
                height: wallGrid.cellHeight
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.k
                    color: Theme.sunken
                    border.width: wallMouse.containsMouse ? root.k : 0
                    border.color: root.phone.trim
                    Image {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        source: "file://" + Wallpapers.pick(wall.modelData, Sidebar.screenName)
                        sourceSize: Qt.size(192, 120)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: false
                    }
                }
                MouseArea {
                    id: wallMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpapers.setEverywhere(wall.modelData)
                }
            }
        }
    }

    // ---- theme: light / dark / auto, the palette, blur ----
    Component {
        id: theme
        PxScroll {
            id: themeScroll
            contentHeight: themeCol.implicitHeight
            Column {
                id: themeCol
                width: themeScroll.flick.width
                spacing: root.k * 3
                Row {
                    spacing: root.k * 2
                    Repeater {
                        model: [["light", I18n.t("Светлая", "Light"), "sun"], ["dark", I18n.t("Тёмная", "Dark"), "moon"], ["auto", I18n.t("Авто", "Auto"), "clock"]]
                        PxButton {
                            required property var modelData
                            compact: true
                            hell: root.hell
                            checked: Config.appearance.mode === modelData[0]
                            icon: modelData[2]
                            text: modelData[1]
                            onClicked: Config.appearance.mode = modelData[0]
                        }
                    }
                    PxButton {
                        compact: true
                        hell: root.hell
                        checked: Config.appearance.blur
                        icon: "sparkle"
                        text: I18n.t("Блюр", "Blur")
                        onClicked: Config.appearance.blur = !Config.appearance.blur
                    }
                }
                PxText {
                    text: I18n.t("Палитра", "Palette")
                    kind: "tiny"
                    color: root.dimInk
                }
                Flow {
                    width: parent.width
                    spacing: root.k * 2
                    Repeater {
                        model: Object.keys(Theme.flavors)
                        Rectangle {
                            id: sw
                            required property string modelData
                            readonly property var f: Theme.flavors[modelData][Theme.night ? "dark" : "light"] || ({})
                            width: root.k * 22
                            height: root.k * 14
                            color: f.face || Theme.face
                            border.width: Config.appearance.flavor === modelData ? root.k : Math.max(1, root.k / 2)
                            border.color: Config.appearance.flavor === modelData ? root.phone.trim : Theme.edge
                            Row {
                                anchors.centerIn: parent
                                Repeater {
                                    model: [sw.f.accent, sw.f.accent2]
                                    Rectangle {
                                        required property var modelData
                                        width: root.k * 6
                                        height: root.k * 6
                                        color: modelData || "transparent"
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.appearance.flavor = sw.modelData
                            }
                        }
                    }
                }
                PxButton {
                    compact: true
                    hell: root.hell
                    icon: "gear"
                    text: I18n.t("Все настройки…", "All settings…")
                    onClicked: {
                        Sidebar.open = false;
                        Shell.openSettings("theme");
                    }
                }
            }
        }
    }
}
