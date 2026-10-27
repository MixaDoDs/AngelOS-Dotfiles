import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Tasks.qml's double blink round a window picked on the bar, over everything on its screen.
// A file of its own: a PanelWindow inline would leave Tasks (and the bar) uncreatable where
// there is no layer shell (the UI self-test)
PanelWindow {
    property var host
    screen: Shell.screenByName(host ? host.screenName : "")
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-window-flash"
    RightClickGuard {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // a step outside the window, clear of niri's focus ring, which lights up at the same moment
    Rectangle {
        readonly property real gap: Theme.u * 5
        x: host ? host.flashRect.x - gap : 0
        y: host ? host.flashRect.y - gap : 0
        width: host ? host.flashRect.width + gap * 2 : 0
        height: host ? host.flashRect.height + gap * 2 : 0
        color: "transparent"
        border.width: Theme.u * 3
        border.color: Qt.alpha(Theme.accent, 0.25)
        visible: !!host && host.flashOn
    }
}
