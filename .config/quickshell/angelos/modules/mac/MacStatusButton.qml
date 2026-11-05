import QtQuick
import qs.services

// A status item of the Golden Gate menu bar (MacMenuBar's StatusButton, MacDesks' overview
// button): its content in the middle, a capsule of the bar's ink under it while what it opens
// is open
Item {
    id: sb

    property color ink: GoldenGate.label
    property real rowH: GoldenGate.barHeight
    property bool active: false
    default property alias content: box.data
    signal clicked(var mouse)

    width: Math.max(GoldenGate.px(26), box.childrenRect.width + GoldenGate.px(12))
    height: rowH
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: GoldenGate.px(2)
        anchors.bottomMargin: GoldenGate.px(2)
        radius: height / 2
        color: Qt.alpha(sb.ink, sb.ink.r > 0.5 ? 0.22 : 0.1)
        visible: sb.active
    }
    Item {
        id: box
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => sb.clicked(m)
    }
}
