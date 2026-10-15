import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// The mini island's measure of the screen's free part (services/Island): an empty,
// see-through layer the bars push aside; its size is what is left of the screen.
// Only while the island is open.
Scope {
    LazyLoader {
        active: Island.probing
        PanelWindow {
            id: probe
            screen: Shell.screenByName(Island.output)
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "angelos-island-probe"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            onWidthChanged: Island.free = Qt.size(width, height)
            onHeightChanged: Island.free = Qt.size(width, height)
            Component.onCompleted: Island.free = Qt.size(width, height)
            RightClickGuard {}
        }
    }
}
