import QtQuick
import qs.services

// Qt 6.11 segfaults on a right press that lands on a window's very first pixel
// when nothing takes the press and the window has no focused item: the context
// menu event synthesized from it has pos (0,0), which Qt reads as "opened from
// the keyboard" and maps the null activeFocusItem
// (QQuickDeliveryAgentPrivate::contextMenuTargets → QQuickItem::mapToScene).
// A menu opened at the pointer puts its corner right under the next click.
// Every angelOS window carries one of these: it takes right presses on that pixel. It also
// signs its window in for `angelos perf` (services/Perf), which has no other way to find them.
MouseArea {
    readonly property var hostWindow: Window.window
    Component.onCompleted: Perf.addWindow(this)
    Component.onDestruction: Perf.dropWindow(this)
    z: -1
    width: 1
    height: 1
    acceptedButtons: Qt.RightButton
}
