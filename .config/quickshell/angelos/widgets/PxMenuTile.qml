import QtQuick
import qs.config
import qs.services

// One of the everyday actions in a pixel menu's top row (PxMenuList.quick): its icon, its short
// name under it; lit while on (a checked toggle); with `choices` (a widget's S M L) small
// buttons under the icon instead of the name. The colours of the menu it stands in.
Item {
    id: root

    property var entry: null
    property real scale_: 1
    property bool highlighted: false
    readonly property var t: MenuLook.tokensFor(root.parent)
    readonly property var choices: entry && entry.choices ? Array.from(entry.choices) : []
    readonly property bool on: !!entry && MenuLook.on(entry.checked, false)
    readonly property bool usable: !!entry && MenuLook.on(entry.enabled, true)
    readonly property bool lit: (mouse.containsMouse || highlighted) && usable
    signal triggered
    signal choiceTriggered(int index)

    Accessible.role: Accessible.Button
    Accessible.name: entry ? entry.label || "" : ""
    Accessible.onPressAction: if (usable)
        triggered()

    // as wide as its name needs, within reason (a long one elides)
    width: Math.round(Math.max(Theme.u * 30 * scale_, Math.min(Theme.u * 48, caption.implicitWidth + Theme.u * 4)))
    height: col.implicitHeight + Theme.u * 4
    opacity: usable ? 1 : 0.45

    // serp-skin: a soft rounded plate instead of the bevelled tile
    Rectangle {
        visible: !!root.t.serp && (root.lit || root.on)
        anchors.fill: parent
        radius: Serp.radiusSmall
        color: root.on ? Serp.selected : Serp.hover
        border.width: root.on && root.highlighted ? 1 : 0
        border.color: Serp.accent
    }
    PxBox {
        anchors.fill: parent
        visible: (root.lit || root.on) && !root.t.serp  // serp-skin
        sunken: mouse.pressed || root.on
        hell: root.t.hellBox
        color: root.on ? Theme.mix(root.t.tileBg, Theme.accent, 0.35) : root.t.tileBg
    }
    Column {
        id: col
        anchors.centerIn: parent
        spacing: Theme.u
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.u * 12 * root.scale_
            height: width
            PxIcon {
                anchors.centerIn: parent
                name: root.entry ? root.entry.icon || "heart" : "heart"
                pixel: root.scale_ > 1.1 ? Theme.u * 2 : Theme.u
                ink: root.t.ink
                visible: !root.t.serp  // serp-skin
            }
            // serp-skin: the skin's line icon
            MacIcon {
                anchors.centerIn: parent
                visible: !!root.t.serp
                name: root.t.serp ? MenuLook.serpIcon(root.entry ? root.entry.icon || "heart" : "heart") : "circle-dot"
                size: Math.round(parent.width * 0.75)
                stroke: 2
                color: root.on || root.lit ? Serp.accent : Serp.text
            }
        }
        PxText {
            id: caption
            visible: root.choices.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width - Theme.u * 2
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.entry ? root.entry.short || root.entry.label || "" : ""
            kind: "tiny"
            color: root.t.text
        }
        Row {
            visible: root.choices.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.max(1, Theme.u / 2)
            Repeater {
                model: root.choices
                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool sel: MenuLook.on(modelData.checked, false)
                    width: Math.max(Theme.u * 7, chipText.implicitWidth + Theme.u * 2)
                    height: Theme.u * 7
                    color: sel ? (root.t.serp ? Serp.accent : Theme.accent) : chipMouse.containsMouse ? Qt.alpha(root.t.serp ? Serp.accent : Theme.accent, 0.3) : Qt.alpha(root.t.lo, 0.5)  // serp-skin
                    radius: root.t.serp ? Serp.px(3) : 0  // serp-skin
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: root.t.edge
                    PxText {
                        id: chipText
                        anchors.centerIn: parent
                        kind: "tiny"
                        text: chip.modelData.label || ""
                        color: chip.sel ? (root.t.serp ? Serp.onAccent : Theme.selectText) : root.t.text  // serp-skin
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choiceTriggered(chip.index)
                    }
                }
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        enabled: root.usable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
