import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Stress on the panel. Pixel: a flat PxButton, heart and percent. Mac look (Skin.mac, the
// Golden Gate menu bar): a line heart and the percent in the bar's ink, like a menu bar extra.
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    // the pixel bar's hooks (BarItem): padding and the hell bar's ink go to the button
    property int hpad: -1
    property bool barInk: false
    readonly property string icon: btn.icon
    readonly property string text: btn.text
    readonly property bool mac: Skin.mac
    readonly property string value: Math.round(Stats.stress * 100) + "%"

    implicitWidth: mac ? macRow.implicitWidth : btn.implicitWidth
    implicitHeight: mac ? Skin.px(18) : btn.implicitHeight

    PxButton {
        id: btn
        visible: !root.mac
        anchors.fill: parent
        compact: true
        flat: true
        hpad: root.hpad
        barInk: root.barInk
        icon: "heart"
        text: root.value
    }
    Row {
        id: macRow
        visible: root.mac
        anchors.centerIn: parent
        spacing: Skin.px(4)
        MacIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "heart"
            size: Skin.px(15)
            stroke: 2
            color: Skin.ink(root.screenName)
        }
        MacText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            color: Skin.ink(root.screenName)
        }
    }
}
