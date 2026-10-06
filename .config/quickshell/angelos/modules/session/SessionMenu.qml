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
    readonly property var actions: [
        {
            "id": "lock",
            "label": I18n.t("Блок", "Block"),
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
            "label": I18n.t("Рестарт", "Restart"),
            "icon": "refresh",
            "key": "R"
        },
        {
            "id": "poweroff",
            "label": I18n.t("Выкл", "Off"),
            "icon": "power",
            "key": "P"
        }
    ]

    function run(id) {
        Shell.sessionOpen = false;
        if (id === "logout" || id === "reboot" || id === "poweroff") {
            // let the Y2K goodbye chime play before the session goes away
            if (Sounds.enabled("shutdown")) {
                Sounds.play("shutdown");
                bye.action = id;
                bye.restart();
                return;
            }
        }
        act(id);
    }
    Timer {
        id: bye
        property string action
        interval: 1300
        onTriggered: win.act(action)
    }
    function act(id) {
        switch (id) {
        case "lock":
            Shell.lock();
            break;
        case "idle":
            Idle.start();
            break;
        case "suspend":
            Shell.exec(["systemctl", "suspend"]);
            break;
        case "logout":
            Niri.quit();
            break;
        case "reboot":
            Shell.exec(["systemctl", "reboot"]);
            break;
        case "poweroff":
            Shell.exec(["systemctl", "poweroff"]);
            break;
        }
    }

    // built when it opens (shell.qml: LazyLoader), so the first showing is the creation itself
    Component.onCompleted: if (visible)
        opened()
    onVisibleChanged: if (visible)
        opened()
    function opened() {
        current = 0;
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
                    if (a)
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

            Row {
                id: row
                spacing: Theme.u * 5
                Repeater {
                    model: win.actions
                    PxButton {
                        id: b
                        required property var modelData
                        required property int index
                        width: Theme.u * 40
                        height: Theme.u * 40
                        checked: win.current === index
                        danger: modelData.id === "poweroff"
                        onClicked: win.run(modelData.id)
                        onHoveredChanged: if (hovered)
                            win.current = index
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.u * 3
                            PxIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: b.modelData.icon
                                pixel: Theme.u * 2
                            }
                            PxText {
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
