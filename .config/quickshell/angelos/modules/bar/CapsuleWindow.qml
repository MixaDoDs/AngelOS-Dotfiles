pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Capsules (Settings → Bar → Style → Capsules): three floating pills at the top — the
// left, the centre and the right of the bar, each as wide as it needs (BarContent "capsules"
// lays the sections out, this draws a capsule behind each and takes input only there).
// In hell (BarLayout.hell): three plain plates of the circle's colour with its rim around
// them — the content on calm ground, nothing hanging, nothing swaying.
PanelWindow {
    id: win

    required property var modelData
    readonly property bool compact: Config.bar.compactOnVertical && modelData.width < 1300
    readonly property bool hell: BarLayout.hell
    readonly property int capHeight: Theme.fit(15)
    readonly property int drop: Theme.u * 3                             // from the screen's edge to a capsule
    readonly property int pad: Theme.u * 5                              // a capsule around its section
    readonly property bool fxLive: !Shell.fullscreenOn(modelData.name)

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: drop + capHeight + Theme.u * 3
    exclusionMode: Shell.dev ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "angelos-bar"
    WlrLayershell.layer: WlrLayer.Top
    // the edge it keeps from windows, for the screenshot selector (services/Zones)
    ZoneReport {
        win: win
        key: "capsule"
    }

    // input (and blur) only on the capsules
    mask: Region {
        item: win.cap0
        Region {
            item: win.cap1
        }
        Region {
            item: win.cap2
        }
    }
    BackgroundEffect.blurRegion: Config.appearance.blur && !win.hell ? blurRegion : null
    Region {
        id: blurRegion
        item: win.cap0
        Region {
            item: win.cap1
        }
        Region {
            item: win.cap2
        }
    }

    // the three capsules: where BarContent put the sections, a pad around them
    property Item cap0: null
    property Item cap1: null
    property Item cap2: null
    Repeater {
        model: 3
        onItemAdded: (i, it) => {
            if (i === 0)
                win.cap0 = it;
            else if (i === 1)
                win.cap1 = it;
            else
                win.cap2 = it;
        }
        Item {
            id: cap
            required property int index
            readonly property var sec: index === 0 ? content.leftBox : index === 1 ? content.centerBox : content.rightBox
            readonly property bool used: sec && sec.visible && sec.implicitWidth > 0
            visible: used
            x: content.x + (sec ? sec.x : 0) - win.pad
            y: win.drop
            width: used ? sec.width + win.pad * 2 : 0
            height: win.capHeight

            // heaven: a pill with a hard pixel shadow (no antialiasing: stepped pixel ends)
            Rectangle {
                visible: !win.hell && Config.appearance.shadows
                x: Theme.u * 2
                y: Theme.u * 2
                width: parent.width
                height: parent.height
                radius: height / 2
                antialiasing: false
                color: Qt.alpha("#000000", 0.35)
            }
            Rectangle {
                visible: !win.hell
                anchors.fill: parent
                radius: height / 2
                antialiasing: false
                color: Theme.panel
                border.width: Theme.u
                border.color: Theme.edge
                Rectangle {
                    x: parent.radius * 0.6
                    y: Theme.u * 2
                    width: parent.width - parent.radius * 1.2
                    height: Theme.u
                    color: Qt.alpha(Theme.hi, 0.8)
                }
            }

            // hell: a plate with the circle's rim
            HellBarFrame {
                visible: win.hell
                anchors.fill: parent
                texture: false
                rim: "all"
            }
        }
    }

    BarContent {
        id: content
        anchors.fill: parent
        anchors.leftMargin: Theme.u * 6
        anchors.rightMargin: Theme.u * 6
        anchors.topMargin: win.drop
        anchors.bottomMargin: win.height - win.drop - win.capHeight
        screenName: win.modelData.name
        barWindow: win
        style: "capsules"
        compact: win.compact
        itemHeight: Theme.fit(12)
    }

    RightClickGuard {}
}
