import QtQuick
import qs.config
import qs.services

// The phone's battery (PhoneScreen's status line, the outside screen): a pixel cell with four
// bars of PhoneLine.battery; a bolt while it charges (the bars run up), the last bar blinking
// when it is nearly out.
Item {
    id: root

    property color color: "#ffffff"
    readonly property int k: Theme.u
    readonly property int bars: Math.max(0, Math.min(4, Math.ceil(PhoneLine.battery * 4 - 0.01)))
    property int tick: 0
    Timer {
        interval: 450
        running: root.visible && (PhoneLine.plugged || PhoneLine.battery < 0.15)
        repeat: true
        onTriggered: root.tick++
    }
    // charging: the bars fill up one after another, again and again
    readonly property int shown: PhoneLine.plugged && PhoneLine.battery < 1 ? Math.min(4, bars - 1 + tick % (5 - Math.max(0, bars - 1))) : bars
    width: k * 12
    height: k * 6
    Rectangle {
        width: root.k * 11
        height: root.k * 6
        color: "transparent"
        border.width: Math.max(1, root.k / 2)
        border.color: root.color
        Row {
            x: root.k
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.max(1, root.k / 2)
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: root.k * 2
                    height: root.k * 4
                    color: root.color
                    visible: index < root.shown && !(root.bars === 1 && !PhoneLine.plugged && root.tick % 2)
                }
            }
        }
    }
    Rectangle {
        x: root.k * 11
        anchors.verticalCenter: parent.verticalCenter
        width: root.k
        height: root.k * 2
        color: root.color
    }
}
