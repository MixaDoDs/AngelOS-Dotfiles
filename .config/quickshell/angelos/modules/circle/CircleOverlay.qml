pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// The screenshot, Pixel-like (services/CircleSearch): a layer window over the frozen screen with
// the overlay's face (CircleCanvas: the areas, the words, the pick, the modes, the bar, the
// keys). Transparent itself, so closing fades back to the live screen. Esc / right click: back,
// then away; Enter: save; Ctrl+C: copy (a text pick's text, else the picture); Ctrl+S: save;
// Ctrl+A: all the text; Tab: the next mode; Ctrl+Enter: search.
Scope {
    id: root
    LazyLoader {
        active: (CircleSearch.open || CircleSearch.fading) && !!Shell.screenByName(CircleSearch.screenName)

        PanelWindow {
            id: win
            screen: Shell.screenByName(CircleSearch.screenName)
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-circle"
            // takes input until Esc; the dev stand on the test screen leaves the keyboard alone
            WlrLayershell.keyboardFocus: !CircleSearch.open || Quickshell.env("ANGELOS_STAND_NOKEYS") === "1" ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
            // fading away: the clicks already go through
            mask: Region {
                item: CircleSearch.open ? face : null
            }

            CircleCanvas {
                id: face
                anchors.fill: parent
                focus: true
            }
            RightClickGuard {}
        }
    }
}
