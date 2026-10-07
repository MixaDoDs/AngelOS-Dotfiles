import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The dock (Settings → Bar → Style → Dock): a floating shelf at the bottom centre with the
// whole bar in one row; the window icons stand on the shelf, grow under the pointer and hop
// when their window opens (Tasks: dock). Like the island the surface keeps the screen's
// width and the shelf grows inside it; above it there is headroom for the grown icons, input
// and blur cover only the shelf. The same in hell (no hell version of its own).
PanelWindow {
    id: win

    required property var modelData
    readonly property bool compact: Config.bar.compactOnVertical && modelData.width < 1300
    readonly property int dockHeight: Theme.fit(22)
    readonly property int gap: Theme.u * 4               // between the shelf and the screen's edge
    readonly property int headroom: Theme.u * 12          // the grown icons rise into it

    screen: modelData
    anchors.bottom: true
    implicitWidth: modelData.width - Theme.u * 8
    implicitHeight: headroom + dockHeight + gap
    mask: Region {
        item: box
    }
    exclusiveZone: dockHeight + gap
    exclusionMode: Shell.dev ? ExclusionMode.Ignore : ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.namespace: "angelos-bar"
    WlrLayershell.layer: WlrLayer.Top
    // the edge it keeps from windows, for the screenshot selector (services/Zones)
    ZoneReport {
        win: win
        key: "dock"
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: box
    }

    // the pointer over the dock, in screen coordinates (like the taskbar's)
    HoverHandler {
        id: hover
        onPointChanged: if (hovered)
            Pointer.report("bar", win.modelData.name, (win.modelData.width - win.width) / 2 + point.position.x, win.modelData.height - win.height + point.position.y)
        onHoveredChanged: if (!hovered)
            Pointer.left("bar", win.modelData.name)
    }

    PxBox {
        id: box
        readonly property real want: Math.min(win.width - Theme.u * 2, row.implicitWidth + Theme.u * 12)
        width: want
        x: Math.round((win.width - Theme.u * 2 - width) / 2)
        y: win.headroom
        height: win.dockHeight
        color: Theme.panel
        shadow: Config.appearance.shadows
        Behavior on width {
            NumberAnimation {
                duration: Motion.ms(Theme.normal)
                easing.type: Easing.OutCubic
            }
        }

        // the shelf the icons stand on
        Rectangle {
            x: -box.inset
            width: box.width
            height: Theme.u * 4
            y: box.height - box.inset - height
            color: Theme.faceAlt
            Rectangle {
                width: parent.width
                height: Theme.u
                color: Theme.hi
            }
        }
        // no clip: the grown icons rise out of the shelf
        BarContent {
            id: row
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Theme.u
            screenName: win.modelData.name
            barWindow: win
            style: "dock"
            compact: win.compact
            inline: true
            itemHeight: Theme.fit(18)
        }
    }

    RightClickGuard {}
}
