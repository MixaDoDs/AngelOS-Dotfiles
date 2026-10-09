import QtQuick
import QtQuick.Effects
import qs.config
import qs.services
import qs.widgets

// The desktop widget's other two frames (Settings → Widgets → Frame; DesktopWidgetHost):
//   plate  a plain pixel plate with a hard shadow, no title bar; the widget's name shows on a
//          little tab over its corner while the pointer is on it, in edit mode and in a drag
//   none   nothing at all: the content stands on the wallpaper with a hard pixel shadow under
//          it so it reads on any picture; the tab the same as above
// The whole frame is the handle (under the content: buttons in it still take their clicks).
// In hell (Theme.realm) the plate is the circle's obsidian with its rim, like PxWindow.
Item {
    id: root

    property bool bare: false               // "none"
    property bool hell: false
    property bool fill: true                // false: an input copy over its face draws only what's on top
    property bool shadow: Config.appearance.shadows
    property bool showName: false
    property bool closable: false
    property string title: ""
    property string icon: "heart"
    readonly property int padding: bare ? Theme.u * 2 : Theme.u * 5
    readonly property alias bodyItem: inner
    readonly property alias dragArea: drag
    readonly property int tabHeight: tab.height
    signal closeClicked

    PxBox {
        id: plate
        visible: !root.bare
        anchors.fill: parent
        hell: root.hell
        flat: true
        color: !root.fill ? "transparent" : root.hell ? Theme.hellPanel : Theme.panel
        shadow: root.shadow && root.fill
        shadowSize: Theme.u * 3
    }

    // the whole frame (and the name tab while it shows) moves the widget
    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: tab.visible ? -tab.height : 0
    }

    Item {
        id: inner
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        height: root.height - root.padding * 2
    }
    // none: a hard pixel shadow under the content, so it reads on any wallpaper (the content's
    // own picture, darkened and moved an art pixel down and right, under it)
    ShaderEffectSource {
        id: ink
        visible: false
        sourceItem: root.bare && root.fill ? inner : null
        live: true
    }
    MultiEffect {
        visible: root.bare && root.fill
        x: inner.x + Theme.u
        y: inner.y + Theme.u
        z: -1
        width: inner.width
        height: inner.height
        source: ink
        brightness: -1
        colorization: 1
        colorizationColor: Theme.dark || root.hell ? "#000000" : Theme.shadow
        opacity: Theme.dark || root.hell ? 0.8 : 0.45
    }

    // ---- hell's rim over the plate ----
    HellEdge {
        visible: root.hell && !root.bare && root.fill
        anchors.fill: parent
        z: 3
        seed: (root.title.length * 7 + root.title.charCodeAt(0)) || 1
    }

    // ---- the name tab over the top-left corner ----
    PxBox {
        id: tab
        visible: root.showName
        x: root.bare ? 0 : Theme.u * 3
        y: -height + (root.bare ? 0 : plate.ob)
        z: 4
        width: tabRow.implicitWidth + Theme.u * 6
        height: tabRow.implicitHeight + Theme.u * 3
        hell: root.hell
        flat: true
        color: root.hell ? Theme.mix(Theme.hellFaceAlt, Theme.hellRim, 0.25) : Theme.menuHeader
        Row {
            id: tabRow
            anchors.centerIn: parent
            spacing: Theme.u * 2
            PxIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                pixel: Math.max(1, Theme.u - 1)
                ink: root.hell ? Theme.hellEdge : Theme.edge
                fill: root.hell ? Theme.hellTextDim : "#ffffff"
                body: root.hell ? Theme.hellFace : "#ffffff"
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                kind: "tiny"
                font.bold: !root.hell
                font.family: root.hell && Theme.latin(root.title) ? Theme.fontHell : Theme.fontBody
                font.pixelSize: root.hell && Theme.latin(root.title) ? Theme.hellPx(Theme.fs) : Theme.sizeTiny
                color: root.hell ? Theme.hellText : Theme.text
            }
        }
    }

    // ---- edit mode: the cross on the top-right corner ----
    PxButton {
        visible: root.closable
        x: root.width - width / 2 - Theme.u * 2
        y: -height / 2 + Theme.u * 2
        z: 5
        compact: true
        hell: root.hell
        icon: "close"
        iconPixel: Math.max(1, Theme.u - 1)
        onClicked: root.closeClicked()
    }
}
