pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Start → Sleep (Shell.suspend): every screen goes out like an old CRT in ~0.3 s — the picture
// squeezes into a bright line, the line into a dot, the dot goes — and stays black until the
// machine sleeps. Hard pixel edges only, every size on the art-pixel grid. Calm or no motion:
// black at once, no flash. Shell takes it away on waking (or a few seconds after, if the
// suspend never happened); a click takes it away as well.
// takes input: the black screen is the machine going to sleep — a click there wakes the picture
Scope {
    Variants {
        model: Shell.sleepFx ? Shell.screens : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-sleep"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property int px: Math.max(2, Theme.u)
            function snap(v) {
                return Math.max(0, Math.round(v / px) * px);
            }
            property real t: 0
            NumberAnimation on t {
                from: 0
                to: 1
                duration: Motion.calm ? 0 : 300
                running: true
            }
            // 0 … 0.5 the picture squeezes, 0.5 … 0.8 the line shrinks, 0.8 … 1 the dot goes
            readonly property real squeeze: Math.min(1, t / 0.5)
            readonly property real shrink: Math.max(0, Math.min(1, (t - 0.5) / 0.3))
            readonly property real fade: Math.max(0, Math.min(1, (t - 0.8) / 0.2))
            readonly property int lineH: px * 2
            readonly property int band: Math.max(lineH, snap(height * (1 - squeeze)))
            readonly property int lineW: Math.max(lineH, snap(width * (1 - shrink)))
            readonly property int dot: snap(lineH * (1 - fade))

            // the squeezing picture: black closes in from the top and the bottom, what is left
            // brightens in four flat steps
            Rectangle {
                visible: win.t < 0.5
                width: parent.width
                height: Math.floor((parent.height - win.band) / 2)
                color: "#000000"
            }
            Rectangle {
                visible: win.t < 0.5
                y: Math.floor((parent.height - win.band) / 2)
                width: parent.width
                height: win.band
                color: Qt.rgba(1, 1, 1, Math.round(win.squeeze * 4) / 4 * 0.85)
            }
            Rectangle {
                visible: win.t < 0.5
                y: Math.floor((parent.height - win.band) / 2) + win.band
                width: parent.width
                height: parent.height - y
                color: "#000000"
            }
            // then black, the line and the dot
            Rectangle {
                visible: win.t >= 0.5
                anchors.fill: parent
                color: "#000000"
                Rectangle {
                    // a one-pixel cyan rim, hard-edged, around the white core
                    readonly property int w: win.fade > 0 ? win.dot : win.lineW
                    readonly property int h: win.fade > 0 ? win.dot : win.lineH
                    visible: w > 0
                    x: Math.floor((parent.width - w) / 2) - win.px
                    y: Math.floor((parent.height - h) / 2) - win.px
                    width: w + win.px * 2
                    height: h + win.px * 2
                    color: "#7fe8ff"
                    Rectangle {
                        x: win.px
                        y: win.px
                        width: parent.w
                        height: parent.h
                        color: "#ffffff"
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                // no arrow over the black
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
                onClicked: Shell.sleepFx = false
            }

            RightClickGuard {}
        }
    }
}
