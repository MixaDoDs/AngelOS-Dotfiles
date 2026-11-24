import QtQuick
import qs.services

// serp-skin: a dialog's button in Serpantinum's look — a rounded pill. kind: "" a plain one on
// surface1, "primary" the accent, "danger" red (shut down, restart…), "flat" no ground until
// hovered. `selected`: the one the keys picked, a ring around it.
Item {
    id: pill

    property string label: ""
    property string icon: ""
    property string kind: ""
    property bool selected: false
    readonly property bool hovered: ma.containsMouse
    signal clicked

    readonly property bool filled: kind === "primary" || kind === "danger"
    readonly property color fill: kind === "primary" ? Serp.accent : kind === "danger" ? Serp.red : kind === "flat" ? "transparent" : Serp.surface1
    readonly property color ink: filled ? Serp.onAccent : kind === "flat" ? Serp.subtext1 : Serp.text

    implicitWidth: content.implicitWidth + Serp.px(30)
    implicitHeight: Serp.px(34)
    opacity: enabled ? 1 : 0.45

    // the keys' pick
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Serp.px(3)
        radius: height / 2
        color: "transparent"
        border.width: Serp.px(2)
        border.color: pill.filled ? pill.fill : Serp.accent
        opacity: pill.selected ? 0.9 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Serp.quick
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: pill.filled ? (ma.containsMouse ? Qt.lighter(pill.fill, 1.1) : pill.fill) : ma.containsMouse ? (pill.kind === "flat" ? Serp.hover : Serp.surface2) : pill.fill
        border.width: pill.kind === "" ? 1 : 0
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
        Behavior on color {
            ColorAnimation {
                duration: Serp.quick
            }
        }
    }
    Row {
        id: content
        anchors.centerIn: parent
        spacing: Serp.px(6)
        scale: ma.pressed ? 0.95 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Serp.quick
                easing.type: Easing.OutCubic
            }
        }
        SIcon {
            visible: pill.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: pill.icon || "circle-help"
            size: Serp.px(15)
            color: pill.ink
        }
        SText {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.label
            bold: true
            color: pill.ink
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: pill.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
