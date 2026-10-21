import QtQuick

// A MouseArea for a right-click menu that opens at the pointer. The menu opens where the
// button went DOWN, not where Qt says it came up: with a menu already open (an xdg-popup
// grab), Qt on Wayland reports the release relative to that popup — a second right-click
// on the wallpaper put the new menu off by the old menu's position (B2). Left and middle
// clicks are passed on as they are; the middle button also says when it goes down and up
// (the wallpaper's ring: hold, flick, let go).
MouseArea {
    id: root

    signal menu(real x, real y)
    signal otherClicked(var mouse)
    signal middlePressed(real x, real y)
    signal middleReleased(real x, real y)

    property real downX: 0
    property real downY: 0
    acceptedButtons: Qt.RightButton
    onPressed: m => {
        downX = m.x;
        downY = m.y;
        m.accepted = true;
        if (m.button === Qt.MiddleButton)
            root.middlePressed(m.x, m.y);
    }
    onReleased: m => {
        if (m.button === Qt.MiddleButton)
            root.middleReleased(m.x, m.y);
    }
    onClicked: m => {
        if (m.button === Qt.RightButton)
            root.menu(root.downX, root.downY);
        else
            root.otherClicked(m);
    }
}
