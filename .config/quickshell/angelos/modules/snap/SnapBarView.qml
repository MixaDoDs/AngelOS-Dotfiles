pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.background
import qs.services
import qs.widgets

// The snap bar (services/SnapAssist), as in Windows 11: a window dragged near the top of a screen
// brings the screen's layouts down there; the part under the pointer lights up, and let go on
// it, the window snaps there (the rest of the layout is offered after, Snap Assist). The pointer
// is the compositor's while it drags (angel-niri tells where it is): nothing here takes input.
Scope {
    LazyLoader {
        active: SnapAssist.bar !== null
        PanelWindow {
            id: win

            readonly property var bar: SnapAssist.bar
            screen: Shell.screenByName(bar ? bar.output : "") || Shell.focusedScreen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: box.y + box.height + Theme.u * 4
            mask: Region {}
            WlrLayershell.namespace: "angelos-snap-bar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // where the pointer is over the layouts
            readonly property point at: bar ? Qt.point(bar.pos[0] - box.x - box.inset, bar.pos[1] - box.y - box.inset) : Qt.point(-1, -1)

            PxBox {
                id: box
                x: Math.round((win.width - width) / 2)
                y: Theme.u * 6
                width: layouts.implicitWidth + inset * 2
                height: layouts.implicitHeight + inset * 2
                color: Qt.alpha(Theme.panel, 0.95)
                shadow: Config.appearance.shadows
                SnapLayouts {
                    id: layouts
                    width: implicitWidth
                    screen: win.screen
                    perRow: layouts.layouts.length
                    t: MenuLook.tokens(MenuLook.lookFor("task"))
                    at: win.at
                }
            }

            Connections {
                target: SnapAssist
                function onBarDropped(id, output, pos) {
                    if (!win.screen || output !== win.screen.name)
                        return;
                    const p = layouts.partAt(pos[0] - box.x - box.inset, pos[1] - box.y - box.inset);
                    if (p)
                        SnapAssist.snap(id, p[1], layouts.layouts[p[0]], output);
                }
            }

            RightClickGuard {}
        }
    }
}
