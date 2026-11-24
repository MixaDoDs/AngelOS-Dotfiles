import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import qs.modules.serp  // serp-skin

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
    color: Serp.on ? Qt.alpha(Serp.crust, 0.25) : Qt.alpha(Theme.shadow, 0.35)  // serp-skin
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

    BackgroundEffect.blurRegion: (Serp.on ? Serp.blurOn : Config.appearance.blur) ? blurRegion : null  // serp-skin
    Region {
        id: blurRegion
        item: Serp.on ? serpDlg.card : card  // serp-skin
        radius: Serp.on ? Serp.radius + Serp.px(4) : 0  // serp-skin
    }

    SessionConfirmCard {
        id: card
        opacity: Serp.on ? 0 : 1  // serp-skin: hidden, its keys still listen (SerpDialog* draws)
        anchors.centerIn: parent
    }

    SerpDialogConfirm { id: serpDlg; host: card }  // serp-skin

    RightClickGuard {}
}
