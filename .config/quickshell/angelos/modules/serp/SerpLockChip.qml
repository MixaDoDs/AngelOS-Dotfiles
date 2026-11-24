import QtQuick
import qs.services

// serp-skin: a small rounded chip of the lock and idle faces (an icon and a word)
Rectangle {
    id: chip
    property string icon: ""
    property string text: ""
    property color ink: Serp.text
    property color fill: Qt.alpha(Serp.base, 0.55)

    implicitWidth: row.implicitWidth + Serp.px(22)
    implicitHeight: Serp.px(30)
    radius: height / 2
    color: fill
    border.width: 1
    border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Serp.px(7)
        SIcon {
            visible: chip.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: chip.icon
            size: Serp.px(14)
            color: chip.ink
        }
        SText {
            visible: chip.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            size: Serp.px(12)
            bold: true
            color: chip.ink
            elide: Text.ElideNone
        }
    }
}
