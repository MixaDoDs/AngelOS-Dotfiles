pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// serp-skin: the wallpaper under the skin's lock and idle faces — what the desktop shows on this
// screen's active desk (a scene's day or night still), frosted and dimmed into the skin's crust,
// a soft shade at the top and the bottom so the clock and the chips read on any picture.
Item {
    id: root

    property string screenName: ""
    property date now: new Date()          // a scene's night still at night
    property real blur: 1                  // 0..1
    property real dim: 0.42                // the crust over it, 0..1
    readonly property bool ready: pic.status === Image.Ready

    readonly property var ws: screenName ? Niri.activeWorkspace(screenName) : null
    readonly property string path: screenName ? Wallpapers.resolve(screenName, ws ? ws.idx : 1) : ""
    readonly property string url: {
        const d = path ? Wallpapers.still(path, now) : "";
        return d ? (d.startsWith("/") ? "file://" + d : d) : "";
    }
    // a layered scene's still: its neutral frame cut to the view the desktop shows (margin 8)
    readonly property var sceneRect: {
        const m = path && Wallpapers.sceneOf(path) ? Wallpapers.meta[path] : null;
        return m && m.w ? Qt.rect(8, 8, m.w - 16, m.h - 16) : null;
    }

    Rectangle {
        anchors.fill: parent
        color: Serp.crust
    }
    Image {
        id: pic
        anchors.fill: parent
        visible: false
        source: root.url
        fillMode: Image.PreserveAspectCrop
        // frosted anyway: half the screen is plenty
        sourceSize: root.sceneRect ? undefined : Qt.size(Math.max(1, Math.ceil(root.width / 2)), Math.max(1, Math.ceil(root.height / 2)))
        sourceClipRect: root.sceneRect || Qt.rect(0, 0, 0, 0)
        asynchronous: true
        cache: true
        smooth: true
        onStatusChanged: if (status === Image.Error && root.path)
            Wallpapers.fit(root.path)
    }
    MultiEffect {
        anchors.fill: parent
        source: pic
        visible: root.ready
        autoPaddingEnabled: false
        blurEnabled: root.blur > 0
        blur: root.blur
        blurMax: 64
        saturation: 0.1
        opacity: root.ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.ms(Serp.slow)
                easing.type: Easing.OutCubic
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Serp.crust, root.dim)
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Serp.crust, 0.35)
            }
            GradientStop {
                position: 0.3
                color: "transparent"
            }
            GradientStop {
                position: 0.75
                color: "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Serp.crust, 0.45)
            }
        }
    }
}
