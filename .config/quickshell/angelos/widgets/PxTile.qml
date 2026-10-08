import QtQuick
import qs.config
import "A11y.js" as A11y

// Big raised button of the simple settings view: icon, name, one line of what's inside.
Item {
    id: root

    property string icon: "heart"
    property string text: ""
    property string hint: ""
    property bool small: false
    signal clicked

    Accessible.role: Accessible.Button
    Accessible.name: A11y.name(text, root, icon)
    Accessible.description: hint
    Accessible.focusable: true
    Accessible.onPressAction: if (enabled)
        clicked()

    implicitWidth: small ? Theme.u * 78 : Theme.u * 92
    implicitHeight: col.implicitHeight + Theme.u * (small ? 8 : 12)

    PxBox {
        anchors.fill: parent
        sunken: mouse.pressed
        color: mouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.2) : Theme.face
        shadow: Config.appearance.shadows && !mouse.pressed
    }
    Column {
        id: col
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: mouse.pressed ? Theme.u : 0
        anchors.verticalCenterOffset: mouse.pressed ? Theme.u : 0
        width: parent.width - Theme.u * 8
        spacing: Theme.u * 2
        PxIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: root.icon
            pixel: root.small ? Theme.u : Theme.u * 2
        }
        PxText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            font.bold: true
            wrapMode: Text.Wrap
        }
        PxText {
            visible: root.hint !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.hint
            kind: "tiny"
            dim: true
            wrapMode: Text.Wrap
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
