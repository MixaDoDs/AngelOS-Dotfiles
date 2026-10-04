import QtQuick
import qs.config

// A card to pick the settings skin (Config.settingsUi.skin): a tiny drawing of the
// window in that skin and its name. In the first-run wizard, on the settings home (until
// one is picked) and in Appearance.
Item {
    id: root

    property string skin: "classic"
    readonly property bool checked: (Config.settingsUi.skin || "classic") === skin
    signal picked

    readonly property var names: ({
            "classic": [I18n.t("Классика angelOS", "angelOS classic"), I18n.t("пиксельные окна Win98", "Win98 pixel windows")],
            "windose": ["Windose ♡", I18n.t("ОС из NEEDY GIRL OVERDOSE", "NEEDY GIRL OVERDOSE's OS")],
            "stream": [I18n.t("Стрим", "Stream"), I18n.t("как эфир Ame: LIVE и чат", "like Ame's stream: LIVE and chat")],
            "goldengate": ["Golden Gate", I18n.t("весь стол как macOS 27", "the whole desktop like macOS 27")]
        })
    implicitWidth: Theme.u * 92
    implicitHeight: pic.height + caption.implicitHeight + hint.implicitHeight + Theme.u * 12

    PxBox {
        anchors.fill: parent
        color: root.skin === "windose" ? root.checked ? Theme.mix(Theme.windosePaper, Theme.windoseRose, 0.18) : Theme.windosePaper : root.checked ? Theme.mix(Theme.face, Theme.accent, 0.25) : mouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : Theme.face
        edgeColor: root.skin === "windose" ? Theme.windoseLine : Theme.edge
        hiColor: root.skin === "windose" ? Theme.windosePaper : Theme.hi
        loColor: root.skin === "windose" ? Theme.windoseLine : Theme.lo
        sunken: root.checked
    }

    // the little window
    Item {
        id: pic
        x: Theme.u * 4
        y: Theme.u * 4
        width: parent.width - Theme.u * 8
        height: Math.round(width * 0.62)
        clip: true
        // classic: a bevelled window, a title bar, a grid of raised tiles
        Rectangle {
            visible: root.skin === "classic"
            anchors.fill: parent
            color: Theme.face
            border.width: Math.max(1, Theme.u / 2)
            border.color: Theme.edge
            Rectangle {
                width: parent.width
                height: parent.height * 0.16
                color: Theme.menuHeader
            }
            Grid {
                x: parent.width * 0.08
                y: parent.height * 0.26
                columns: 4
                spacing: parent.width * 0.03
                Repeater {
                    model: 8
                    Rectangle {
                        width: pic.width * 0.19
                        height: pic.height * 0.28
                        color: Theme.faceAlt
                        border.width: 1
                        border.color: Theme.hi
                    }
                }
            }
        }
        // windose: checks, a pink window, stickers
        Rectangle {
            visible: root.skin === "windose"
            anchors.fill: parent
            color: Theme.windoseLavender
            Grid {
                anchors.fill: parent
                columns: 12
                Repeater {
                    model: 96
                    Rectangle {
                        required property int index
                        width: pic.width / 12
                        height: pic.height / 8
                        color: (index + Math.floor(index / 12)) % 2 ? Qt.alpha(Theme.windoseSticker, 0.2) : "transparent"
                    }
                }
            }
            Rectangle {
                x: parent.width * 0.06
                y: parent.height * 0.08
                width: parent.width * 0.88
                height: parent.height * 0.84
                color: Theme.windosePaper
                border.width: Math.max(1, Theme.u / 2)
                border.color: Theme.windoseLine
                Rectangle {
                    width: parent.width
                    height: parent.height * 0.18
                    color: Theme.windoseRose
                    border.width: 1
                    border.color: Theme.windoseLine
                }
                Grid {
                    x: parent.width * 0.08
                    y: parent.height * 0.3
                    columns: 4
                    spacing: parent.width * 0.06
                    Repeater {
                        model: 4
                        Rectangle {
                            width: pic.width * 0.13
                            height: width
                            radius: width * 0.2
                            color: Theme.windoseSticker
                            border.width: 1
                            border.color: Theme.windoseRose
                        }
                    }
                }
            }
        }
        // golden gate: a Mac desktop — the menu bar, a window with traffic lights, the Dock
        Rectangle {
            visible: root.skin === "goldengate"
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "#e9dcc6"
                }
                GradientStop {
                    position: 0.55
                    color: "#b7b0c8"
                }
                GradientStop {
                    position: 1
                    color: "#8f9cb2"
                }
            }
            Rectangle {
                width: parent.width
                height: Math.max(3, parent.height * 0.08)
                color: Qt.rgba(1, 1, 1, 0.35)
            }
            Rectangle {
                x: parent.width * 0.16
                y: parent.height * 0.2
                width: parent.width * 0.62
                height: parent.height * 0.5
                radius: Math.max(2, width * 0.05)
                color: "#f5f5f7"
                Row {
                    x: parent.width * 0.05
                    y: parent.height * 0.08
                    spacing: Math.max(1, parent.width * 0.025)
                    Repeater {
                        model: ["#ff5f57", "#d1d1d6", "#28c840"]
                        Rectangle {
                            required property string modelData
                            width: Math.max(2, pic.width * 0.035)
                            height: width
                            radius: width / 2
                            color: modelData
                        }
                    }
                }
                Rectangle {
                    y: parent.height * 0.22
                    width: parent.width * 0.3
                    height: parent.height * 0.78
                    color: "#e8e8ea"
                    bottomLeftRadius: parent.radius
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.8
                width: parent.width * 0.56
                height: parent.height * 0.13
                radius: height * 0.35
                color: Qt.rgba(1, 1, 1, 0.55)
                Row {
                    anchors.centerIn: parent
                    spacing: Math.max(1, pic.width * 0.02)
                    Repeater {
                        model: ["#2f8cff", "#ffffff", "#ff7a2f", "#8a8a90", "#4cd964"]
                        Rectangle {
                            required property string modelData
                            width: pic.height * 0.08
                            height: width
                            radius: width * 0.25
                            color: modelData
                        }
                    }
                }
            }
        }
        // stream: dark, LIVE, the chat on the right
        Rectangle {
            visible: root.skin === "stream"
            anchors.fill: parent
            color: Theme.streamBg
            Rectangle {
                x: parent.width * 0.05
                y: parent.height * 0.07
                width: parent.width * 0.22
                height: parent.height * 0.14
                radius: height / 2
                color: Theme.streamLive
            }
            Column {
                x: parent.width * 0.05
                y: parent.height * 0.3
                spacing: parent.height * 0.05
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: pic.width * 0.6
                        height: pic.height * 0.16
                        radius: 2
                        color: [Theme.ngoPink, Theme.ngoLilac, Theme.ngoMint][index]
                    }
                }
            }
            Rectangle {
                x: parent.width * 0.72
                width: parent.width * 0.28
                height: parent.height
                color: Theme.streamPanel
                Column {
                    x: 3
                    y: 4
                    spacing: 3
                    Repeater {
                        model: 6
                        Rectangle {
                            required property int index
                            width: pic.width * (0.12 + (index % 3) * 0.04)
                            height: 2
                            color: Theme.streamDim
                        }
                    }
                }
            }
        }
    }
    PxText {
        id: caption
        anchors.top: pic.bottom
        anchors.topMargin: Theme.u * 2
        anchors.horizontalCenter: parent.horizontalCenter
        text: (root.checked ? "♡ " : "") + (root.names[root.skin] || [root.skin])[0]
        font.bold: true
    }
    PxText {
        id: hint
        anchors.top: caption.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.u * 6
        horizontalAlignment: Text.AlignHCenter
        text: (root.names[root.skin] || ["", ""])[1]
        kind: "tiny"
        dim: true
        elide: Text.ElideRight
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Config.settingsUi.skin = root.skin;
            Config.settingsUi.skinChosen = true;
            root.picked();
        }
    }
}
