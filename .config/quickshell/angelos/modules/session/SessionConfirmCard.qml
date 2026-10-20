import QtQuick
import qs.config
import qs.services
import qs.widgets

// "Restart the computer?": the one question before logging out, restarting or shutting down
// (Shell.sessionAction asks, Shell.sessionConfirmed does it). The window around it is
// SessionConfirm; the card alone is what the UI test drives (tests/session).
// Cancel is picked first; a key held from the menu before (its repeats), a click within
// `grace` of the card showing and a pointer that was resting where the yes appears do not say yes.
PxWindow {
    id: card

    readonly property string action: Shell.sessionConfirm
    property int grace: 450
    property int current: 0                  // 0 = cancel, 1 = the action
    property bool ready: false

    readonly property var texts: ({
            "logout": [I18n.t("Выйти из сеанса?", "Log out?"), I18n.t("Программы закроются, несохранённое пропадёт.", "Apps will close; unsaved work is lost."), I18n.t("Выйти", "Log out"), "logout"],
            "reboot": [I18n.t("Перезагрузить компьютер?", "Restart the computer?"), I18n.t("Программы закроются, несохранённое пропадёт.", "Apps will close; unsaved work is lost."), I18n.t("Перезагрузить", "Restart"), "refresh"],
            "poweroff": [I18n.t("Выключить компьютер?", "Shut down the computer?"), I18n.t("Программы закроются, несохранённое пропадёт.", "Apps will close; unsaved work is lost."), I18n.t("Выключить", "Shut down"), "power"]
        })
    readonly property var say: texts[action] || ["", "", "", "power"]

    width: Math.max(Theme.u * 170, buttons.implicitWidth + Theme.pad * 2 + Theme.u * 8)
    height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 10
    title: I18n.t("Подтверждение", "Confirm")
    icon: say[3]
    onCloseClicked: cancel()

    function opened() {
        current = 0;
        ready = false;
        graceTimer.restart();
        keys.forceActiveFocus();
    }
    function cancel() {
        Shell.sessionConfirm = "";
    }
    function confirm() {
        if (ready && action !== "")
            Shell.sessionConfirmed();
    }
    // e: {key, text, isAutoRepeat} (a real key event, or the test's)
    function key(e) {
        if (e.isAutoRepeat)
            return true;
        if (e.key === Qt.Key_Escape)
            cancel();
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab)
            current = 1 - current;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (current === 1)
                confirm();
            else
                cancel();
        } else
            return false;
        return true;
    }

    Timer {
        id: graceTimer
        interval: card.grace
        onTriggered: card.ready = true
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            card.key(e);
            e.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.u * 6

        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.say[0]
            kind: "title"
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.say[1]
            dim: true
        }
        Row {
            id: buttons
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.u * 5
            PxButton {
                text: I18n.t("Отмена", "Cancel")
                checked: card.current === 0
                onHoveredChanged: if (hovered)
                    card.current = 0
                onClicked: card.cancel()
            }
            PxButton {
                text: card.say[2]
                icon: card.say[3]
                danger: true
                checked: card.current === 1
                // only once it can be pressed: the pointer the card opened under picks nothing
                onHoveredChanged: if (hovered && card.ready)
                    card.current = 1
                onClicked: card.confirm()
            }
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.t("← → выбрать · Enter — выбранное · Esc — отмена", "← → pick · Enter: the picked one · Esc: cancel")
            kind: "tiny"
            dim: true
        }
    }
}
