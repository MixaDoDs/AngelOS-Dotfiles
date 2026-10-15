pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Two screens or more and nobody ever said which one is the main one: asked once, the first
// time this version runs (an update brings it). The login (SDDM) and the lock put the
// password field and the pointer there, the widgets and the angel live there. Somebody who
// picked one already (Settings → Monitor, the wizard, the installer) is not asked: the
// login screen just learns it (sddm-theme.py primary).
PanelWindow {
    id: win

    readonly property bool wanted: Config.setup.complete && !Config.system.primaryAsked && !Shell.dev && !Quickshell.env("ANGELOS_TEST")
    property bool due: false
    // never on a streamed screen
    screen: Shell.mainScreenFor("") || Shell.focusedScreen
    visible: due && Quickshell.screens.length > 1 && !Shell.setupLocked && !Shell.locked && !Updates.askRestart
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Theme.shadow, 0.35)
    WlrLayershell.namespace: "angelos-main-screen"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: one question, Esc or a click beside it = later (it asks again next time)
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // a minute after the start, not in the middle of it
    Timer {
        running: win.wanted && !win.due
        interval: 20000
        onTriggered: {
            const picked = Config.system.primaryScreen || "";
            if (picked !== "" && Quickshell.screens.some(s => s.name === picked)) {
                // picked before this question existed: the login only has to hear it
                Outputs.setPrimary(picked);
                Config.system.primaryAsked = true;
            } else if (Quickshell.screens.length > 1) {
                win.due = true;
            }
        }
    }

    function pick(name) {
        Outputs.setPrimary(name);
        Config.system.primaryAsked = true;
        due = false;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.due = false
    }
    Item {
        focus: win.visible
        Keys.onEscapePressed: win.due = false
    }

    PxWindow {
        id: dialog
        anchors.centerIn: parent
        width: Theme.u * 220
        height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 8
        title: I18n.t("Главный экран", "The main screen")
        icon: "star"
        onCloseClicked: win.due = false

        MouseArea {
            anchors.fill: parent
        }
        Column {
            id: col
            width: parent.width
            spacing: Theme.u * 5
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                kind: "title"
                text: I18n.t("Какой экран главный?", "Which screen is the main one?")
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: I18n.t("Там при входе в систему и на блокировке появятся поле пароля и курсор, там же живут виджеты и ангел. Потом: Настройки → Монитор → Главный экран.", "The password field and the pointer of the login and the lock show there, the widgets and the angel live there. Later: Settings → Monitor → Main screen.")
            }
            Flow {
                width: parent.width
                spacing: Theme.u * 3
                Repeater {
                    model: Quickshell.screens
                    PxButton {
                        required property var modelData
                        icon: "star"
                        accent: modelData.name === (Shell.widestScreen ? Shell.widestScreen.name : "")
                        text: modelData.name + "  " + modelData.width + "×" + modelData.height + (modelData.model ? "  " + modelData.model : "")
                        onClicked: win.pick(modelData.name)
                    }
                }
            }
            PxButton {
                anchors.right: parent.right
                text: I18n.t("Позже", "Later")
                onClicked: win.due = false
            }
        }
    }

    RightClickGuard {}
}
