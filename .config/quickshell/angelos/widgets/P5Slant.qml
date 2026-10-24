import QtQuick
import qs.config

// The P5 settings window's plate for the pixel widgets (settingsSkin "p5"): a slanted box with
// hard, unsmoothed edges, on a black shadow when `raised`.
Item {
    id: root

    property color color: Theme.p5Paper2
    property bool raised: false
    property real slant: 0.22
    property color rim: "transparent"

    Rectangle {
        visible: root.raised
        x: Theme.u * 2
        y: Theme.u * 2
        width: root.width
        height: root.height
        color: Theme.p5Black
        antialiasing: false
        transform: Shear {
            origin.y: root.height / 2
            xFactor: -root.slant
        }
    }
    Rectangle {
        width: root.width
        height: root.height
        color: root.color
        border.width: root.rim.a > 0 ? Theme.u : 0
        border.color: root.rim
        antialiasing: false
        transform: Shear {
            origin.y: root.height / 2
            xFactor: -root.slant
        }
    }
}
