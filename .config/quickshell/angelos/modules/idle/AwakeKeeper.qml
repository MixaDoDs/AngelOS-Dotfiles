import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Holds the idle inhibitor while services/Awake is on. niri honours an inhibitor only while
// its surface is drawn on some output, so it sits on a 1×1 clear overlay surface (above
// full-screen windows too), on a screen the stream does not see when there is one.
LazyLoader {
    active: Awake.active && Shell.screens.length > 0

    PanelWindow {
        id: holder

        screen: Shell.screens.find(s => !StreamMode.onStream(s.name)) || Shell.screens[0]
        anchors.top: true
        anchors.left: true
        implicitWidth: 1
        implicitHeight: 1
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "angelos-awake"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        IdleInhibitor {
            window: holder
            enabled: true
        }

        RightClickGuard {}
    }
}
