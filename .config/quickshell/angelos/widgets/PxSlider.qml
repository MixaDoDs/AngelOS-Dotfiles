import QtQuick
import qs.config
import qs.services
import "A11y.js" as A11y

// Pixel slider: sunken track, pink fill, heart thumb.
Item {
    id: root
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: Theme.p5For(root.parent)
    // the filled part (a caller in another colour scheme passes its own, e.g. the Halo)
    property color fill: Theme.accent

    property real from: 0
    property real to: 1
    property real value: 0
    // what the pointer (or a wheel step) set, shown until the owner's binding answers. `value`
    // itself is never assigned: that cut the owner's binding (Config, a service), and after one
    // drag an Undo, a reset, a clamp or another window no longer moved the slider — it showed a
    // value that was not the one saved. A value the owner didn't take shows as it is once let go
    property real _held: NaN
    readonly property real shown: isNaN(_held) ? value : _held
    onValueChanged: if (!mouse.pressed)
        _held = NaN
    property real stepSize: 0
    property bool live: true
    property string suffix: ""
    property int decimals: 0
    property bool showValue: true
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    // the P5 settings window draws like the classic look, in its own colours
    readonly property bool classicLike: settingsSkin === "classic" || settingsSkin === "p5"
    // the Golden Gate skin's System Settings: a Mac slider — a thin track, the accent up to a
    // round white knob
    readonly property bool mac: settingsSkin === "goldengate"
    property real valueScale: 1
    readonly property bool dragging: mouse.pressed
    signal moved(real value)
    signal released(real value)

    // steps up (1) or down (-1): the wheel, a screen reader's increase / decrease
    function nudge(dir) {
        const step = stepSize > 0 ? stepSize : (to - from) / 50;
        const v = Math.max(Math.min(from, to), Math.min(Math.max(from, to), shown + dir * step));
        _held = v;
        moved(v);
        released(v);
        letGo.restart();
    }
    Accessible.role: Accessible.Slider
    Accessible.name: A11y.rowLabel(root)
    Accessible.description: (shown * valueScale).toFixed(decimals) + suffix
    Accessible.focusable: true
    Accessible.onIncreaseAction: nudge(1)
    Accessible.onDecreaseAction: nudge(-1)

    // in a box marked fixedWidth (SettingRow's control column) no wider than it, as PxSegmented
    implicitWidth: parent && parent.fixedWidth === true ? Math.min(Theme.u * 110, parent.width) : Theme.u * 110
    implicitHeight: Theme.u * 12

    readonly property real frac: to === from ? 0 : Math.max(0, Math.min(1, (shown - from) / (to - from)))
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
        visible: root.classicLike
        anchors.left: parent.left
        anchors.right: valueLabel.visible ? valueLabel.left : parent.right
        anchors.rightMargin: valueLabel.visible ? Theme.u * 4 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.u * 6
        sunken: true
        color: Theme.tone("sunken", root.p5)

        Rectangle {
            x: 0
            y: 0
            height: parent.height - track.inset * 2
            width: Math.max(0, thumb.x + thumb.width / 2 - track.inset)
            color: root.fill
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
        visible: !root.classicLike && !root.mac
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
        visible: root.classicLike
        width: Theme.u * 9
        height: Theme.u * 12
        anchors.verticalCenter: track.verticalCenter
        x: track.x + root.frac * (track.width - width)
        color: mouse.containsMouse || mouse.pressed ? Theme.tone("faceAlt", root.p5) : Theme.tone("face", root.p5)
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
        visible: !root.classicLike && !root.mac
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
        text: (root.shown * root.valueScale).toFixed(root.decimals) + root.suffix
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
                root._held = v;
            root.moved(v);
        }
        // a drag ends with `released` however it ends: a press taken away (an overlay that
        // grabs the pointer, the window losing it) never sends onReleased, and a page that
        // saves on release would keep the old value (the keyboard's repeat sliders)
        property bool dragOpen: false
        onPressed: m => {
            dragOpen = true;
            apply(m.x);
        }
        onPositionChanged: m => {
            if (pressed)
                apply(m.x);
        }
        onReleased: m => {
            dragOpen = false;
            root.released(root.valueAt(m.x));
            letGo.restart();
        }
        onCanceled: {
            if (!dragOpen)
                return;
            dragOpen = false;
            root.released(root.shown);
            letGo.restart();
        }
        // only once the pointer rests on it or it was pressed: scrolling the page past it
        // doesn't turn it (#93)
        onWheel: w => {
            const n = wheelGate.steps(w);
            if (n !== 0)
                root.nudge(n);
        }
        WheelGate {
            id: wheelGate
            hovered: mouse.containsMouse
            held: mouse.pressed
        }
    }
    Timer {
        id: letGo
        interval: 2000
        onTriggered: if (!mouse.pressed)
            root._held = NaN
    }
}
