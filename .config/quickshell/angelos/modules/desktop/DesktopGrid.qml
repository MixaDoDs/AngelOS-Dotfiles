import QtQuick
import qs.config
import qs.services

// The widgets' grid on the wallpaper, in edit mode while snapping is on (Background: under the
// widgets' faces). A dot at every cell, a line every fourth; the cell is DesktopWidgets.gridPx
// (the edit bar on top picks it). `ghost: true`: instead the place a dragged widget will take
// when it is let go, over the widgets.
Item {
    id: root

    property string screenName
    property bool ghost: false
    readonly property bool on: DesktopWidgets.editMode && DesktopWidgets.snapOn

    // ---- the place it will land ----
    readonly property var d: DesktopWidgets.drag
    readonly property bool dragging: ghost && on && d.uid !== "" && d.screen === screenName && d.w > 0
    // where it really lands: on the grid and clear of the widgets before it (DesktopWidgets.settledPlace)
    readonly property point landing: dragging ? DesktopWidgets.settledPlace(d.uid, screenName, d.x, d.y, d.w, d.h, width, height) : Qt.point(0, 0)
    Rectangle {
        visible: root.dragging
        x: root.landing.x
        y: root.landing.y
        width: root.d.w || 0
        height: root.d.h || 0
        color: Qt.alpha(Theme.hell ? Theme.hellAccent : Theme.accent, 0.12)
        border.width: Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(Theme.hell ? Theme.hellAccent : Theme.accent, 0.8)
    }

    // ---- the grid ----
    Loader {
        anchors.fill: parent
        active: !root.ghost && root.on
        sourceComponent: Canvas {
            id: grid
            readonly property int g: DesktopWidgets.gridPx
            readonly property int dot: Math.max(1, Math.round(Theme.u / 2))
            readonly property color minor: Qt.alpha(Theme.hell ? Theme.hellText : Theme.text, Theme.dark || Theme.hell ? 0.12 : 0.16)
            readonly property color dotInk: Qt.alpha(Theme.hell ? Theme.hellText : Theme.text, Theme.dark || Theme.hell ? 0.25 : 0.3)
            readonly property color major: Qt.alpha(Theme.hell ? Theme.hellBlood : Theme.accent, 0.35)
            renderStrategy: Canvas.Cooperative
            onGChanged: requestPaint()
            onMinorChanged: requestPaint()
            onMajorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (g < 2)
                    return;
                // a line at every cell (a widget lands on any of them), every fourth brighter; a
                // cell too small for lines gets dots
                const lines = g >= Theme.u * 6;
                ctx.fillStyle = String(minor);
                if (lines) {
                    for (let x = 0; x <= width; x += g)
                        if (x % (g * 4))
                            ctx.fillRect(x, 0, dot, height);
                    for (let y = 0; y <= height; y += g)
                        if (y % (g * 4))
                            ctx.fillRect(0, y, width, dot);
                } else {
                    ctx.fillStyle = String(dotInk);
                    for (let x = 0; x <= width; x += g)
                        for (let y = 0; y <= height; y += g)
                            if (x % (g * 4) && y % (g * 4))
                                ctx.fillRect(x, y, dot, dot);
                }
                ctx.fillStyle = String(major);
                for (let x = 0; x <= width; x += g * 4)
                    ctx.fillRect(x, 0, dot, height);
                for (let y = 0; y <= height; y += g * 4)
                    ctx.fillRect(0, y, width, dot);
            }
        }
    }
}
