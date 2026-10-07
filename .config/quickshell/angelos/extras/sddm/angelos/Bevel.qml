import QtQuick

// A Y2K box: raised (a button, a window) or sunken (a field), in the theme's colours —
// a light edge top-left, a dark one bottom-right, an outline round it.
Rectangle {
    id: root

    required property var pal
    property int u: 2
    property bool sunken: false
    property bool outline: true
    property color face: sunken ? pal.sunken : pal.face
    default property alias content: inner.data

    color: outline ? pal.edge : "transparent"
    Rectangle {
        id: light
        anchors.fill: parent
        anchors.margins: root.outline ? root.u : 0
        color: root.sunken ? root.pal.lo : root.pal.hi
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: root.u
            anchors.topMargin: root.u
            color: root.sunken ? root.pal.hi : root.pal.lo
            Rectangle {
                anchors.fill: parent
                anchors.rightMargin: root.u
                anchors.bottomMargin: root.u
                color: root.face
            }
        }
    }
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: (root.outline ? root.u : 0) + root.u * 2
    }
}
