pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// After Settings → Updates installed a new version: this shell still runs the
// previous one from memory, so ask to restart it now or leave it for later.
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: Updates.askRestart && !Shell.setupLocked
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha(Theme.shadow, 0.35)
    WlrLayershell.namespace: "angelos-update"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: asks to restart: a click beside it means later
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    property int current: 1                 // 0 later, 1 restart

    function answer(restart) {
        if (restart)
            Updates.restartShell();
        else
            Updates.restartLater();
    }

    onVisibleChanged: if (visible) {
        current = 1;
        keys.forceActiveFocus();
    }

    // a click beside the dialog: later
    MouseArea {
        anchors.fill: parent
        onClicked: win.answer(false)
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: dialog
    }

    PxWindow {
        id: dialog
        anchors.centerIn: parent
        width: Theme.u * 200
        height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 8
        title: Updates.restored ? I18n.t("angelOS: прежняя версия ♡", "angelOS: the previous version ♡") : I18n.t("angelOS обновлён ♡", "angelOS is updated ♡")
        icon: "download"
        onCloseClicked: win.answer(false)

        Item {
            id: keys
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape)
                    win.answer(false);
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)
                    win.current = 1 - win.current;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                    win.answer(win.current === 1);
                e.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: col
            width: parent.width
            spacing: Theme.u * 5

            Row {
                width: parent.width
                spacing: Theme.u * 5
                PxIcon {
                    name: "sparkle"
                    pixel: Theme.u * 2
                }
                PxText {
                    width: parent.width - Theme.u * 30
                    wrapMode: Text.Wrap
                    kind: "title"
                    text: Updates.restored ? I18n.t("Возвращено как было до обновления", "Restored to how it was before the update") : I18n.t("Новая версия установлена", "The new version is installed") + (Updates.landed > 0 ? I18n.t(" (изменений: ", " (changes: ") + Updates.landed + ")" : "")
                }
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: Updates.restored ? I18n.t("Оболочка запущена с файлами того обновления. Перезагрузить её? Окна и программы останутся открытыми.", "The shell was started with that update's files. Restart it? Windows and apps stay open.") : I18n.t("Сейчас работает ещё прошлая — она в памяти. Перезагрузить оболочку? Окна и программы останутся открытыми, панель пропадёт на пару секунд.", "The previous one is still running from memory. Restart the shell now? Windows and apps stay open; the bar disappears for a couple of seconds.")
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: I18n.t("«Позже» — новая версия загрузится при следующем входе; перезапустить можно и в Настройки → Обновления.", "“Later”: the new version loads at the next login; Settings → Updates can restart it too.")
            }
            Row {
                anchors.right: parent.right
                spacing: Theme.u * 4
                PxButton {
                    text: I18n.t("Позже", "Later")
                    checked: win.current === 0
                    onHoveredChanged: if (hovered)
                        win.current = 0
                    onClicked: win.answer(false)
                }
                PxButton {
                    icon: "refresh"
                    accent: true
                    checked: win.current === 1
                    text: I18n.t("Перезагрузить оболочку", "Restart the shell")
                    onHoveredChanged: if (hovered)
                        win.current = 1
                    onClicked: win.answer(true)
                }
            }
        }
    }

    RightClickGuard {}
}
