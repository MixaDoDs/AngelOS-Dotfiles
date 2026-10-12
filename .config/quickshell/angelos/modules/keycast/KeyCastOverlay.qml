pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The keys pressed (services/KeyCast), as pixel keycaps at the bottom of the screen in use:
// the newest on the right, each fades out on its own. Takes no input.
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    visible: KeyCast.items.length > 0
    anchors.bottom: true
    margins.bottom: Theme.u * 30
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: Math.max(1, row.width + Theme.u * 4)
    implicitHeight: row.height + Theme.u * 4
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "angelos-keycast"
    WlrLayershell.layer: WlrLayer.Overlay

    Row {
        id: row
        x: Theme.u * 2
        y: Theme.u * 2
        spacing: Theme.u * 4
        Repeater {
            model: KeyCast.items
            Item {
                id: cap
                required property var modelData
                width: face.width + Theme.u * 2
                height: face.height + Theme.u * 3
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.still ? 0 : 140
                    }
                }
                // the key's side: a hard pixel step under it
                Rectangle {
                    x: Theme.u
                    y: Theme.u * 3
                    width: face.width
                    height: face.height
                    color: Theme.mix(Theme.edge, "#000000", 0.35)
                }
                Rectangle {
                    id: face
                    width: label.implicitWidth + Theme.u * 14
                    height: label.implicitHeight + Theme.u * 8
                    color: cap.modelData.kind === "note" ? Theme.accent : Theme.face
                    border.width: Theme.u
                    border.color: Theme.edge
                    PxText {
                        id: label
                        anchors.centerIn: parent
                        kind: cap.modelData.kind === "note" ? "body" : "title"
                        text: cap.modelData.text
                        color: cap.modelData.kind === "note" ? Theme.selectText : Theme.text
                    }
                }
            }
        }
    }

    RightClickGuard {}
}
