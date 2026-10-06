pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// What every circle's dress of Settings shares (modules/settings/dresses; story/circles.json →
// dress, Config.y2k.hellSettings): a page the chosen view is written on — SettingsView puts it
// into `viewSlot` and re-inks it with the dress's paper, ink and red ink (shaders/grimoire.frag)
// — and a head with the title: drag it to move, double-click to maximize, the closer shuts
// Settings. A dress draws round it: its children sit behind the page (z 0) or over its edge
// (z 2); `pageX` … `pageBottom` say where the page is, `headHeight` how tall the head.
Item {
    id: dress

    required property var view              // SettingsView
    readonly property alias viewSlot: viewSlot
    readonly property alias page: page

    // the page: its paper, the ink the view is written in, the red ink for its accents
    property color paper: "#ecdcb0"
    property color ink: "#3b2415"
    property color redInk: "#8a1020"
    // the head
    property string title: ""
    property color titleColor: Theme.hellText
    property string titleFont: Theme.fontHell
    property int titlePx: Theme.hellPx(1)
    property real headHeight: Theme.u * 18
    property color closer: Theme.hellBlood
    property color closerInk: Theme.hellText
    property real closerCorner: Theme.u
    // where the page sits
    property real pageX: Theme.u * 8
    property real pageTop: headHeight + Theme.u * 2
    property real pageRight: Theme.u * 8
    property real pageBottom: Theme.u * 8
    property real pageMargin: Theme.u * 6
    property real pageCorner: 0
    property color pageEdge: "transparent"
    property real pageEdgeWidth: 0

    // the page
    Rectangle {
        id: page
        z: 1
        x: dress.pageX
        y: dress.pageTop
        width: dress.width - dress.pageX - dress.pageRight
        height: dress.height - dress.pageTop - dress.pageBottom
        radius: dress.pageCorner
        color: dress.paper
        border.width: dress.pageEdgeWidth
        border.color: dress.pageEdge
        Item {
            id: viewSlot
            anchors.fill: parent
            anchors.margins: dress.pageMargin
        }
    }

    // the head: the title, the closer
    Item {
        id: head
        z: 3
        width: dress.width
        height: dress.headHeight
        PxText {
            anchors.centerIn: parent
            kind: "title"
            font.family: dress.titleFont
            font.pixelSize: dress.titlePx
            renderType: Text.NativeRendering
            color: dress.titleColor
            text: dress.title
        }
        MouseArea {
            anchors.fill: parent
            onPressed: if (dress.view.hostWindow)
                dress.view.hostWindow.startSystemMove()
            onDoubleClicked: if (dress.view.hostWindow)
                dress.view.hostWindow.maximized = !dress.view.hostWindow.maximized
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 8
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.u * 11
            height: width
            radius: dress.closerCorner
            color: closeMouse.containsMouse ? Theme.mix(dress.closer, dress.closerInk, 0.3) : dress.closer
            border.width: Math.max(1, Theme.u / 2)
            border.color: Theme.hellEdge
            PxIcon {
                anchors.centerIn: parent
                name: "close"
                pixel: Math.max(1, Math.round(Theme.u / 2))
                ink: dress.closerInk
                fill: dress.closerInk
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dress.view.settingsNav.settingsOpen = false
            }
        }
    }

    // resize grip
    PxIcon {
        z: 3
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        name: "sparkle"
        fill: dress.titleColor
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.u * 3
            cursorShape: Qt.SizeFDiagCursor
            onPressed: if (dress.view.hostWindow)
                dress.view.hostWindow.startSystemResize(Edges.Bottom | Edges.Right)
        }
    }
}
