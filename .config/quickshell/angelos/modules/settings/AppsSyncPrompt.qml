pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The author's new apps after an update (services/AppsSync), in a window of the shell instead of
// a terminal: what is new with a tick each, then the install right here — hearts for how far it
// is, each one with its state, the output's last lines; «Ещё раз» for what didn't make it. The
// admin password is asked once (pkexec → the shell's polkit dialog). The desktop is not held:
// closed while it runs, the install goes on and says how it ended.
// Opens from the «Как у автора» notification's «Поставить», Settings → Updates, `angelos apps`.
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: AppsSync.open && !Shell.setupLocked
    // a floating card: room around it for the shadow, the rest of the screen stays the desktop's
    readonly property int rim: Theme.u * 6
    implicitWidth: dialog.width + rim * 2
    implicitHeight: dialog.height + rim * 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-apps"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: if (visible)
        dialog.takeKeys()

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: dialog
    }

    AppsSyncCard {
        id: dialog
        anchors.centerIn: parent
    }

    RightClickGuard {}
}
