pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Shake to find the pointer (services/CursorShake): for a moment a see-through overlay draws
// the theme's arrow bigger at the pointer (crisp pixels), then it shrinks back and goes.
// One arrow only: the compositor draws the real arrow above every surface, and only the surface
// under the pointer can hide it — so while the big arrow is up the overlay holds the pointer and
// shows a blank cursor. Holding it is also how the overlay knows the exact spot (niri tells
// nobody where the pointer is): every motion lands here, the big arrow's tip sits on it, and when
// it has shrunk back to the real size the overlay goes and the real arrow is there, same place.
// Clicks still reach the apps (B3): a press ends the effect, and on release the overlay goes and
// the same click is handed on to what is under the pointer (CursorShake.pass → vpointer.py).
// A drag that started here is let go — it would land somewhere it wasn't meant to.
Variants {
    model: Shell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property var img: CursorShake.image
        // the real arrow's size on screen: the theme's picture drawn at the cursor size
        readonly property real base: img ? Cursors.size / Math.max(1, img.nominal) : Cursors.size / 16
        property real grow: CursorShake.shaking ? CursorShake.zoom : 1
        Behavior on grow {
            NumberAnimation {
                duration: Motion.ms(CursorShake.shaking ? 170 : catcher.pressed ? 90 : 240)
                easing.type: CursorShake.shaking ? Easing.OutBack : Easing.InOutQuad
            }
        }
        // a click was caught: the overlay is gone at once (even mid-shrink), so the click
        // handed on lands on the app, not here
        property bool passing: false
        Connections {
            target: CursorShake
            function onShakingChanged() {
                if (CursorShake.shaking)
                    win.passing = false;
            }
        }

        screen: modelData
        // (angel-niri draws the big arrow itself: CursorShake.ownZoom)
        visible: !CursorShake.ownZoom && !passing && (CursorShake.shaking || grow > 1.02 || catcher.pressed)
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "angelos-cursor"
        WlrLayershell.layer: WlrLayer.Overlay
        // takes input: only while the big arrow is up — the real arrow hides under a blank
        // cursor and every motion gives the exact spot; clicks and wheel steps are handed on
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // the pointer's spot on this screen during this shake (it may be on another screen)
        property bool known: false
        property real px: 0
        property real py: 0
        onVisibleChanged: if (!visible)
            known = false

        MouseArea {
            id: catcher
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            cursorShape: Qt.BlankCursor
            property real downX: 0
            property real downY: 0
            property int button: 0
            function seen(x, y) {
                win.px = x;
                win.py = y;
                win.known = true;
            }
            // Qt's buttons → the Linux codes the virtual pointer sends
            function code(b) {
                return b === Qt.RightButton ? 273 : b === Qt.MiddleButton ? 274 : b === Qt.BackButton ? 275 : b === Qt.ForwardButton ? 276 : 272;
            }
            onPositionChanged: m => seen(m.x, m.y)
            onEntered: seen(mouseX, mouseY)
            onExited: win.known = false
            onPressed: m => {
                seen(m.x, m.y);
                downX = m.x;
                downY = m.y;
                button = m.button;
                CursorShake.dismiss();
            }
            onReleased: m => {
                const click = Math.abs(m.x - downX) <= 6 && Math.abs(m.y - downY) <= 6;
                win.passing = true;
                if (click)
                    handOn.later("click " + code(button));
            }
            onWheel: w => {
                CursorShake.dismiss();
                win.passing = true;
                handOn.later("wheel " + (-w.angleDelta.y / 120) + " " + (-w.angleDelta.x / 120));
            }
        }
        // a frame after the overlay went, so the compositor already sees what is under it
        Timer {
            id: handOn
            property string what: ""
            function later(w) {
                what = w;
                restart();
            }
            interval: 30
            onTriggered: {
                const p = what.split(" ");
                if (p[0] === "click")
                    CursorShake.pass(p[1]);
                else
                    CursorShake.wheel(p[1], p[2]);
            }
        }

        // the theme's arrow, hotspot on the pointer
        Image {
            visible: !!win.img && win.known
            source: win.img ? "file://" + win.img.png : ""
            smooth: false
            mipmap: false
            cache: false
            width: (win.img ? win.img.width : 0) * win.base * win.grow
            height: (win.img ? win.img.height : 0) * win.base * win.grow
            x: win.px - (win.img ? win.img.xhot : 0) * win.base * win.grow
            y: win.py - (win.img ? win.img.yhot : 0) * win.base * win.grow
        }
        // no picture of the theme: the pixel arrow from the icon set
        PxIcon {
            visible: !win.img && win.known
            name: "cursor"
            pixel: Math.max(1, Math.round(win.base * win.grow))
            ink: Theme.edge
            fill: "#ffffff"
            x: win.px
            y: win.py
        }

        RightClickGuard {}
    }
}
