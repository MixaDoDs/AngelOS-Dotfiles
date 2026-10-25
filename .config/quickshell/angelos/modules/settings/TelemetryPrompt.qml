pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Set up before the wizard had its telemetry step: asked once, a while after the start
// (services/Telemetry). Yes / No is the answer; Esc, a click beside it or «Позже» ask again at
// the next start. Never on a streamed screen.
PanelWindow {
    id: win

    // nowhere to send it yet (data/sponsor.json has no endpoint): not asked
    readonly property bool wanted: Config.ready && Config.setup.complete && Telemetry.consent === "" && Telemetry.hasEndpoint && !Shell.dev && !Quickshell.env("ANGELOS_TEST")
    property bool due: false
    screen: Shell.mainScreenFor("") || Shell.focusedScreen
    visible: due && wanted && !Shell.setupLocked && !Shell.locked && !Updates.askRestart
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // takes input: a question over the screen, a click beside the card is «later»
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Theme.shadow, 0.35)
    WlrLayershell.namespace: "angelos-telemetry"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // after the main-screen question (20 s), not on top of it
    Timer {
        running: win.wanted && !win.due
        interval: 45000
        onTriggered: win.due = true
    }

    function answer(v) {
        Telemetry.setConsent(v);
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
        anchors.centerIn: parent
        width: Theme.u * 220
        height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 8
        title: I18n.t("Телеметрия", "Telemetry")
        icon: "chip"
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
                text: I18n.t("Помочь автору телеметрией?", "Help the author with telemetry?")
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: I18n.t("Раз в неделю автору angelOS уходят версии и железо: процессор, видеокарта, память, экраны, версии Quickshell и системы. Имён, файлов и IP — нет. Скажешь «нет» — ничего не собирается. Передумать и посмотреть, что именно уходит: Настройки → angelOS → Телеметрия.", "Once a week angelOS's author gets the versions and the hardware: CPU, graphics, memory, screens, the Quickshell and system versions. No names, files or IP. Say no and nothing is collected. To change your mind or see exactly what goes: Settings → angelOS → Telemetry.")
            }
            Row {
                anchors.right: parent.right
                spacing: Theme.u * 3
                PxButton {
                    text: I18n.t("Позже", "Later")
                    flat: true
                    onClicked: win.due = false
                }
                PxButton {
                    text: I18n.t("Нет", "No")
                    onClicked: win.answer("no")
                }
                PxButton {
                    text: I18n.t("Да, помогу ♡", "Yes, I'll help ♡")
                    icon: "heart"
                    accent: true
                    onClicked: win.answer("yes")
                }
            }
        }
    }

    RightClickGuard {}
}
