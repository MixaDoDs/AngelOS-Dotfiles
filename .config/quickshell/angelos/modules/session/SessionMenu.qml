pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// "Shut down angelOS?" dialog.
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: Shell.sessionOpen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Theme.shadow, 0.35)
    WlrLayershell.namespace: "angelos-session"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: the power menu: a click beside it closes it
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    property int current: 0
    // a letter for logging out, restarting or shutting down only picks it: a second press (or
    // Enter) does it. One stray key used to switch the computer off (16.10)
    property string armed: ""
    readonly property var askFirst: ["logout", "reboot", "poweroff"]
    readonly property var actions: [
        {
            "id": "lock",
            "label": I18n.t("Заблокировать", "Lock"),
            "icon": "lock",
            "key": "L"
        },
        {
            "id": "idle",
            "label": I18n.t("Заставка", "Idle"),
            "icon": "sparkle",
            "key": "I"
        },
        {
            "id": "suspend",
            "label": I18n.t("Сон", "Sleep"),
            "icon": "moon",
            "key": "S"
        },
        {
            "id": "logout",
            "label": I18n.t("Выйти", "Log out"),
            "icon": "logout",
            "key": "E"
        },
        {
            "id": "reboot",
            "label": I18n.t("Перезагрузка", "Restart"),
            "icon": "refresh",
            "key": "R"
        },
        {
            "id": "poweroff",
            "label": I18n.t("Выключение", "Shut down"),
            "icon": "power",
            "key": "P"
        }
    ]

    // the actions themselves (and the goodbye chime) live in Shell.sessionAction
    function run(id) {
        Shell.sessionOpen = false;
        Shell.sessionAction(id);
    }

    // built when it opens (shell.qml: LazyLoader), so the first showing is the creation itself
    Component.onCompleted: if (visible)
        opened()
    onVisibleChanged: if (visible)
        opened()
    function opened() {
        current = 0;
        armed = "";
        keys.forceActiveFocus();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.sessionOpen = false
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: dialog
    }

    PxWindow {
        id: dialog
        anchors.centerIn: parent
        width: row.implicitWidth + Theme.pad * 2 + Theme.u * 8
        height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 10
        title: I18n.t("Завершение работы angelOS", "angelOS session")
        icon: "power"
        onCloseClicked: Shell.sessionOpen = false

        Item {
            id: keys
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape)
                    Shell.sessionOpen = false;
                else if (e.key === Qt.Key_Left)
                    win.current = (win.current + win.actions.length - 1) % win.actions.length;
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)
                    win.current = (win.current + 1) % win.actions.length;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                    win.run(win.actions[win.current].id);
                else {
                    const a = win.actions.find(a => a.key === e.text.toUpperCase());
                    if (a && win.askFirst.includes(a.id) && win.armed !== a.id) {
                        win.current = win.actions.indexOf(a);
                        win.armed = a.id;
                    } else if (a)
                        win.run(a.id);
                }
                e.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: col
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 8

            PxText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("Что сделать с компьютером? ♡", "What would you like to do? ♡")
                kind: "title"
            }
            PxText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: win.armed !== ""
                readonly property var act: win.actions.find(a => a.id === win.armed) || {}
                text: I18n.t("Ещё раз [", "Press [") + (act.key || "") + I18n.t("] или Enter — ", "] again or Enter: ") + String(act.label || "").toLowerCase() + I18n.t(", Esc — отмена", ", Esc to cancel")
                kind: "tiny"
                color: Theme.danger
            }

            Row {
                id: row
                spacing: Theme.u * 5
                Repeater {
                    model: win.actions
                    PxButton {
                        id: b
                        required property var modelData
                        required property int index
                        // as wide as its word: «Перезагрузка» in full, not «Рестарт» cut to fit
                        width: Math.max(Theme.u * 40, lbl.implicitWidth + Theme.u * 8)
                        height: Theme.u * 40
                        checked: win.current === index
                        danger: modelData.id === "poweroff"
                        onClicked: win.run(modelData.id)
                        onHoveredChanged: if (hovered) {
                            win.current = index;
                            win.armed = "";
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.u * 3
                            PxIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: b.modelData.icon
                                pixel: Theme.u * 2
                            }
                            PxText {
                                id: lbl
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: b.modelData.label
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "[" + b.modelData.key + "]"
                                kind: "tiny"
                                dim: true
                            }
                        }
                    }
                }
            }
        }
    }

    RightClickGuard {}
}
