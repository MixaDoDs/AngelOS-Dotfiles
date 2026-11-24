pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.services
import qs.modules.serp
import "."

// serp-skin: angelOS's Discord widget (modules/desktop/widgets/DiscordWidget, services/
// DiscordVoice) in Serpantinum's face, same sizes and data:
//   S  the faces in a row (up to six, then +N)
//   M  a face and a name a line, a green ring around whoever speaks
//   L  the same under the channel's name (Bold, a «в голосе» chip), up to ten
// Round avatars, a green ring and a soft glow while speaking, muted / deafened marks in red.
// No call: one quiet centred line with an icon. Before the first time Discord has to allow it:
// the accent button «Подключить Discord» (DiscordVoice.authorize, as the original).
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    // the button to connect takes a click; a call only shows
    readonly property bool passive: DiscordVoice.state !== "auth"

    readonly property bool inCall: DiscordVoice.state === "call"
    readonly property int faceSize: Serp.px(size === "s" ? 34 : 28)
    readonly property int limit: size === "s" ? 6 : size === "l" ? 10 : 6
    readonly property var shown: DiscordVoice.users.slice(0, limit)
    readonly property int more: Math.max(0, DiscordVoice.users.length - limit)

    implicitWidth: Serp.px(size === "s" ? 250 : size === "l" ? 290 : 260)
    implicitHeight: Math.max(col.implicitHeight, Serp.px(size === "s" ? 40 : 56))

    Column {
        id: col
        width: root.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: Serp.px(10)

        // ---- L: the channel ----
        Row {
            visible: root.size === "l" && root.inCall
            width: parent.width
            spacing: Serp.px(8)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Serp.px(26)
                height: width
                radius: width / 2
                color: Serp.selected
                SIcon {
                    anchors.centerIn: parent
                    name: "volume-2"
                    size: Serp.px(14)
                    color: Serp.accent
                }
            }
            SText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - Serp.px(26) - chip.width - parent.spacing * 2)
                text: DiscordVoice.channel
                size: Serp.px(14)
                bold: true
            }
            Rectangle {
                id: chip
                anchors.verticalCenter: parent.verticalCenter
                height: Serp.px(20)
                width: chipRow.width + Serp.px(14)
                radius: height / 2
                color: Serp.surface0
                border.width: 1
                border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Serp.px(5)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Serp.px(6)
                        height: width
                        radius: width / 2
                        color: Serp.green
                    }
                    SText {
                        text: I18n.t("в голосе", "in voice")
                        size: Serp.px(10.5)
                        color: Serp.subtext0
                    }
                }
            }
        }

        // ---- no call (or nobody in it): one quiet line ----
        Column {
            visible: !root.inCall || DiscordVoice.users.length === 0
            width: parent.width
            spacing: Serp.px(6)
            SIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.size !== "s"
                name: DiscordVoice.state === "no-discord" ? "power" : DiscordVoice.state === "auth" ? "key-round" : DiscordVoice.state === "authorizing" ? "refresh-cw" : DiscordVoice.state === "rpc-only" ? "info" : "users"
                size: Serp.px(20)
                color: Serp.subtext0
            }
            SText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                size: Serp.px(12)
                color: Serp.subtext0
                text: DiscordVoice.state === "no-discord" ? I18n.t("Discord не запущен", "Discord is not running")
                    : DiscordVoice.state === "auth" ? I18n.t("Покажу, кто в звонке, — Discord один раз спросит разрешение", "I'll show who is in the call — Discord asks once to allow it")
                    : DiscordVoice.state === "authorizing" ? I18n.t("Подтверди в окне Discord…", "Allow it in Discord's window…")
                    : DiscordVoice.state === "rpc-only" ? I18n.t("Этот клиент (Vesktop, Equibop…) не отдаёт звонок по RPC — нужен мост DevTools: docs/discord-voice.md", "This client (Vesktop, Equibop…) does not share calls over RPC — it needs the DevTools bridge: docs/discord-voice.md")
                    : I18n.t("Не в звонке", "Not in a call")
            }
            SText {
                visible: DiscordVoice.state === "auth" && DiscordVoice.error !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                size: Serp.smallSize
                color: Serp.red
                text: DiscordVoice.error
            }
            // the button to connect: the accent's pill
            Rectangle {
                id: connect
                visible: DiscordVoice.state === "auth"
                anchors.horizontalCenter: parent.horizontalCenter
                height: Serp.px(30)
                width: connectRow.width + Serp.px(24)
                radius: height / 2
                color: connectMa.containsMouse ? Qt.lighter(Serp.accent, 1.1) : Serp.accent
                scale: connectMa.pressed ? 0.96 : 1
                Behavior on color {
                    ColorAnimation {
                        duration: Serp.quick
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Serp.quick
                        easing.type: Easing.OutCubic
                    }
                }
                Row {
                    id: connectRow
                    anchors.centerIn: parent
                    spacing: Serp.px(6)
                    SIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "plug-zap"
                        size: Serp.px(14)
                        color: Serp.onAccent
                    }
                    SText {
                        text: I18n.t("Подключить Discord", "Connect Discord")
                        size: Serp.px(12)
                        bold: true
                        color: Serp.onAccent
                    }
                }
                MouseArea {
                    id: connectMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DiscordVoice.authorize()
                }
            }
        }

        // ---- S: the faces in a row ----
        Flow {
            visible: root.size === "s" && root.inCall
            width: parent.width
            spacing: Serp.px(8)
            Repeater {
                model: root.size === "s" ? root.shown : []
                Avatar {
                    required property var modelData
                    person: modelData
                    badge: true
                }
            }
            Rectangle {
                visible: root.more > 0
                width: root.faceSize + Serp.px(6)
                height: width
                radius: width / 2
                color: Serp.surface0
                border.width: 1
                border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
                SText {
                    anchors.centerIn: parent
                    text: "+" + root.more
                    size: Serp.px(12)
                    bold: true
                    color: Serp.subtext0
                }
            }
        }

        // ---- M, L: a face and a name a line ----
        Column {
            visible: root.size !== "s" && root.inCall && DiscordVoice.users.length > 0
            width: parent.width
            spacing: Serp.px(4)
            Repeater {
                model: root.size !== "s" ? root.shown : []
                Rectangle {
                    id: line
                    required property var modelData
                    readonly property bool speaking: !!modelData.speaking
                    width: col.width
                    height: root.faceSize + Serp.px(10)
                    radius: Serp.radiusSmall
                    color: speaking ? Qt.alpha(Serp.green, 0.08) : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: Serp.quick
                        }
                    }
                    Avatar {
                        id: lineFace
                        x: Serp.px(2)
                        anchors.verticalCenter: parent.verticalCenter
                        person: line.modelData
                    }
                    SText {
                        anchors.left: lineFace.right
                        anchors.leftMargin: Serp.px(8)
                        anchors.right: marks.left
                        anchors.rightMargin: Serp.px(6)
                        anchors.verticalCenter: parent.verticalCenter
                        text: line.modelData.name || ""
                        size: Serp.px(13)
                        bold: line.speaking || !!line.modelData.me
                        color: line.speaking ? Serp.green : line.modelData.muted || line.modelData.deaf ? Serp.subtext0 : Serp.text
                    }
                    Row {
                        id: marks
                        anchors.right: parent.right
                        anchors.rightMargin: Serp.px(6)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Serp.px(6)
                        MuteMark {
                            visible: !!line.modelData.muted && !line.modelData.deaf
                            deaf: false
                        }
                        MuteMark {
                            visible: !!line.modelData.deaf
                            deaf: true
                        }
                    }
                }
            }
            SText {
                visible: root.more > 0
                x: Serp.px(4)
                text: I18n.t("и ещё ", "and ") + root.more + I18n.t("", " more")
                size: Serp.smallSize
                color: Serp.subtext0
            }
        }
    }

    // muted: the mic struck through; deafened: the speaker crossed out — both in red
    component MuteMark: Item {
        id: mm
        property bool deaf: false
        property real side: Serp.px(14)
        width: side
        height: side
        SIcon {
            anchors.centerIn: parent
            name: mm.deaf ? "volume-x" : "mic"
            size: mm.side
            color: Serp.red
        }
        Rectangle {
            visible: !mm.deaf
            anchors.centerIn: parent
            width: Serp.px(1.8)
            height: mm.side * 1.15
            radius: width / 2
            rotation: -45
            color: Serp.red
            antialiasing: true
        }
    }

    // a round portrait: a green ring and a soft glow while speaking, dimmed when muted
    component Avatar: Item {
        id: av
        property var person: ({})
        property bool badge: false            // S: the mute mark on the face itself
        readonly property bool speaking: !!person.speaking
        readonly property bool hushed: !!person.muted || !!person.deaf
        width: root.faceSize + Serp.px(6)
        height: width
        // the glow
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + Serp.px(4)
            height: width
            radius: width / 2
            color: Qt.alpha(Serp.green, 0.22)
            opacity: av.speaking ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Serp.quick
                }
            }
        }
        // the ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Serp.px(2)
            border.color: av.speaking ? Serp.green : Serp.line
            Behavior on border.color {
                ColorAnimation {
                    duration: Serp.quick
                }
            }
        }
        Item {
            anchors.centerIn: parent
            width: root.faceSize
            height: width
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Serp.surface1
                SText {
                    anchors.centerIn: parent
                    visible: pic.status !== Image.Ready
                    text: String(av.person.name || "?").charAt(0).toUpperCase()
                    size: parent.width * 0.42
                    bold: true
                    color: Serp.subtext1
                }
            }
            Image {
                id: pic
                anchors.fill: parent
                visible: false
                source: av.person.avatar ? "file://" + av.person.avatar : ""
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
            Rectangle {
                id: picMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
                antialiasing: true
            }
            MultiEffect {
                anchors.fill: parent
                visible: pic.status === Image.Ready
                source: pic
                maskEnabled: true
                maskSource: picMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
                opacity: av.hushed ? 0.5 : 1
            }
        }
        Rectangle {
            visible: av.badge && av.hushed
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -Serp.px(2)
            width: Serp.px(16)
            height: width
            radius: width / 2
            color: Serp.surface0
            border.width: 1
            border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            MuteMark {
                anchors.centerIn: parent
                side: Serp.px(10)
                deaf: !!av.person.deaf
            }
        }
    }
}
