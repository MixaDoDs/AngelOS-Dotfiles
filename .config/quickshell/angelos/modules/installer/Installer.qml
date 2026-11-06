pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings

// The live ISO's installer (Shell.installer; shell.qml loads it only there): every screen covered, the
// setup wizard's stage (SetupAssistant: its look, its step changes, Back / Continue, Enter) asking the
// install's own questions (InstallFlow). The screen comes on like a television, once. In the corner:
// restart and power off — never while the disk is being written.
Scope {
    id: root

    InstallFlow {
        id: flow
    }

    Variants {
        model: Shell.screens

        PanelWindow {
            id: cover

            required property var modelData
            readonly property bool hosting: modelData === flow.host
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.desk
            WlrLayershell.namespace: "angelos-installer"
            WlrLayershell.layer: WlrLayer.Overlay
            // takes input: the live is only the installer, nothing under it is to be used
            WlrLayershell.keyboardFocus: hosting ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            RightClickGuard {}
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Theme.desk
                    }
                    GradientStop {
                        position: 1
                        color: Theme.mix(Theme.desk, Theme.accent, Theme.dark ? 0.14 : 0.1)
                    }
                }
            }
            FloatingHearts {
                anchors.fill: parent
                count: 12
                maxOpacity: 0.22
                glide: true
                running: !Motion.still
            }
            Loader {
                anchors.fill: parent
                active: cover.hosting
                // the course is handed over once it is loaded: its first step then lands as a change (as SetupWizard does)
                onLoaded: {
                    item.wizard = flow;
                    flow.assistant = item;
                }
                sourceComponent: SetupAssistant {
                    screenName: cover.modelData.name
                    bodies: ({
                            "lang": langBody,
                            "hero": heroBody,
                            "disk": diskBody,
                            "confirm": confirmBody,
                            "progress": progressBody
                        })
                    arts: ({
                            "newgame": logoArt
                        })
                }
            }
            // restart / power off, top right (not while the disk is written)
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.u * 6
                spacing: Theme.u * 2
                visible: cover.hosting && !flow.installState.running
                PxButton {
                    icon: "refresh"
                    text: I18n.t("Перезагрузить", "Restart")
                    compact: true
                    onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                }
                PxButton {
                    icon: "power"
                    text: I18n.t("Выключить", "Power off")
                    compact: true
                    onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                }
            }
            // the television comes on: a line of light opens into the picture (once; not while motion is still)
            Item {
                id: tv
                anchors.fill: parent
                property real open: Motion.still ? 1 : 0
                visible: open < 1
                Rectangle {
                    width: parent.width
                    height: parent.height * (1 - tv.open) / 2
                    color: "#000000"
                }
                Rectangle {
                    y: parent.height - height
                    width: parent.width
                    height: parent.height * (1 - tv.open) / 2
                    color: "#000000"
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * Math.min(1, tv.open * 6 + 0.05)
                    height: Theme.u * 2
                    color: "#ffffff"
                    opacity: 1 - tv.open
                }
                NumberAnimation on open {
                    running: !Motion.still
                    from: 0
                    to: 1
                    duration: 900
                    easing.type: Easing.InQuad
                }
            }
        }
    }

    // ---- the answers ----
    Component {
        id: logoArt
        AngelLogo {
            pixel: Theme.u * 2
            fontSize: Theme.sizeHuge
        }
    }
    Component {
        id: langBody
        Column {
            spacing: Theme.u * 4
            PxSegmented {
                model: [
                    {
                        "label": "Русский",
                        "value": "ru"
                    },
                    {
                        "label": "English",
                        "value": "en"
                    }
                ]
                currentValue: I18n.english ? "en" : "ru"
                onActivated: v => Config.appearance.language = v
            }
            PxText {
                kind: "title"
                text: I18n.t("Часовой пояс: ", "Time zone: ") + flow.zoneOrDefault
            }
            PxField {
                id: filter
                width: parent.width
                icon: "search"
                placeholder: I18n.t("город или регион: Moscow, Europe/…", "a city or region: London, Europe/…")
            }
            PxBox {
                width: parent.width
                height: Theme.u * 90
                sunken: true
                clip: true
                ListView {
                    id: zoneList
                    anchors.fill: parent
                    anchors.margins: Theme.u * 2
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property string q: filter.text.trim().toLowerCase().replace(/ /g, "_")
                    model: q ? flow.zones.filter(z => z.toLowerCase().includes(q)) : flow.zones
                    delegate: PxButton {
                        required property string modelData
                        width: zoneList.width
                        flat: true
                        compact: true
                        checked: modelData === flow.zoneOrDefault
                        text: modelData.replace(/_/g, " ")
                        onClicked: flow.zone = modelData
                    }
                    Component.onCompleted: positionViewAtIndex(Math.max(0, flow.zones.indexOf(flow.zoneOrDefault)), ListView.Center)
                }
            }
        }
    }
    Component {
        id: heroBody
        Column {
            spacing: Theme.u * 4
            PxField {
                width: parent.width
                icon: "heart"
                placeholder: I18n.t("имя героя", "the hero's name")
                text: flow.heroName
                onEdited: flow.heroName = text
                Component.onCompleted: input.forceActiveFocus()
            }
            PxField {
                width: parent.width
                placeholder: I18n.t("логин: ", "login: ") + (flow.loginFor(flow.heroName) || "…")
                text: flow.loginTyped
                onEdited: flow.loginTyped = text.toLowerCase()
            }
            PxField {
                width: parent.width
                icon: "lock"
                password: true
                placeholder: I18n.t("пароль", "password")
                text: flow.password
                onEdited: flow.password = text
            }
            PxField {
                width: parent.width
                icon: "lock"
                password: true
                placeholder: I18n.t("пароль ещё раз", "the password again")
                text: flow.password2
                onEdited: flow.password2 = text
                onAccepted: flow.next()
            }
            PxText {
                visible: flow.heroTried && !!flow.heroProblem
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.danger
                text: "✕ " + flow.heroProblem
            }
        }
    }
    Component {
        id: diskBody
        Column {
            spacing: Theme.u * 3
            PxText {
                visible: flow.disks.length === 0
                dim: true
                text: I18n.t("Ищу диски…", "Looking for disks…")
            }
            Repeater {
                model: flow.disks
                PxBox {
                    id: card
                    required property var modelData
                    readonly property string blocked: flow.blocker(modelData)
                    readonly property bool picked: flow.disk === modelData.path && !blocked
                    width: parent.width
                    height: info.implicitHeight + Theme.u * 10
                    color: picked ? Theme.mix(Theme.face, Theme.accent, 0.25) : Theme.face
                    opacity: blocked ? 0.5 : 1
                    Column {
                        id: info
                        x: Theme.u * 4
                        y: Theme.u * 4
                        width: parent.width - Theme.u * 8
                        spacing: Theme.u
                        PxText {
                            kind: "title"
                            text: (card.modelData.model || card.modelData.name) + " · " + flow.sizeText(card.modelData.size)
                        }
                        PxText {
                            kind: "tiny"
                            dim: true
                            text: card.modelData.path + (card.modelData.tran ? " · " + card.modelData.tran : "") + (card.blocked ? " · " + I18n.t("сюда нельзя: ", "not here: ") + card.blocked : "")
                        }
                        Repeater {
                            model: flow.contents(card.modelData)
                            PxText {
                                required property string modelData
                                kind: "tiny"
                                text: "· " + modelData
                            }
                        }
                        PxText {
                            visible: flow.contents(card.modelData).length === 0
                            kind: "tiny"
                            text: I18n.t("· пустой — разделов нет", "· empty, no partitions")
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !card.blocked
                        cursorShape: Qt.PointingHandCursor
                        onClicked: flow.disk = card.modelData.path
                    }
                }
            }
        }
    }
    Component {
        id: confirmBody
        Column {
            spacing: Theme.u * 3
            PxText {
                kind: "title"
                text: flow.diskInfo ? (flow.diskInfo.model || flow.diskInfo.name) + " · " + flow.sizeText(flow.diskInfo.size) + " · " + flow.diskInfo.path : ""
            }
            PxText {
                dim: true
                text: I18n.t("На нём сейчас:", "On it now:")
            }
            Repeater {
                model: flow.diskInfo ? flow.contents(flow.diskInfo) : []
                PxText {
                    required property string modelData
                    color: Theme.danger
                    text: "✕ " + modelData
                }
            }
            PxText {
                visible: !!flow.diskInfo && flow.contents(flow.diskInfo).length === 0
                text: I18n.t("ничего — он пустой", "nothing: it is empty")
            }
            Item {
                width: 1
                height: Theme.u * 2
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: I18n.t("Герой: ", "Hero: ") + flow.heroName + " (" + flow.login + ") · " + flow.zoneOrDefault + " · " + (I18n.english ? "English" : "Русский")
            }
        }
    }
    Component {
        id: progressBody
        Column {
            spacing: Theme.u * 4
            PxProgress {
                width: parent.width
                value: flow.progress
                text: Math.round(flow.progress * 100) + "%"
            }
            PxText {
                dim: true
                text: flow.phaseText
            }
            PxText {
                visible: !!flow.error
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                color: Theme.danger
                text: flow.error
            }
        }
    }
}
