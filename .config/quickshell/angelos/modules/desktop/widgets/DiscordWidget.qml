pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Who is in your Discord call (services/DiscordVoice):
//   S  the faces in a row (up to six, then +N)
//   M  the faces with names, a ring around whoever speaks
//   L  the same under the channel's name, up to ten
// The avatars are drawn without smoothing: small pixel portraits. Before the first time Discord
// has to allow it — a button here asks it (its own window comes up in Discord, once).
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    // the button to connect takes a click; a call only shows
    readonly property bool passive: DiscordVoice.state !== "auth"

    readonly property bool hellish: Theme.hell
    readonly property color ink: hellish ? Theme.hellText : Theme.text
    readonly property color inkDim: hellish ? Theme.hellTextDim : Theme.textDim
    readonly property color ring: hellish ? Theme.hellAccent : Theme.accent
    readonly property int faceSize: Theme.u * (size === "s" ? 16 : 14)
    readonly property int limit: size === "s" ? 6 : size === "l" ? 10 : 6
    readonly property var shown: DiscordVoice.users.slice(0, limit)
    readonly property int more: Math.max(0, DiscordVoice.users.length - limit)

    implicitWidth: Theme.u * (size === "s" ? 120 : size === "l" ? 140 : 124)
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: root.width
        spacing: Theme.u * 3

        // the channel (L), or what is going on when there is no call
        Row {
            visible: root.size === "l" && DiscordVoice.state === "call"
            spacing: Theme.u * 2
            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "speaker"
                pixel: Math.max(1, Theme.u - 1)
            }
            PxText {
                width: col.width - Theme.u * 12
                elide: Text.ElideRight
                kind: "title"
                color: root.ink
                text: DiscordVoice.channel
            }
        }
        PxText {
            visible: DiscordVoice.state !== "call" || DiscordVoice.users.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            color: root.inkDim
            text: DiscordVoice.state === "no-discord" ? I18n.t("Discord не запущен", "Discord is not running")
                : DiscordVoice.state === "auth" ? I18n.t("Покажу, кто в звонке, — Discord один раз спросит разрешение", "I'll show who is in the call — Discord asks once to allow it")
                : DiscordVoice.state === "authorizing" ? I18n.t("Подтверди в окне Discord…", "Allow it in Discord's window…")
                : DiscordVoice.state === "rpc-only" ? I18n.t("Этот клиент (Vesktop, Equibop…) не отдаёт звонок по RPC — нужен мост DevTools: docs/discord-voice.md", "This client (Vesktop, Equibop…) does not share calls over RPC — it needs the DevTools bridge: docs/discord-voice.md")
                : I18n.t("Не в звонке", "Not in a call")
        }
        PxText {
            visible: DiscordVoice.state === "auth" && DiscordVoice.error !== ""
            width: parent.width
            wrapMode: Text.Wrap
            kind: "tiny"
            color: Theme.danger
            text: DiscordVoice.error
        }
        PxButton {
            visible: DiscordVoice.state === "auth"
            compact: true
            accent: true
            icon: "headphones"
            text: I18n.t("Подключить Discord", "Connect Discord")
            onClicked: DiscordVoice.authorize()
        }

        // S: the faces in a row
        Flow {
            visible: root.size === "s" && DiscordVoice.state === "call"
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: root.size === "s" ? root.shown : []
                Avatar {
                    required property var modelData
                    person: modelData
                }
            }
            PxText {
                visible: root.more > 0
                height: root.faceSize
                verticalAlignment: Text.AlignVCenter
                color: root.inkDim
                text: "+" + root.more
            }
        }

        // M, L: a face and a name a line
        Column {
            visible: root.size !== "s" && DiscordVoice.state === "call"
            width: parent.width
            spacing: Theme.u * 2
            Repeater {
                model: root.size !== "s" ? root.shown : []
                Row {
                    id: line
                    required property var modelData
                    spacing: Theme.u * 3
                    Avatar {
                        person: line.modelData
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: col.width - root.faceSize - Theme.u * 16
                        elide: Text.ElideRight
                        color: line.modelData.speaking ? root.ring : root.ink
                        text: line.modelData.name
                    }
                    PxIcon {
                        visible: line.modelData.muted || line.modelData.deaf
                        anchors.verticalCenter: parent.verticalCenter
                        name: line.modelData.deaf ? "headphones" : "mic"
                        pixel: Math.max(1, Theme.u - 1)
                        opacity: 0.55
                    }
                }
            }
            PxText {
                visible: root.more > 0
                kind: "tiny"
                color: root.inkDim
                text: I18n.t("и ещё ", "and ") + root.more + I18n.t("", " more")
            }
        }
    }

    // a portrait: the picture without smoothing, a ring while speaking, dim when muted
    component Avatar: Item {
        id: av
        property var person: ({})
        width: root.faceSize + Theme.u * 2
        height: root.faceSize + Theme.u * 2
        Rectangle {
            anchors.fill: parent
            color: av.person.speaking ? root.ring : "transparent"
            border.width: Theme.u
            border.color: av.person.speaking ? root.ring : Qt.alpha(root.ink, 0.35)
        }
        Rectangle {
            x: Theme.u
            y: Theme.u
            width: root.faceSize
            height: root.faceSize
            color: Theme.mix(Theme.face, Theme.accent, 0.3)
            PxText {
                anchors.centerIn: parent
                visible: pic.status !== Image.Ready
                color: root.ink
                text: String(av.person.name || "?").charAt(0).toUpperCase()
            }
            Image {
                id: pic
                anchors.fill: parent
                source: av.person.avatar ? "file://" + av.person.avatar : ""
                sourceSize.width: 32
                sourceSize.height: 32
                fillMode: Image.PreserveAspectCrop
                smooth: false
                asynchronous: true
                opacity: av.person.muted || av.person.deaf ? 0.5 : 1
            }
        }
    }
}
