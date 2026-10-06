import QtQuick
import qs.config
import qs.services

// A card in the look in use (services/Skin, the Theme API): the body of a plugin's widget, a
// popup's panel, a group of rows. Pixel: a raised (or sunken) bevelled PxBox in the theme's face.
// Mac: a rounded slab — Liquid Glass (MacGlass: tint, rim, shadow) when transparency is allowed,
// a solid group otherwise; `sunken` makes it a quiet inset group. Hell: hell's obsidian box.
// The content goes inside `padding`; the card is as big as its content unless sized:
//   SkinCard { width: Skin.px(220); Column { width: parent.width; PxText { text: "…" } } }
// Its children see settingsSkin, so the shared controls inside take the same look.
Item {
    id: root

    property bool sunken: false
    // the Mac look's quiet group (a row inside a popover, a well) instead of a glass card
    property bool group: sunken
    // the pixel box's colour (the face, or the well when sunken)
    property color pixelColor: sunken ? Theme.sunken : Theme.face
    property bool shadow: !sunken && !group
    property int padding: Skin.padding
    property real radius: group ? Skin.radius : Skin.cardRadius
    // the Mac look for the controls inside; in pixel the parents' own (classic, Windose, Stream)
    readonly property string settingsSkin: macBody ? "goldengate" : Theme.settingsSkinFor(parent)
    readonly property bool macBody: Skin.mac && !Skin.hell
    default property alias content: inner.data

    implicitWidth: inner.childrenRect.width + padding * 2
    implicitHeight: inner.childrenRect.height + padding * 2

    // ---- pixel and hell ----
    PxBox {
        visible: !root.macBody
        anchors.fill: parent
        hell: Skin.hell
        sunken: root.sunken
        shadow: root.shadow && Config.appearance.shadows
        color: Skin.hell ? (root.sunken ? Theme.hellSunken : Theme.hellFace) : root.pixelColor
    }
    // ---- mac: glass, or a quiet group inside one ----
    Loader {
        anchors.fill: parent
        active: root.macBody
        sourceComponent: root.group ? groupC : glass
    }
    Component {
        id: glass
        MacGlass {
            radius: root.radius
            shadow: root.shadow
            shadowSize: GoldenGate.px(18)
            shadowY: GoldenGate.px(4)
        }
    }
    Component {
        id: groupC
        Rectangle {
            radius: root.radius
            color: GoldenGate.groupBg
            border.width: 1
            border.color: GoldenGate.separator
        }
    }

    Item {
        id: inner
        x: root.padding
        y: root.padding
        width: Math.max(0, root.width - root.padding * 2)
        height: Math.max(0, root.height - root.padding * 2)
    }
}
