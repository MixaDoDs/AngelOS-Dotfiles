import QtQuick
import qs.services
import qs.modules.serp

// serp-skin: a labelled button of the network panel — kind "accent" (the main action),
// "danger" (forget), "plain"; an optional spinner instead of the icon while `busy`
Item {
    id: b
    property string text: ""
    property string icon: ""
    property string kind: "plain"
    property bool busy: false
    signal clicked
    onBusyChanged: if (!busy)
        ic.rotation = 0

    implicitHeight: Serp.px(30)
    implicitWidth: row.implicitWidth + Serp.px(24)
    opacity: enabled ? 1 : 0.45

    readonly property color fg: kind === "accent" ? Serp.onAccent : kind === "danger" ? Serp.red : Serp.text
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: b.kind === "accent" ? (ma.containsMouse ? Qt.lighter(Serp.accent, 1.08) : Serp.accent) : b.kind === "danger" ? Qt.alpha(Serp.red, ma.containsMouse ? 0.22 : 0.12) : ma.containsMouse ? Serp.surface2 : Serp.surface1
        border.width: b.kind === "plain" ? 1 : 0
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
        Behavior on color {
            ColorAnimation {
                duration: Serp.quick
            }
        }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Serp.px(6)
        scale: ma.pressed ? 0.94 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Serp.quick
                easing.type: Easing.OutCubic
            }
        }
        SIcon {
            id: ic
            visible: b.icon !== "" || b.busy
            anchors.verticalCenter: parent.verticalCenter
            name: b.busy ? "refresh-cw" : b.icon
            size: Serp.px(13)
            color: b.fg
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: b.busy && b.visible
            }
        }
        SText {
            anchors.verticalCenter: parent.verticalCenter
            text: b.text
            size: Serp.px(11.5)
            bold: true
            color: b.fg
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
