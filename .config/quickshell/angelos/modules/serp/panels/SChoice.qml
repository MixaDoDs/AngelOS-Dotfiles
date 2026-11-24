pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.serp

// serp-skin: a small dropdown (Serpantinum's Dropdown): the current choice in a surface0 field
// with a chevron; open, the list unfolds under it inside the panel. model: [{label, value}]
Item {
    id: dd
    property string title: ""
    property string icon: ""
    property var model: []
    property string value: ""
    property string placeholder: "—"
    property bool open: false
    signal activated(string value)
    readonly property var current: (model || []).find(m => m.value === value) || null
    implicitHeight: field.height + (open ? list.height + Serp.px(4) : 0)
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Serp.normal
            easing.type: Easing.OutCubic
        }
    }
    clip: true

    Rectangle {
        id: field
        width: parent.width
        height: Serp.px(32)
        radius: Serp.radiusSmall
        color: fma.containsMouse ? Serp.surface1 : Serp.surface0
        border.width: 1
        border.color: dd.open ? Qt.alpha(Serp.accent, 0.5) : Serp.line
        Row {
            x: Serp.px(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Serp.px(8)
            SIcon {
                visible: dd.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: dd.icon
                size: Serp.px(14)
                color: Serp.subtext0
            }
            SText {
                anchors.verticalCenter: parent.verticalCenter
                text: dd.title
                size: Serp.px(11)
                dim: true
            }
            SText {
                anchors.verticalCenter: parent.verticalCenter
                width: field.width - Serp.px(130)
                text: dd.current ? dd.current.label : dd.placeholder
                size: Serp.px(11.5)
                bold: !!dd.current
                color: dd.current ? Serp.text : Serp.subtext0
            }
        }
        SIcon {
            anchors.right: parent.right
            anchors.rightMargin: Serp.px(10)
            anchors.verticalCenter: parent.verticalCenter
            name: dd.open ? "chevron-up" : "chevron-down"
            size: Serp.px(14)
            color: Serp.subtext0
        }
        MouseArea {
            id: fma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: (dd.model || []).length > 0
            onClicked: dd.open = !dd.open
        }
    }
    Rectangle {
        id: list
        y: field.height + Serp.px(4)
        width: parent.width
        height: Math.min(Serp.px(150), col.implicitHeight + Serp.px(8))
        radius: Serp.radiusSmall
        color: Serp.base
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
        Flickable {
            anchors.fill: parent
            anchors.margins: Serp.px(4)
            contentHeight: col.implicitHeight
            clip: true
            Column {
                id: col
                width: parent.width
                spacing: Serp.px(2)
                Repeater {
                    model: dd.model || []
                    Rectangle {
                        id: opt
                        required property var modelData
                        readonly property bool on: modelData.value === dd.value
                        width: col.width
                        height: Serp.px(28)
                        radius: Serp.radiusSmall
                        color: on ? Serp.selected : oma.containsMouse ? Serp.hover : "transparent"
                        SText {
                            x: Serp.px(10)
                            width: parent.width - Serp.px(20)
                            anchors.verticalCenter: parent.verticalCenter
                            text: opt.modelData.label
                            size: Serp.px(11.5)
                            color: opt.on ? Serp.accent : Serp.text
                        }
                        MouseArea {
                            id: oma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dd.open = false;
                                dd.activated(opt.modelData.value);
                            }
                        }
                    }
                }
            }
        }
    }
}
