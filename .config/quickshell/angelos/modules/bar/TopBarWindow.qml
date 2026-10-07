import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Thin strip at the top. In hell (BarLayout.hell): the circle's ground with calm plates
// under the widgets and a thin rim along the bottom (HellBarFrame), nothing below it.
PanelWindow {
    id: win

    required property var modelData
    readonly property bool compact: Config.bar.compactOnVertical && modelData.width < 1300

    readonly property bool hell: BarLayout.hell
    readonly property int barHeight: Theme.fit(16)
    readonly property int headroom: 0
    readonly property bool fxLive: !Shell.fullscreenOn(modelData.name)

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: barHeight + headroom
    exclusionMode: Shell.dev ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: barHeight
    mask: Region {
        item: strip
    }
    color: "transparent"
    WlrLayershell.namespace: "angelos-bar"
    WlrLayershell.layer: WlrLayer.Top
    // the edge it keeps from windows, for the screenshot selector (services/Zones)
    ZoneReport {
        win: win
        key: "topbar"
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: strip
    }

    Rectangle {
        id: strip
        width: parent.width
        height: win.barHeight
        color: win.hell ? "transparent" : Theme.panel
        HellBarFrame {
            visible: win.hell
            anchors.fill: parent
            content: topContent
            rim: "bottom"
        }
        Rectangle {
            visible: !win.hell
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.u
            color: Theme.dark ? Theme.edge : Theme.lo
        }
        Rectangle {
            visible: !win.hell
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.u
            width: parent.width
            height: Theme.u
            color: Theme.menuHeader
        }

        BarContent {
            id: topContent
            anchors.fill: parent
            anchors.bottomMargin: Theme.u * 2
            screenName: win.modelData.name
            barWindow: win
            style: "top"
            compact: win.compact
            itemHeight: Theme.fit(12)
        }
    }

    RightClickGuard {}
}
