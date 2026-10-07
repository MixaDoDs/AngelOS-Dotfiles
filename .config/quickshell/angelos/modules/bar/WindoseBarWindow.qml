pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Windose (Settings → Bar → Style → Windose): the NEEDY GIRL OVERDOSE taskbar along the
// bottom — pastel paper with a little check, a rose and lavender stripe on top, every
// button a pill (the controls inside take the "windose" skin, like Settings' Windose
// skin), a few hearts. In hell (BarLayout.hell) the circle's ground, plates under the
// widgets, a rim on top (HellBarFrame) — the stripes, the hearts and the check stay in heaven.
PanelWindow {
    id: win

    required property var modelData
    readonly property bool compact: Config.bar.compactOnVertical && modelData.width < 1300
    readonly property bool hell: BarLayout.hell
    readonly property bool fxLive: !Shell.fullscreenOn(modelData.name)

    screen: modelData
    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    exclusionMode: Shell.dev ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"
    WlrLayershell.namespace: "angelos-bar"
    WlrLayershell.layer: WlrLayer.Top
    // the edge it keeps from windows, for the screenshot selector (services/Zones)
    ZoneReport {
        win: win
        key: "windose"
    }

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: paper
    }

    HoverHandler {
        onPointChanged: if (hovered)
            Pointer.report("bar", win.modelData.name, point.position.x, win.modelData.height - win.height + point.position.y)
        onHoveredChanged: if (!hovered)
            Pointer.left("bar", win.modelData.name)
    }

    Item {
        id: paper
        anchors.fill: parent
        // the controls inside are Windose's pills (PxButton, PxBox: Theme.settingsSkinFor)
        readonly property string settingsSkin: "windose"

        Rectangle {
            visible: !win.hell
            anchors.fill: parent
            color: Qt.alpha(Theme.windosePaper, Math.max(0.9, Theme.panelAlpha))
        }
        // the check: 4 art pixels a square, faint
        Image {
            visible: !win.hell
            anchors.fill: parent
            fillMode: Image.Tile
            smooth: false
            opacity: Theme.dark ? 0.16 : 0.22
            readonly property int sq: Theme.u * 4
            sourceSize: Qt.size(sq * 2, sq * 2)
            source: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="' + sq * 2 + '" height="' + sq * 2 + '" shape-rendering="crispEdges"><rect width="' + sq + '" height="' + sq + '" fill="' + Theme.hex(Theme.windoseLavender) + '"/><rect x="' + sq + '" y="' + sq + '" width="' + sq + '" height="' + sq + '" fill="' + Theme.hex(Theme.windoseLavender) + '"/></svg>')
        }
        HellBarFrame {
            visible: win.hell
            anchors.fill: parent
            content: windoseContent
            rim: "top"
        }
        // the stripes along the top: rose over lavender
        Rectangle {
            visible: !win.hell
            width: parent.width
            height: Theme.u
            color: Theme.windoseRose
        }
        Rectangle {
            visible: !win.hell
            y: Theme.u
            width: parent.width
            height: Theme.u
            color: Theme.windoseLavender
        }
        // hearts here and there along the paper, under the buttons
        Repeater {
            model: win.hell ? [] : [0.31, 0.52, 0.71]
            PxIcon {
                required property var modelData
                x: Math.round(win.width * modelData / Theme.u) * Theme.u
                y: win.height - height - Theme.u * 2
                name: "heartSmall"
                pixel: Theme.u
                fill: Theme.windoseRose
                ink: Theme.windoseLine
                opacity: 0.55
            }
        }
        BarContent {
            id: windoseContent
            anchors.fill: parent
            anchors.topMargin: Theme.u * 2
            anchors.leftMargin: Theme.u * 2
            anchors.rightMargin: Theme.u * 2
            screenName: win.modelData.name
            barWindow: win
            style: "windose"
            compact: win.compact
            itemHeight: Theme.fit(14)
        }
    }

    RightClickGuard {}
}
