pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Asked once, over the Settings window the first time it opens: the familiar look (Windows 11)
// or the new one (P5) — services/SettingsLook. The answer opens Settings again in the look picked;
// Esc, a click beside the card or «Позже» ask again at the next opening. Never on a streamed
// screen; not under Golden Gate or hell's dresses (a look of their own).
PanelWindow {
    id: win

    readonly property bool wanted: Config.ready && Config.setup.complete && !Config.settingsUi.lookAsked && !Quickshell.env("ANGELOS_TEST") && Quickshell.env("ANGELOS_SETTINGS_OLD") !== "1" && Config.settingsUi.skin !== "goldengate" && !(Angel.demon && HellLook.settingsPick !== "")
    property bool later: false
    screen: Shell.focusedScreen
    visible: wanted && Shell.settingsOpen && !later && !StreamMode.active && !Shell.setupLocked && !Shell.locked
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // takes input: a question over Settings, a click beside the card is «later»
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Theme.shadow, 0.35)
    WlrLayershell.namespace: "angelos-settings-look"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: Shell
        function onSettingsOpenChanged() {
            if (!Shell.settingsOpen)
                win.later = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: win.later = true
    }
    Item {
        focus: win.visible
        Keys.onEscapePressed: win.later = true
    }

    PxWindow {
        anchors.centerIn: parent
        width: Theme.u * 220
        height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 8
        title: I18n.t("Настройки", "Settings")
        icon: "gear"
        onCloseClicked: win.later = true

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
                text: I18n.t("Какой вид настроек оставить?", "Which Settings look to keep?")
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: I18n.t("Привычный — окно как в Windows 11: разделы слева, настройки справа. Новый — Persona 5 на весь экран, его ещё доделываем. Сменить потом: Настройки → Внешний вид → Вид окна настроек.", "Familiar: a window like Windows 11, sections on the left, settings on the right. New: Persona 5 over the whole screen, still being finished. To change it later: Settings → Appearance → Settings window look.")
            }
            Row {
                anchors.right: parent.right
                spacing: Theme.u * 3
                PxButton {
                    text: I18n.t("Позже", "Later")
                    flat: true
                    onClicked: win.later = true
                }
                PxButton {
                    text: I18n.t("Новый (P5)", "New (P5)")
                    icon: "sparkle"
                    onClicked: SettingsLook.choose("p5")
                }
                PxButton {
                    text: I18n.t("Привычный", "Familiar")
                    icon: "window"
                    accent: true
                    onClicked: SettingsLook.choose("win11")
                }
            }
        }
    }

    RightClickGuard {}
}
