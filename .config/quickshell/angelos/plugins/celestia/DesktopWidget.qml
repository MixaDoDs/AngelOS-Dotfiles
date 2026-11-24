import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// celestia.exe: the face and what she says. The host draws the frame in every look.
Item {
    id: root
    property var plugin
    property string screenName
    property var widget

    readonly property real side: Skin.macWidgets ? DesktopWidgets.mpx(230) : Theme.u * 112
    implicitWidth: side
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Skin.spacing
        Face {
            id: face
            width: root.side
            height: root.side
            plugin: root.plugin
            screenName: root.screenName
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onPositionChanged: m => Brain.lookAt(m.x / width * 2 - 1, 1 - m.y / height * 2)
                onClicked: Brain.click()
            }
        }
        Limits {
            visible: root.plugin ? root.plugin.get("deskLimits", true) : true
            width: parent.width
            compact: true
            mac: Skin.macWidgets
            hell: Theme.hell
        }
        PxText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Brain.spoken ? Brain.typed : Brain.word
            wrapMode: Text.Wrap
            maximumLineCount: 3
            kind: Brain.spoken ? "body" : "tiny"
            font.family: Serp.on ? Serp.font : Skin.macWidgets ? Skin.font : Theme.fontBody  // serp-skin
            color: Theme.hell ? (Brain.spoken ? Theme.hellText : Theme.hellTextDim) : (Brain.spoken ? Skin.text : Skin.textDim)
        }
    }
}
