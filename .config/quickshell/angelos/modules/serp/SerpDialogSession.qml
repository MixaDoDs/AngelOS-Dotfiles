pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// serp-skin: the session menu (modules/session/SessionMenu: Mod+Shift+E…) in Serpantinum's look —
// the power row of its quick panel as tiles, no hold-to-confirm (logging out, restarting and
// shutting down ask SessionConfirm anyway). `host` is the menu's window: its actions, its pick
// (`current`, the keys change it) and its run(id) — nothing of its own.
SerpDialog {
    id: root

    property var host: null
    readonly property var actions: host ? host.actions : []
    // angelOS's pixel icons → the skin's line icons
    readonly property var lines: ({
            "lock": "lock",
            "idle": "sparkles",
            "suspend": "moon",
            "logout": "log-out",
            "reboot": "refresh-cw",
            "poweroff": "power"
        })

    icon: "power"
    title: I18n.t("Что сделать с компьютером?", "What would you like to do?")
    note: I18n.t("← → выбрать · Enter · буква — сразу · Esc — закрыть", "← → pick · Enter · a letter: at once · Esc: close")
    cardWidth: tiles.implicitWidth + pad * 2
    onDismissed: Shell.sessionOpen = false

    Row {
        id: tiles
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Serp.px(8)
        Repeater {
            model: root.actions
            Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool picked: root.host && root.host.current === index
                readonly property bool danger: modelData.id === "poweroff"
                readonly property color tint: danger ? Serp.red : Serp.accent
                width: Math.max(Serp.px(84), lbl.implicitWidth + Serp.px(18))
                height: Serp.px(96)
                Rectangle {
                    anchors.fill: parent
                    radius: Serp.radius
                    color: tile.picked ? Qt.alpha(tile.tint, 0.2) : ma.containsMouse ? Serp.surface1 : Qt.alpha(Serp.surface0, 0.8)
                    border.width: tile.picked ? Serp.px(2) : 1
                    border.color: tile.picked ? Qt.alpha(tile.tint, 0.75) : Serp.line
                    Behavior on color {
                        ColorAnimation {
                            duration: Serp.quick
                        }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: Serp.px(6)
                    scale: ma.pressed ? 0.94 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: Serp.quick
                            easing.type: Easing.OutCubic
                        }
                    }
                    SIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: root.lines[tile.modelData.id] || "circle-help"
                        size: Serp.px(24)
                        color: tile.danger || tile.picked ? tile.tint : Serp.text
                    }
                    SText {
                        id: lbl
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.label
                        size: Serp.px(12)
                        bold: tile.picked
                        elide: Text.ElideNone
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: keyText.implicitWidth + Serp.px(10)
                        height: Serp.px(16)
                        radius: height / 2
                        color: Qt.alpha(Serp.text, 0.07)
                        SText {
                            id: keyText
                            anchors.centerIn: parent
                            text: tile.modelData.key
                            size: Serp.px(10)
                            dim: true
                        }
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse && root.host)
                        root.host.current = tile.index
                    onClicked: if (root.host)
                        root.host.run(tile.modelData.id)
                }
            }
        }
    }
}
