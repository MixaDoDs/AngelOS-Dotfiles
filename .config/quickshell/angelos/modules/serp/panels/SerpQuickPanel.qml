pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.serp

// serp-skin: Serpantinum's system panel (syspanel) with angelOS inside — you and the angel, the
// sound / mic / brightness sliders, five quick tiles (Wi-Fi, Bluetooth, Do not disturb, Stay awake,
// Eco), the Wi-Fi networks when asked, the latest notifications, and the power row (hold to
// confirm). Rows slide in one after another (0/30/55/80/105/130 ms).
Item {
    id: root
    property string screenName: ""
    property real progress: 1
    property bool netsOpen: false

    function rowIn(i) {
        // each row's own share of the progress: a cascade
        return Math.max(0, Math.min(1, (progress - [0, 0.06, 0.11, 0.16, 0.21, 0.26][Math.min(i, 5)]) / 0.74));
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Serp.radius * 1.4, 24)
        color: Serp.ground
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }
    MouseArea {
        anchors.fill: parent
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: Serp.px(10)
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: Serp.px(8)

            // ---- you ----
            SCard {
                width: col.width
                height: Serp.px(58)
                opacity: root.rowIn(0)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Serp.px(12)
                    anchors.rightMargin: Serp.px(8)
                    spacing: Serp.px(10)
                    Rectangle {
                        Layout.preferredWidth: Serp.px(36)
                        Layout.preferredHeight: Serp.px(36)
                        radius: width / 2
                        color: Serp.surface1
                        clip: true
                        SIcon {
                            anchors.centerIn: parent
                            name: Angel.demon ? "angel-horns" : "angel"
                            size: Serp.px(20)
                            color: Serp.accent
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: Serp.px(1)
                        SText {
                            width: parent.width
                            text: Quickshell.env("USER") || "angel"
                            size: Serp.px(15)
                            black: true
                        }
                        SText {
                            width: parent.width
                            text: Angel.demon ? "angelOS · ад правит" : "angelOS · Serpantinum"
                            size: Serp.px(10)
                            dim: true
                        }
                    }
                    SButton {
                        SIcon {
                            name: "settings"
                        }
                        onClicked: {
                            Serp.closePanel();
                            Serp.settingsOpen = true;
                        }
                    }
                    SButton {
                        SIcon {
                            name: "sliders-horizontal"
                        }
                        onClicked: {
                            Serp.closePanel();
                            Shell.openSettings("", "");
                        }
                    }
                }
            }

            // ---- sliders ----
            SCard {
                width: col.width
                height: sliders.implicitHeight + Serp.px(20)
                opacity: root.rowIn(1)
                Column {
                    id: sliders
                    anchors.centerIn: parent
                    width: parent.width - Serp.px(20)
                    spacing: Serp.px(8)
                    component Line: RowLayout {
                        id: line
                        property string icon
                        property real value
                        property color fill: Serp.accent
                        property bool off: false
                        signal moved(real v)
                        signal iconClicked
                        width: parent.width
                        spacing: Serp.px(8)
                        SButton {
                            flat: false
                            ground: Serp.surface1
                            implicitWidth: Serp.px(34)
                            implicitHeight: Serp.px(34)
                            SIcon {
                                name: line.icon
                                color: line.off ? Serp.subtext0 : Serp.text
                            }
                            onClicked: line.iconClicked()
                        }
                        SSlider {
                            Layout.fillWidth: true
                            value: line.value
                            fill: line.off ? Serp.surface2 : line.fill
                            onMoved: v => line.moved(v)
                        }
                        SText {
                            Layout.preferredWidth: Serp.px(38)
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(line.value * 100) + "%"
                            size: Serp.px(11)
                            bold: true
                        }
                    }
                    Line {
                        visible: Audio.ready
                        icon: SerpIcons.volume()
                        value: Audio.volume
                        off: Audio.muted
                        fill: Qt.lighter(Serp.blue, 1.15)
                        onMoved: v => Audio.setVolume(v)
                        onIconClicked: Audio.toggleMute()
                    }
                    Line {
                        visible: Audio.ready && !!Audio.source
                        icon: "mic"
                        value: Audio.micVolume
                        off: Audio.micMuted
                        fill: Serp.teal
                        onMoved: v => {
                            if (Audio.source && Audio.source.audio)
                                Audio.source.audio.volume = v;
                        }
                        onIconClicked: Audio.toggleMic()
                    }
                    Line {
                        visible: Backlight.available
                        icon: "sun"
                        value: Backlight.level
                        fill: Qt.lighter(Serp.mauve, 1.1)
                        onMoved: v => Backlight.set(Math.max(0.02, v), true)
                    }
                }
            }

            // ---- quick tiles ----
            Item {
                width: col.width
                height: Serp.px(76)
                opacity: root.rowIn(2)
                Row {
                    id: tiles
                    anchors.fill: parent
                    spacing: Serp.px(6)
                    readonly property real tileW: (width - spacing * 4) / 5
                    component Tile: Rectangle {
                        id: tile
                        property string icon
                        property string label
                        property string sub: ""
                        property bool on: false
                        property bool present: true
                        signal clicked
                        signal rightClicked
                        width: tiles.tileW
                        height: tiles.height
                        radius: Serp.radiusSmall
                        opacity: present ? 1 : 0.35
                        color: on ? Serp.accent : tma.containsMouse ? Serp.surface1 : Serp.surface0
                        scale: tma.pressed ? 0.95 : 1
                        Behavior on color {
                            ColorAnimation {
                                duration: Serp.normal
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Serp.quick
                                easing.type: Easing.OutCubic
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            width: parent.width - Serp.px(8)
                            spacing: Serp.px(4)
                            SIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: tile.icon
                                size: Serp.px(18)
                                color: tile.on ? Serp.onAccent : Serp.subtext0
                            }
                            SText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.label
                                size: Serp.px(9.5)
                                bold: true
                                color: tile.on ? Serp.onAccent : Serp.text
                            }
                            SText {
                                visible: tile.sub !== ""
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.sub
                                size: Serp.px(8.5)
                                color: tile.on ? Qt.alpha(Serp.onAccent, 0.75) : Serp.subtext0
                            }
                        }
                        MouseArea {
                            id: tma
                            anchors.fill: parent
                            enabled: tile.present
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: m => m.button === Qt.RightButton ? tile.rightClicked() : tile.clicked()
                        }
                    }
                    Tile {
                        icon: SerpIcons.net()
                        label: "Wi-Fi"
                        present: Wifi.hasWifi
                        on: Wifi.enabled
                        sub: Wifi.connected ? Wifi.connected.name : ""
                        onClicked: Wifi.setEnabled(!Wifi.enabled)
                        onRightClicked: root.netsOpen = !root.netsOpen
                    }
                    Tile {
                        icon: "bluetooth"
                        label: "Bluetooth"
                        present: Bt.available
                        on: Bt.enabled
                        sub: Bt.connectedDevices.length ? Bt.connectedDevices.length + " подкл." : ""
                        onClicked: Bt.setEnabled(!Bt.enabled)
                    }
                    Tile {
                        icon: Config.notifications.dnd ? "bell-off" : "bell"
                        label: "Не беспок."
                        on: Config.notifications.dnd
                        onClicked: Config.notifications.dnd = !Config.notifications.dnd
                    }
                    Tile {
                        icon: "sun-dim"
                        label: "Не спать"
                        on: Awake.active
                        sub: Awake.active && Awake.reason !== "manual" ? "авто" : ""
                        onClicked: Awake.set("toggle")
                    }
                    Tile {
                        icon: "gauge"
                        label: "Эко"
                        on: Power.eco
                        onClicked: Power.toggleEco()
                    }
                }
            }

            // ---- Wi-Fi networks (right click on the Wi-Fi tile) ----
            SCard {
                visible: root.netsOpen && Wifi.hasWifi
                width: col.width
                height: Math.min(Serp.px(240), nets.contentHeight + Serp.px(16))
                ListView {
                    id: nets
                    anchors.fill: parent
                    anchors.margins: Serp.px(8)
                    clip: true
                    spacing: Serp.px(2)
                    model: Wifi.networks
                    delegate: SButton {
                        id: net
                        required property var modelData
                        width: nets.width
                        implicitHeight: Serp.px(32)
                        active: Wifi.connected === modelData
                        RowLayout {
                            width: nets.width - Serp.px(20)
                            spacing: Serp.px(8)
                            SIcon {
                                name: net.modelData.signalStrength < 0.4 ? "wifi-low" : "wifi"
                                size: Serp.px(14)
                            }
                            SText {
                                Layout.fillWidth: true
                                text: net.modelData.name || "?"
                                size: Serp.px(12)
                            }
                            SIcon {
                                visible: Wifi.connected === net.modelData
                                name: "check"
                                size: Serp.px(14)
                                color: Serp.accent
                            }
                        }
                        onClicked: if (Wifi.connected !== modelData && !Wifi.needsPassword(modelData))
                            Wifi.connect(modelData, "")
                        else if (Wifi.connected !== modelData) {
                            Serp.closePanel();
                            Shell.openSettings("network", "");
                        }
                    }
                }
            }

            // ---- notifications ----
            SCard {
                width: col.width
                height: Math.max(Serp.px(120), notifCol.implicitHeight + Serp.px(20))
                opacity: root.rowIn(3)
                Column {
                    id: notifCol
                    x: Serp.px(10)
                    y: Serp.px(10)
                    width: parent.width - Serp.px(20)
                    spacing: Serp.px(6)
                    RowLayout {
                        width: parent.width
                        SText {
                            Layout.fillWidth: true
                            text: "Уведомления"
                            size: Serp.px(13)
                            bold: true
                        }
                        SButton {
                            visible: Notifs.history.length > 0
                            SText {
                                text: "Очистить"
                                size: Serp.px(11)
                                dim: true
                            }
                            onClicked: Serp.clearNotifs()  // the cards fly off first
                        }
                    }
                    SText {
                        visible: Notifs.history.length === 0
                        text: "Тишина. Ангел доволен."
                        size: Serp.px(12)
                        dim: true
                    }
                    Repeater {
                        model: Notifs.history.slice(0, 4)
                        SerpNotifCard {
                            width: notifCol.width
                        }
                    }
                    SButton {
                        visible: Notifs.history.length > 4
                        SText {
                            text: "Все уведомления (" + Notifs.history.length + ")"
                            size: Serp.px(11)
                            color: Serp.accent
                        }
                        onClicked: Serp.openPanel("notifs", root.screenName)
                    }
                }
            }

            // ---- power: hold to confirm ----
            Item {
                width: col.width
                height: Serp.px(70)
                opacity: root.rowIn(4)
                Row {
                    id: power
                    anchors.fill: parent
                    spacing: Serp.px(6)
                    readonly property real unit: (width - spacing * 3) / (1 + 1 + 1.6 + 1.9)
                    SHoldButton {
                        width: power.unit
                        height: power.height
                        icon: "lock"
                        label: "Замок"
                        weight: 1
                        onConfirmed: {
                            Serp.closePanel();
                            Shell.sessionNow("lock");
                        }
                    }
                    SHoldButton {
                        width: power.unit
                        height: power.height
                        icon: "moon"
                        label: "Сон"
                        weight: 1
                        onConfirmed: {
                            Serp.closePanel();
                            Shell.sessionNow("suspend");
                        }
                    }
                    SHoldButton {
                        width: power.unit * 1.6
                        height: power.height
                        icon: "refresh-cw"
                        label: "Перезагрузка"
                        weight: 1.5
                        tint: Serp.yellow
                        onConfirmed: Shell.sessionNow("reboot")
                    }
                    SHoldButton {
                        width: power.unit * 1.9
                        height: power.height
                        icon: "power"
                        label: "Выключить"
                        weight: 2.2
                        tint: Serp.red
                        onConfirmed: Shell.sessionNow("poweroff")
                    }
                }
            }
            SText {
                width: col.width
                horizontalAlignment: Text.AlignHCenter
                text: "держи кнопку, пока не заполнится"
                size: Serp.px(9.5)
                dim: true
                opacity: root.rowIn(5) * 0.7
            }
        }
    }
}
