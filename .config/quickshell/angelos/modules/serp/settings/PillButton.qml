import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: a text button — the accent one leads, the soft one stands by
Rectangle {
    id: pb
    property string rowKey: ""            // for the settings search
    property string icon: ""
    property string label: ""
    property bool primary: false
    signal clicked
    implicitWidth: row.implicitWidth + Serp.px(28)
    implicitHeight: Serp.px(34)
    radius: Serp.radiusSmall
    color: primary ? (ma.containsMouse ? Qt.lighter(Serp.accent, 1.08) : Serp.accent) : (ma.containsMouse ? Serp.surface2 : Serp.surface1)
    scale: ma.pressed ? 0.96 : 1
    Behavior on scale {
        NumberAnimation {
            duration: Serp.quick
            easing.type: Easing.OutCubic
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Serp.quick
        }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Serp.px(8)
        SIcon {
            visible: pb.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: pb.icon || "circle-help"
            size: Serp.px(15)
            color: pb.primary ? Serp.onAccent : Serp.text
        }
        SText {
            anchors.verticalCenter: parent.verticalCenter
            text: pb.label
            size: Serp.px(12)
            bold: true
            color: pb.primary ? Serp.onAccent : Serp.text
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pb.clicked()
    }
}
