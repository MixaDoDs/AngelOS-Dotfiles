import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Serpantinum's segmented Switch — the accent plate stretches to the new
// segment: its leading edge goes first (200 ms), the trailing one follows (350 ms)
Item {
    id: sw
    property var options: []
    property int currentIndex: 0
    signal picked(int index)
    readonly property int count: Math.max(1, options.length)
    readonly property real seg: width / count
    implicitWidth: count * Serp.px(92)
    implicitHeight: Serp.px(32)

    Rectangle {
        anchors.fill: parent
        radius: Serp.px(8)
        color: Serp.surface1
    }
    Rectangle {
        id: plate
        // the edges in segments (0..count), so a resize moves them without animating
        property real l: sw.currentIndex
        property real r: sw.currentIndex + 1
        property int prev: sw.currentIndex
        Connections {
            target: sw
            function onCurrentIndexChanged() {
                const right = sw.currentIndex > plate.prev;
                ra.duration = right ? 200 : 350;
                la.duration = right ? 350 : 200;
                plate.prev = sw.currentIndex;
                plate.l = sw.currentIndex;
                plate.r = sw.currentIndex + 1;
            }
        }
        Behavior on l {
            NumberAnimation {
                id: la
                duration: 200
                easing.type: Easing.OutExpo
            }
        }
        Behavior on r {
            NumberAnimation {
                id: ra
                duration: 200
                easing.type: Easing.OutExpo
            }
        }
        x: l * sw.seg
        width: Math.max(0, (r - l) * sw.seg)
        height: parent.height
        radius: Serp.px(8)
        color: Serp.accent
    }
    Row {
        anchors.fill: parent
        Repeater {
            model: sw.options
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: sw.seg
                height: sw.height
                SText {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - Serp.px(12))
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.modelData
                    size: Serp.px(11)
                    bold: cell.index === sw.currentIndex
                    color: cell.index === sw.currentIndex ? Serp.onAccent : Serp.text
                    Behavior on color {
                        ColorAnimation {
                            duration: Serp.normal
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (cell.index !== sw.currentIndex)
                        sw.picked(cell.index)
                }
            }
        }
    }
}
