pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// A plate of the heaven lock (a game's login screen, drawn in pixels): cream inside, a
// gold rim with a darker edge, corners cut in steps — a few steps more for a `pill`.
// `dark` (the shell's dark theme): night-blue glass inside, the same gold rim.
Item {
    id: root

    property bool pill: false
    property bool shadow: true
    property int corner: pill ? 3 : 2          // steps cut off each corner
    property int s: Theme.u
    property bool dark: false
    property color fill: dark ? Qt.rgba(0.09, 0.11, 0.24, 0.93) : Qt.rgba(1, 0.985, 0.95, 0.95)
    property color rim: dark ? "#d9a94a" : "#e8b84a"
    property color edge: dark ? "#5a3c12" : "#9a6a24"
    property color hi: dark ? "#3a4684" : "#ffffff"

    component Stair: Item {
        id: st
        property int k: 2
        property int step: Theme.u
        property color color: "white"
        Repeater {
            model: st.k + 1
            Rectangle {
                required property int index
                x: (st.k - index) * st.step
                y: index * st.step
                width: Math.max(0, st.width - 2 * x)
                height: Math.max(0, st.height - 2 * y)
                color: st.color
            }
        }
    }

    Stair {
        visible: root.shadow
        x: 0
        y: root.s * 2
        width: root.width
        height: root.height
        k: root.corner
        step: root.s
        color: root.dark ? Qt.rgba(0, 0, 0, 0.4) : Qt.rgba(0.1, 0.15, 0.35, 0.22)
    }
    Stair {
        anchors.fill: parent
        k: root.corner
        step: root.s
        color: root.edge
    }
    Stair {
        anchors.fill: parent
        anchors.margins: root.s
        k: Math.max(1, root.corner - 1)
        step: root.s
        color: root.rim
    }
    Stair {
        anchors.fill: parent
        anchors.margins: root.s * 2
        k: Math.max(1, root.corner - 1)
        step: root.s
        color: root.fill
    }
    // the light on the upper edge
    Rectangle {
        x: root.s * (root.corner + 2)
        y: root.s * 2
        width: Math.max(0, root.width - 2 * x)
        height: root.s
        color: root.hi
        opacity: 0.9
    }
}
