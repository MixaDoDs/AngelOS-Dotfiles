import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The window round SessionConfirmCard: up while Shell.sessionConfirm names an action.
// A click beside the card cancels, like the session menu's.
// takes input: the question is modal — a click beside the card is its «Отмена»
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: Shell.sessionConfirm !== ""
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
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    // built when it opens (LazyWindows), so the first showing is the creation itself
    Component.onCompleted: if (visible)
        card.opened()
    onVisibleChanged: if (visible)
        card.opened()
    // another action asked while it is up: the question starts over (Cancel first, the pause again)
    Connections {
        target: Shell
        function onSessionConfirmChanged() {
            if (Shell.sessionConfirm !== "" && win.visible)
                card.opened();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.cancel()
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: card
    }

    SessionConfirmCard {
        id: card
        anchors.centerIn: parent
    }

    RightClickGuard {}
}
