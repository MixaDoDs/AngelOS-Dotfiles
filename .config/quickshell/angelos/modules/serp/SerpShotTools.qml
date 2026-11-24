pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// serp-skin: the screenshot editor's tools (ShotEditor's left column) as the skin's round
// buttons — a pill each: the line icon, the name, the key; the tool in hand in the accent. The
// editor's own column stays (hidden) beside it; this one sets the same `ed.tool`.
Column {
    id: root
    property var editor: null                // ShotEditor (tools, tool)
    spacing: Serp.px(4)

    // ShotEditor.tools' ids → Lucide (widgets/MacIcons.js)
    readonly property var icons: ({
            "select": "mouse-pointer-2",
            "pen": "activity",
            "marker": "contrast",
            "line": "minus",
            "arrow": "chevron-right",
            "rect": "scan",
            "ellipse": "circle-dot",
            "num": "calculator",
            "text": "type",
            "sticker": "heart",
            "hide": "eye",
            "crop": "scissors"
        })

    Repeater {
        model: root.editor ? root.editor.tools : []
        Rectangle {
            id: pill
            required property var modelData
            readonly property bool on: !!root.editor && root.editor.tool === modelData[0]
            objectName: "serp-tool-" + modelData[0]
            width: root.width
            height: Serp.px(32)
            radius: height / 2
            color: on ? Serp.accent : ma.containsMouse ? Serp.hover : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Serp.quick
                }
            }
            Rectangle {
                // the round icon well
                x: Serp.px(3)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height - Serp.px(6)
                height: width
                radius: width / 2
                color: pill.on ? Qt.alpha(Serp.onAccent, 0.15) : Serp.surface1
                SIcon {
                    anchors.centerIn: parent
                    name: root.icons[pill.modelData[0]] || "circle-help"
                    size: Serp.px(15)
                    color: pill.on ? Serp.onAccent : Serp.text
                }
            }
            SText {
                x: parent.height + Serp.px(2)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - keyCap.width - Serp.px(12)
                text: pill.modelData[2]
                color: pill.on ? Serp.onAccent : Serp.text
            }
            SText {
                id: keyCap
                anchors.right: parent.right
                anchors.rightMargin: Serp.px(12)
                anchors.verticalCenter: parent.verticalCenter
                text: pill.modelData[3]
                size: Serp.smallSize
                color: pill.on ? Qt.alpha(Serp.onAccent, 0.7) : Serp.subtext0
            }
            scale: ma.pressed ? 0.97 : 1
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editor.tool = pill.modelData[0]
            }
        }
    }
}
