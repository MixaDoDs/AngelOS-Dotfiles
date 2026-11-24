import QtQuick
import qs.services
import qs.modules.serp

// serp-skin settings: Serpantinum's SettingsRow — a soft card: an icon box, the title and a
// line about it, the control on the right; `below` holds what unfolds under it (a dropdown).
// rowKey is what the search finds; flash() is its mauve "here it is".
Rectangle {
    id: row
    property string rowKey: ""
    property string icon: "settings"
    property string title: ""
    property string desc: ""
    property bool expanded: false
    default property alias control: ctl.data
    property alias below: belowBox.data
    property real flashA: 0
    readonly property int padH: Serp.px(14)
    readonly property int padV: Serp.px(12)

    width: parent ? parent.width : 0
    height: head.height + (expanded ? belowBox.childrenRect.height + padV : 0)
    clip: true
    radius: Serp.radius
    color: hov.hovered ? Qt.alpha(Serp.surface1, 0.4) : Qt.alpha(Serp.surface0, 0.4)
    Behavior on color {
        ColorAnimation {
            duration: Serp.quick
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: Serp.normal
            easing.type: Easing.OutCubic
        }
    }
    HoverHandler {
        id: hov
    }

    function flash() {
        fl.restart();
    }
    SequentialAnimation {
        id: fl
        NumberAnimation {
            target: row
            property: "flashA"
            from: 0
            to: 0.16
            duration: 400
            easing.type: Easing.OutCubic
        }
        PauseAnimation {
            duration: 1500
        }
        NumberAnimation {
            target: row
            property: "flashA"
            to: 0
            duration: 900
            easing.type: Easing.InOutSine
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.alpha(Serp.mauve, row.flashA)
    }

    Item {
        id: head
        width: parent.width
        height: Math.max(Serp.px(32), texts.implicitHeight, ctl.height) + row.padV * 2
        Rectangle {
            id: iconBox
            x: row.padH
            anchors.verticalCenter: parent.verticalCenter
            width: Serp.px(32)
            height: width
            radius: Serp.radiusSmall
            color: Qt.alpha(Serp.surface1, 0.6)
            SIcon {
                anchors.centerIn: parent
                name: row.icon
                size: Serp.px(16)
                color: Serp.subtext0
            }
        }
        Column {
            id: texts
            anchors.left: iconBox.right
            anchors.leftMargin: Serp.px(12)
            anchors.right: ctl.left
            anchors.rightMargin: Serp.px(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Serp.px(2)
            SText {
                width: parent.width
                text: row.title
                size: Serp.px(13)
            }
            SText {
                width: parent.width
                visible: text !== ""
                text: row.desc
                size: Serp.px(11)
                color: Serp.subtext0
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
        Item {
            id: ctl
            anchors.right: parent.right
            anchors.rightMargin: row.padH
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }
    Item {
        id: belowBox
        x: row.padH
        y: head.height
        width: parent.width - row.padH * 2
        height: childrenRect.height
        visible: row.expanded || row.height > head.height + 1
    }
}
