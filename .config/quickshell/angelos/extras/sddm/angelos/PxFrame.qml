import QtQuick

// The angelOS window (widgets/PxWindow): an outline, a bevel, a title bar in the title
// gradient with the program's name and three little buttons.
Item {
    id: root

    required property var pal
    property int u: 2
    property string title: ""
    property string icon: "heart"
    property int fontSize: 18
    property string font: ""
    property color body: pal.face
    readonly property int titleHeight: fontSize + u * 6
    readonly property int inset: u * 3
    default property alias content: inner.data

    // drop shadow, outline, bevel
    Rectangle {
        x: root.u * 2
        y: root.u * 2
        width: root.width
        height: root.height
        color: Qt.rgba(0, 0, 0, 0.35)
    }
    Rectangle {
        anchors.fill: parent
        color: root.pal.edge
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.u
        color: root.pal.hi
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.u
        anchors.leftMargin: root.u * 2
        anchors.topMargin: root.u * 2
        color: root.pal.lo
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.u * 2
        color: root.body
    }
    Rectangle {
        id: bar
        x: root.inset
        y: root.inset
        width: root.width - root.inset * 2
        height: root.titleHeight
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: root.pal.title1
            }
            GradientStop {
                position: 1
                color: root.pal.title2
            }
        }
        PixelIcon {
            id: ico
            name: root.icon
            pixel: root.u
            ink: root.pal.edge
            fill: root.pal.accent
            x: root.u * 3
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.left: ico.right
            anchors.leftMargin: root.u * 3
            anchors.right: buttons.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: root.pal.titleText
            font.family: root.font
            font.pixelSize: root.fontSize
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
        Row {
            id: buttons
            anchors.right: parent.right
            anchors.rightMargin: root.u * 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u * 2
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: root.titleHeight - root.u * 6
                    height: width
                    color: root.pal.face
                    border.width: root.u
                    border.color: root.pal.edge
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - root.u * 6
                        height: index === 0 ? root.u * 2 : parent.width - root.u * 6
                        anchors.verticalCenterOffset: index === 0 ? parent.height / 2 - root.u * 4 : 0
                        color: index === 2 ? root.pal.accent : "transparent"
                        border.width: index === 1 ? root.u : 0
                        border.color: root.pal.text
                    }
                }
            }
        }
    }
    Item {
        id: inner
        x: root.inset + root.u * 4
        y: bar.y + bar.height + root.u * 5
        width: root.width - x * 2
        height: root.height - y - root.u * 6
    }
}
