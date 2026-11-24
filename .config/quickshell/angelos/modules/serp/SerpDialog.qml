pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// serp-skin: the face of an angelOS dialog in Serpantinum's look — a centred card of liquid glass
// (frosted hard, tinted ≥ 0.75: text over any wallpaper), an icon and a bold title, the body, what
// the dialog adds of its own (children), a dim note and a row of pills. It decides nothing: the
// dialog's own window keeps its keys and its functions (hunks/dialogs.py hides its pixel frame
// under Serp.on and lays this over it, the hidden frame's focus still taking the keys); this only
// says what was picked (`picked`, `hoveredButton`, `dismissed` = a click beside the card).
//
//     SerpDialog { title: …; buttons: [{label, icon, kind}]; current: win.current; onPicked: i => … }
Item {
    id: root

    anchors.fill: parent
    visible: Serp.on

    property string icon: ""
    property color iconTint: Serp.accent
    property string title: ""
    property string body: ""
    property string note: ""
    property var buttons: []           // [{label, icon, kind: "" | primary | danger | flat, enabled}]
    property int current: -1           // the pill the keys picked
    property bool centred: false       // the pills in the middle (else on the right)
    property real cardWidth: Serp.px(440)
    property int pad: Serp.px(18)
    default property alias extra: extraBox.data
    readonly property alias card: card

    signal dismissed
    signal picked(int index)
    signal hoveredButton(int index)

    // the wallpaper in screen space, for the liquid glass
    SerpBackdrop {
        id: glassBack
        active: Serp.glassOn && root.visible
    }

    // beside the card: the dialog's own «later / cancel»; it also keeps the hidden frame's
    // buttons from the pointer
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.dismissed()
    }

    SGlass {
        id: card
        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width - Serp.px(32))
        height: col.implicitHeight + root.pad * 2
        radius: Serp.radius + Serp.px(4)
        backdrop: glassBack
        tintAmount: Math.max(Serp.cfg.glassTint, 0.75)  // text-heavy: readable over any wallpaper
        frost: 6

        // the card eats its clicks and its hover
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Column {
            id: col
            x: root.pad
            y: root.pad
            width: card.width - root.pad * 2
            spacing: Serp.px(12)

            Row {
                width: parent.width
                spacing: Serp.px(12)
                Rectangle {
                    id: badge
                    visible: root.icon !== ""
                    width: Serp.px(36)
                    height: width
                    radius: width / 2
                    color: Qt.alpha(root.iconTint, 0.18)
                    anchors.verticalCenter: parent.verticalCenter
                    SIcon {
                        anchors.centerIn: parent
                        name: root.icon || "circle-help"
                        size: Serp.px(18)
                        color: root.iconTint
                    }
                }
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (badge.visible ? badge.width + parent.spacing : 0)
                    text: root.title
                    size: Serp.px(16)
                    bold: true
                    wrapMode: Text.Wrap
                }
            }
            SText {
                visible: text !== ""
                width: parent.width
                text: root.body
                color: Serp.subtext1
                wrapMode: Text.Wrap
                lineHeight: 1.15
            }
            Column {
                id: extraBox
                visible: children.length > 0
                width: parent.width
                spacing: Serp.px(8)
            }
            SText {
                visible: text !== ""
                width: parent.width
                text: root.note
                size: Serp.smallSize
                dim: true
                wrapMode: Text.Wrap
            }
            Item {
                visible: root.buttons.length > 0
                width: parent.width
                height: pills.height + Serp.px(6)
                Row {
                    id: pills
                    y: Serp.px(4)
                    anchors.right: root.centred ? undefined : parent.right
                    anchors.horizontalCenter: root.centred ? parent.horizontalCenter : undefined
                    spacing: Serp.px(8)
                    Repeater {
                        model: root.buttons
                        SerpDialogPill {
                            required property var modelData
                            required property int index
                            label: modelData.label || ""
                            icon: modelData.icon || ""
                            kind: modelData.kind || ""
                            visible: modelData.visible !== false
                            enabled: modelData.enabled !== false
                            selected: root.current === index
                            onClicked: root.picked(index)
                            onHoveredChanged: if (hovered)
                                root.hoveredButton(index)
                        }
                    }
                }
            }
        }
    }
}
