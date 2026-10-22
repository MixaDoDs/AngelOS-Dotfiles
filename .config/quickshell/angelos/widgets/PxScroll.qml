import QtQuick
import qs.config

// Flickable with a chunky pixel scrollbar.
Item {
    id: root

    property alias flick: flick
    property alias contentHeight: flick.contentHeight
    property alias contentY: flick.contentY
    default property alias content: flick.flickableData
    // false: as tall as its content, the wheel and drags go to the scroll it sits in (a part
    // of a settings page put together from groups, ComposedPage)
    property bool scrolls: true
    // a resize: the content follows the width at most every `widthLag` ms (0: each step) and
    // exactly when it ends: the edge moves every frame, the content is laid out a few times a
    // second (a Settings page: laying it all out again each pixel is what made a resize stutter)
    property int widthLag: 0
    property real laidWidth: 0

    // The bar takes width from the content. A page that gets no taller when it is
    // narrower (a grid that changes its columns, text that rewraps) can fit once the
    // bar is shown and overflow once it is hidden: show, hide, show… in one layout
    // pass, a polish loop that froze the whole shell (Settings → Capture, stream
    // skin, on GitHub's check). So the bar is decided after the pass, and a bar that
    // has flipped back and forth stays shown until the content settles.
    readonly property bool overflows: flick.contentHeight > flick.height + 1
    property bool barVisible: false
    property color trackColor: Theme.sunken  // a menu's look recolours its bar (PxMenuList)
    property color handleColor: Theme.faceAlt
    property int barFlips: 0
    onOverflowsChanged: Qt.callLater(decideBar)
    Component.onCompleted: {
        laidWidth = flick.width;
        Qt.callLater(decideBar);
    }
    function decideBar() {
        if (!scrolls) {
            barVisible = false;
            return;
        }
        if (overflows === barVisible)
            return;
        if (!overflows && barFlips >= 2)
            return;
        barVisible = overflows;
        barFlips++;
        flipsReset.restart();
    }
    Timer {
        id: widthLater
        interval: root.widthLag
        onTriggered: root.laidWidth = flick.width
    }
    Timer {
        id: flipsReset
        interval: 600
        onTriggered: root.barFlips = 0
    }

    // Mouse wheel: fixed steps with a short glide. Flickable's own wheel
    // handling is velocity based and crawls on long settings pages.
    function scrollBy(dy) {
        const max = Math.max(0, flick.contentHeight - flick.height);
        const from = glide.running ? glide.to : flick.contentY;
        const to = Math.max(0, Math.min(max, from + dy));
        glide.stop();
        if (to === flick.contentY)
            return;
        glide.from = flick.contentY;
        glide.to = to;
        glide.start();
    }
    NumberAnimation {
        id: glide
        target: flick
        property: "contentY"
        duration: Motion.ms(110)
        easing.type: Easing.OutCubic
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.rightMargin: root.barVisible ? bar.width + Theme.u * 3 : 0
        clip: true
        contentWidth: root.widthLag > 0 ? root.laidWidth : width
        // the content a moment wider than the view doesn't make it scroll sideways
        flickableDirection: root.widthLag > 0 ? Flickable.VerticalFlick : Flickable.AutoFlickDirection
        onWidthChanged: {
            if (root.widthLag <= 0 || root.laidWidth <= 0)
                root.laidWidth = width;
            else if (!widthLater.running)
                widthLater.start();
        }
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.scrolls
        flickDeceleration: 4000
        maximumFlickVelocity: 3000
        pixelAligned: true

        WheelHandler {
            target: null
            enabled: root.scrolls
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                if (flick.contentHeight <= flick.height)
                    return;
                const dy = e.pixelDelta.y !== 0 ? -e.pixelDelta.y : -e.angleDelta.y / 120 * Theme.u * 40;
                root.scrollBy(dy);
            }
        }
    }

    PxBox {
        id: bar
        visible: root.barVisible
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.u * 8
        sunken: true
        color: root.trackColor

        PxBox {
            id: handle
            x: 0
            width: parent.width - bar.inset * 2
            height: Math.max(Theme.u * 12, (parent.height - bar.inset * 2) * flick.visibleArea.heightRatio)
            y: (parent.height - bar.inset * 2 - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
            color: handleMouse.pressed ? Theme.accent : root.handleColor

            MouseArea {
                id: handleMouse
                anchors.fill: parent
                property real startY
                property real startContent
                onPressed: m => {
                    startY = mapToItem(bar, 0, m.y).y;
                    startContent = flick.contentY;
                }
                onPositionChanged: m => {
                    if (!pressed)
                        return;
                    const dy = mapToItem(bar, 0, m.y).y - startY;
                    const range = bar.height - handle.height;
                    const maxY = flick.contentHeight - flick.height;
                    flick.contentY = Math.max(0, Math.min(maxY, startContent + dy / Math.max(1, range) * maxY));
                }
            }
        }
    }
}
