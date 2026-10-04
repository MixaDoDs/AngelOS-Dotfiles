pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Control Center of the Golden Gate skin: a glass panel under the menu bar's right end, laid out
// like macOS 26/27's (iOS-like tiles): Wi-Fi and Bluetooth as capsules (the round icon switches,
// the rest opens their settings), Now Playing as a big tile, Do Not Disturb, Dark Mode and a
// screenshot as round buttons, Display (the software brightness of this screen) and Sound as wide
// slider tiles. Every tile does what it says; a tile for hardware that isn't there isn't shown.
// Opens from the menu bar's switches icon (GoldenGate.panel === "cc"); Esc or a click outside closes.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name
    readonly property bool open: GoldenGate.panel === "cc" && GoldenGate.panelScreen === screenName
    readonly property int radios: (Wifi.hasWifi ? 1 : 0) + (Bt.available ? 1 : 0)
    readonly property real tile: GoldenGate.px(68)            // one slot
    readonly property real gap: GoldenGate.px(10)
    readonly property real pad: GoldenGate.px(12)
    readonly property color tileFill: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color tileOn: GoldenGate.accent

    screen: modelData
    visible: open || panel.opacity > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-maccc"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // takes input: everywhere but the menu bar while open (a click outside closes the panel)
    mask: Region {
        item: open ? full : null
        Region {
            item: bar
            intersection: Intersection.Subtract
        }
    }
    BackgroundEffect.blurRegion: Config.appearance.blur && open ? blurRegion : null
    Region {
        id: blurRegion
        item: panel
        radius: GoldenGate.panelRadius
    }
    Item {
        id: full
        anchors.fill: parent
    }
    Item {
        id: bar
        width: parent.width
        height: GoldenGate.barHeight
    }
    MouseArea {
        anchors.fill: parent
        onPressed: GoldenGate.closePanel()
    }

    component Capsule: Item {
        id: cap
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        signal toggled
        signal opened
        width: win.tile * 2 + win.gap
        height: win.tile
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: win.tileFill
        }
        Rectangle {
            id: knob
            x: GoldenGate.px(10)
            anchors.verticalCenter: parent.verticalCenter
            width: GoldenGate.px(38)
            height: width
            radius: width / 2
            color: cap.on ? win.tileOn : GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.1)
            MacIcon {
                anchors.centerIn: parent
                name: cap.icon
                size: GoldenGate.px(19)
                stroke: 2
                color: cap.on ? "#ffffff" : GoldenGate.label
            }
            MouseArea {
                anchors.fill: parent
                onClicked: cap.toggled()
            }
        }
        Column {
            anchors.left: knob.right
            anchors.leftMargin: GoldenGate.px(8)
            anchors.right: parent.right
            anchors.rightMargin: GoldenGate.px(8)
            anchors.verticalCenter: parent.verticalCenter
            // as on macOS a long label goes on to the next line ("Do Not / Disturb")
            MacText {
                width: parent.width
                text: cap.title
                semibold: true
                wrapMode: Text.WordWrap
                maximumLineCount: cap.sub ? 1 : 2
            }
            MacText {
                width: parent.width
                text: cap.sub
                size: GoldenGate.smallSize
                color: GoldenGate.secondaryLabel
                visible: text !== ""
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: knob.x + knob.width
            onClicked: cap.opened()
        }
    }
    component FocusCapsule: Capsule {
        icon: "moon"
        title: I18n.t("Не беспокоить", "Do Not Disturb")
        sub: Config.notifications.dnd ? I18n.t("Вкл.", "On") : ""
        on: Config.notifications.dnd
        onToggled: Config.notifications.dnd = !Config.notifications.dnd
        onOpened: Config.notifications.dnd = !Config.notifications.dnd
    }
    component RecordCapsule: Capsule {
        icon: "circle-dot"
        title: I18n.t("Запись экрана", "Screen Recording")
        onToggled: opened()
        onOpened: {
            GoldenGate.closePanel();
            Capture.record();
        }
    }
    component Round: Item {
        id: rd
        property string icon: ""
        property string tip: ""
        property bool on: false
        signal clicked
        width: win.tile
        height: win.tile
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: rd.on ? win.tileOn : win.tileFill
            MacIcon {
                anchors.centerIn: parent
                name: rd.icon
                size: GoldenGate.px(24)
                stroke: 2
                color: rd.on ? "#ffffff" : GoldenGate.label
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: rd.clicked()
        }
    }
    component SliderTile: Item {
        id: st
        property string title: ""
        property string icon: ""
        property real value: 0
        property string action: ""        // an icon button at the end (sound: its settings)
        signal moved(real v)
        signal acted
        width: win.tile * 4 + win.gap * 3
        height: win.tile
        Rectangle {
            anchors.fill: parent
            radius: GoldenGate.px(22)
            color: win.tileFill
        }
        MacText {
            x: GoldenGate.px(16)
            y: GoldenGate.px(9)
            text: st.title
            semibold: true
        }
        Item {
            x: GoldenGate.px(14)
            y: GoldenGate.px(34)
            width: parent.width - GoldenGate.px(28) - (st.action ? GoldenGate.px(34) : 0)
            height: GoldenGate.px(22)
            Rectangle {
                id: track
                anchors.fill: parent
                radius: height / 2
                color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.1)
                Rectangle {
                    width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, st.value)))
                    height: parent.height
                    radius: height / 2
                    color: "#ffffff"
                    border.width: GoldenGate.dark ? 0 : 1
                    border.color: GoldenGate.separator
                }
                MacIcon {
                    x: GoldenGate.px(5)
                    anchors.verticalCenter: parent.verticalCenter
                    name: st.icon
                    size: GoldenGate.px(14)
                    stroke: 2
                    color: "#5a5a60"
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: m => st.moved(Math.max(0, Math.min(1, m.x / width)))
                    onPositionChanged: m => {
                        if (pressed)
                            st.moved(Math.max(0, Math.min(1, m.x / width)));
                    }
                }
            }
        }
        Rectangle {
            visible: st.action !== ""
            anchors.right: parent.right
            anchors.rightMargin: GoldenGate.px(10)
            y: GoldenGate.px(32)
            width: GoldenGate.px(26)
            height: width
            radius: width / 2
            color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.08)
            MacIcon {
                anchors.centerIn: parent
                name: st.action
                size: GoldenGate.px(15)
                stroke: 2
            }
            MouseArea {
                anchors.fill: parent
                onClicked: st.acted()
            }
        }
    }

    MacGlass {
        id: panel
        readonly property real w: win.tile * 4 + win.gap * 3 + win.pad * 2
        width: w
        height: grid.implicitHeight + win.pad * 2
        x: win.width - w - GoldenGate.px(8)
        y: GoldenGate.barHeight + GoldenGate.px(4)
        radius: GoldenGate.panelRadius
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.97
        transformOrigin: Item.TopRight
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(140)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Motion.ms(160)
                easing.type: Easing.OutCubic
            }
        }
        // a click inside never closes it
        MouseArea {
            anchors.fill: parent
        }
        focus: win.open
        Keys.onEscapePressed: GoldenGate.closePanel()

        Column {
            id: grid
            x: win.pad
            y: win.pad
            spacing: win.gap

            Row {
                spacing: win.gap
                Column {
                    spacing: win.gap
                    Capsule {
                        visible: Wifi.hasWifi
                        icon: Wifi.enabled ? "wifi" : "wifi-off"
                        title: "Wi-Fi"
                        sub: !Wifi.enabled ? I18n.t("Выкл.", "Off") : Wifi.connected ? Wifi.connected.name : I18n.t("Не подключено", "Not connected")
                        on: Wifi.enabled
                        onToggled: Wifi.setEnabled(!Wifi.enabled)
                        onOpened: {
                            GoldenGate.closePanel();
                            Shell.openSettings("network");
                        }
                    }
                    Capsule {
                        visible: Bt.available
                        icon: "bluetooth"
                        title: "Bluetooth"
                        sub: !Bt.enabled ? I18n.t("Выкл.", "Off") : Bt.connectedDevices.length ? (Bt.connectedDevices[0].name || "") : I18n.t("Вкл.", "On")
                        on: Bt.enabled
                        onToggled: Bt.setEnabled(!Bt.enabled)
                        onOpened: {
                            GoldenGate.closePanel();
                            Shell.openSettings("bluetooth");
                        }
                    }
                    // what Wi-Fi and Bluetooth leave free of the column
                    FocusCapsule {
                        visible: win.radios < 2
                    }
                    RecordCapsule {
                        visible: win.radios === 0 && Capture.canRecord
                    }
                }
                // Now Playing
                Item {
                    width: win.tile * 2 + win.gap
                    height: win.tile * 2 + win.gap
                    Rectangle {
                        anchors.fill: parent
                        radius: GoldenGate.px(22)
                        color: win.tileFill
                    }
                    Rectangle {
                        id: cover
                        x: GoldenGate.px(14)
                        y: GoldenGate.px(14)
                        width: GoldenGate.px(46)
                        height: width
                        radius: GoldenGate.px(9)
                        color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: Lyrics.artUrl
                            fillMode: Image.PreserveAspectCrop
                            visible: Lyrics.artUrl !== ""
                        }
                        MacIcon {
                            visible: Lyrics.artUrl === ""
                            anchors.centerIn: parent
                            name: "music"
                            color: GoldenGate.secondaryLabel
                        }
                    }
                    Column {
                        x: GoldenGate.px(14)
                        anchors.top: cover.bottom
                        anchors.topMargin: GoldenGate.px(8)
                        width: parent.width - GoldenGate.px(28)
                        MacText {
                            width: parent.width
                            text: Lyrics.player ? (Lyrics.title || I18n.t("Без названия", "Untitled")) : I18n.t("Ничего не играет", "Not Playing")
                            semibold: true
                        }
                        MacText {
                            width: parent.width
                            text: Lyrics.artist
                            visible: text !== ""
                            size: GoldenGate.smallSize
                            color: GoldenGate.secondaryLabel
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: GoldenGate.px(10)
                        spacing: GoldenGate.px(18)
                        opacity: Lyrics.player ? 1 : 0.35
                        Repeater {
                            model: [["skip-back", "previous"], [Lyrics.playing ? "pause" : "play", "togglePlaying"], ["skip-forward", "next"]]
                            MacIcon {
                                required property var modelData
                                name: modelData[0]
                                size: GoldenGate.px(22)
                                filled: true
                                stroke: 1.5
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !!Lyrics.player
                                    onClicked: Lyrics.player[parent.modelData[1]]()
                                }
                            }
                        }
                    }
                }
            }
            // the rows of the reference: [Screen Recording][Mission Control][Lock] and
            // [Dark Mode][Screenshot][Do Not Disturb] under Wi-Fi and Bluetooth; four round
            // buttons in one row when the column above took the capsules
            Row {
                visible: win.radios === 2
                spacing: win.gap
                RecordCapsule {
                    visible: Capture.canRecord
                }
                Round {
                    icon: "layout-grid"
                    onClicked: {
                        GoldenGate.closePanel();
                        Niri.toggleOverview();
                    }
                }
                Round {
                    icon: "lock"
                    onClicked: {
                        GoldenGate.closePanel();
                        Shell.lock();
                    }
                }
            }
            Row {
                spacing: win.gap
                Round {
                    icon: "contrast"
                    on: Theme.dark
                    onClicked: Config.appearance.mode = Theme.dark ? "light" : "dark"
                }
                Round {
                    icon: "scan"
                    onClicked: {
                        GoldenGate.closePanel();
                        Capture.screenshot();
                    }
                }
                FocusCapsule {
                    visible: win.radios === 2
                }
                Round {
                    visible: win.radios < 2
                    icon: "layout-grid"
                    onClicked: {
                        GoldenGate.closePanel();
                        Niri.toggleOverview();
                    }
                }
                Round {
                    visible: win.radios < 2
                    icon: "lock"
                    onClicked: {
                        GoldenGate.closePanel();
                        Shell.lock();
                    }
                }
            }
            SliderTile {
                title: I18n.t("Дисплей", "Display")
                icon: "sun"
                value: ScreenTune.brightnessOf(win.screenName)
                onMoved: v => ScreenTune.setTune(win.screenName, "brightness", Math.max(0.3, v))
            }
            SliderTile {
                visible: Audio.ready
                title: I18n.t("Звук", "Sound")
                icon: Audio.muted ? "volume-x" : "volume-2"
                value: Audio.volume
                action: "settings"
                onMoved: v => Audio.setVolume(v)
                onActed: {
                    GoldenGate.closePanel();
                    Shell.openSettings("sound");
                }
            }
        }
    }

    RightClickGuard {}
}
