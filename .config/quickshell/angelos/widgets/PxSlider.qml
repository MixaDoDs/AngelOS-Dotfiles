import QtQuick
import qs.config
import qs.services

// Pixel slider: sunken track, pink fill, heart thumb.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    property bool live: true
    property string suffix: ""
    property int decimals: 0
    property bool showValue: true
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    // the Golden Gate skin's System Settings: a Mac slider — a thin track, the accent up to a
    // round white knob
    readonly property bool mac: settingsSkin === "goldengate"
    property real valueScale: 1
    readonly property bool dragging: mouse.pressed
    signal moved(real value)
    signal released(real value)

    implicitWidth: Theme.u * 110
    implicitHeight: Theme.u * 12

    readonly property real frac: to === from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))
    property real _drag: frac

    function valueAt(x) {
        let f = Math.max(0, Math.min(1, (x - thumb.width / 2) / (track.width - thumb.width)));
        let v = from + f * (to - from);
        if (stepSize > 0)
            v = Math.round((v - from) / stepSize) * stepSize + from;
        return Math.max(Math.min(from, to), Math.min(Math.max(from, to), v));
    }

    PxBox {
        id: track
        visible: root.settingsSkin === "classic"
        anchors.left: parent.left
        anchors.right: valueLabel.visible ? valueLabel.left : parent.right
        anchors.rightMargin: valueLabel.visible ? Theme.u * 4 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.u * 6
        sunken: true
        color: Theme.sunken

        Rectangle {
            x: 0
            y: 0
            height: parent.height - track.inset * 2
            width: Math.max(0, thumb.x + thumb.width / 2 - track.inset)
            color: Theme.accent
        }
    }

    Rectangle {
        visible: root.mac
        x: track.x
        anchors.verticalCenter: track.verticalCenter
        width: track.width
        height: GoldenGate.px(4)
        radius: height / 2
        color: GoldenGate.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
        Rectangle {
            width: Math.max(parent.height, thumb.x - track.x + thumb.width / 2)
            height: parent.height
            radius: parent.radius
            color: GoldenGate.accent
        }
    }
    Rectangle {
        visible: root.settingsSkin !== "classic" && !root.mac
        x: track.x
        y: track.y
        width: track.width
        height: track.height
        radius: root.settingsSkin === "stream" ? Theme.u * 2 : height / 2
        color: root.settingsSkin === "stream" ? Theme.streamPanel : Theme.windoseSticker
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.settingsSkin === "stream" ? Theme.streamLive : Theme.windoseLine
        Rectangle {
            x: Theme.u
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, (parent.width - Theme.u * 2) * root.frac)
            height: parent.height - Theme.u * 2
            radius: parent.radius
            color: root.settingsSkin === "stream" ? Theme.streamLive : Theme.windoseRose
        }
    }

    PxBox {
        id: thumb
        visible: root.settingsSkin === "classic"
        width: Theme.u * 9
        height: Theme.u * 12
        anchors.verticalCenter: track.verticalCenter
        x: track.x + root.frac * (track.width - width)
        color: mouse.containsMouse || mouse.pressed ? Theme.faceAlt : Theme.face
        PxIcon {
            anchors.centerIn: parent
            name: "heartSmall"
            pixel: Math.max(1, Theme.u - 1)
        }
    }
    Rectangle {
        visible: root.mac
        width: GoldenGate.px(20)
        height: width
        radius: width / 2
        anchors.verticalCenter: track.verticalCenter
        x: thumb.x + (thumb.width - width) / 2
        color: "#ffffff"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, mouse.pressed ? 0.25 : 0.14)
    }
    Rectangle {
        visible: root.settingsSkin !== "classic" && !root.mac
        width: thumb.width
        height: thumb.height
        anchors.verticalCenter: track.verticalCenter
        x: thumb.x
        radius: root.settingsSkin === "windose" ? width / 2 : Theme.u * 2
        color: root.settingsSkin === "stream" ? Theme.ngoSticker : Theme.windoseSticker
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.settingsSkin === "stream" ? Theme.streamLive : Theme.windoseLine
    }

    PxText {
        id: valueLabel
        visible: root.showValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.u * 26
        horizontalAlignment: Text.AlignRight
        text: (root.value * root.valueScale).toFixed(root.decimals) + root.suffix
    }

    MouseArea {
        id: mouse
        anchors.fill: track
        anchors.topMargin: -Theme.u * 4
        anchors.bottomMargin: -Theme.u * 4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function apply(mx) {
            const v = root.valueAt(mx);
            if (root.live)
                root.value = v;
            root.moved(v);
        }
        onPressed: m => apply(m.x)
        onPositionChanged: m => {
            if (pressed)
                apply(m.x);
        }
        onReleased: m => root.released(root.valueAt(m.x))
        onWheel: w => {
            const step = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 50;
            const v = Math.max(Math.min(root.from, root.to), Math.min(Math.max(root.from, root.to), root.value + (w.angleDelta.y > 0 ? step : -step)));
            root.value = v;
            root.moved(v);
            root.released(v);
        }
    }
}
