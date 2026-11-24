import QtQuick
import qs.services

// serp-skin: Serpantinum's wavy seek bar (its WavySeekBar, drawn on a Canvas instead of its
// shader): the played part a sine line in the accent, the rest a flat track; the wave lies down
// while paused. Drag or click to seek when `seekable`. Moves only while `active`.
Item {
    id: bar
    property real value: 0          // 0..1
    property bool playing: false
    property bool seekable: false
    property bool active: visible
    // a hover copy lying over its own face (desktop widgets): catch the pointer, draw nothing — the
    // face below draws the wave; a stale picture of its own jerked as the copy came up
    property bool ghost: false
    property color waveColor: Serp.mauve
    property color trackColor: Serp.surface2
    property real amplitude: Serp.px(6)
    property real stroke: Serp.px(4.5)
    signal seek(real fraction)

    implicitWidth: Serp.px(300)
    implicitHeight: Serp.px(28)

    readonly property bool dragging: ma.pressed
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))

    property real amp: playing ? 1 : 0
    Behavior on amp {
        NumberAnimation {
            duration: 600
            easing.type: Easing.OutQuad
        }
    }
    // the wave's phase from the wall clock: every copy of the bar (a desktop widget's face and its
    // hover copy) draws the same wave — a phase of its own doubled the line
    property real phase: 0
    Timer {
        interval: 33
        repeat: true
        running: bar.active && (bar.playing || bar.amp > 0.001)
        onTriggered: bar.phase = (Date.now() % 1800) / 1800 * Math.PI * 2
    }
    // a fresh copy stands where the song is at once (it slid in from 0 and showed a second line)
    property bool settled: false
    Timer {
        interval: 400
        running: true
        onTriggered: bar.settled = true
    }
    property real shownX: shown
    Behavior on shownX {
        enabled: !bar.dragging && bar.settled
        NumberAnimation {
            duration: Serp.normal
        }
    }

    onPhaseChanged: cv.requestPaint()
    onAmpChanged: cv.requestPaint()
    onShownXChanged: cv.requestPaint()
    onWaveColorChanged: cv.requestPaint()
    onTrackColorChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()

    readonly property real pad: Serp.px(8)
    Canvas {
        id: cv
        visible: !bar.ghost
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const w = width, cy = height / 2, p = bar.pad;
            const ex = p + (w - 2 * p) * bar.shownX;
            c.lineCap = "round";
            c.lineWidth = bar.stroke;
            // the rest: flat
            c.strokeStyle = bar.trackColor;
            c.beginPath();
            c.moveTo(Math.min(w - p, ex + bar.stroke), cy);
            c.lineTo(w - p, cy);
            c.stroke();
            // the played part: a sine, tapering in at the start
            if (ex > p) {
                c.strokeStyle = bar.waveColor;
                c.beginPath();
                const k = 2 * Math.PI / Serp.px(34);
                const a = bar.amplitude * bar.amp;
                for (let x = p; x <= ex; x += 2) {
                    const taper = Math.min(1, (x - p) / Serp.px(24));
                    const y = cy + Math.sin((x - p) * k - bar.phase) * a * taper;
                    if (x === p)
                        c.moveTo(x, y);
                    else
                        c.lineTo(x, y);
                }
                c.lineTo(ex, cy + Math.sin((ex - p) * k - bar.phase) * a * Math.min(1, (ex - p) / Serp.px(24)));
                c.stroke();
            }
        }
    }
    Rectangle {
        id: knob
        width: Serp.px(14)
        height: width
        radius: width / 2
        x: bar.pad + (bar.width - 2 * bar.pad) * bar.shownX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: ma.containsMouse || bar.dragging ? Qt.lighter(bar.waveColor, 1.15) : bar.waveColor
        visible: bar.seekable
        scale: bar.dragging ? 1.25 : ma.containsMouse ? 1.15 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Serp.quick
                easing.type: Easing.OutBack
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: bar.seekable
        hoverEnabled: true
        cursorShape: bar.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
        function at(x) {
            return Math.max(0, Math.min(1, (x - bar.pad) / Math.max(1, bar.width - 2 * bar.pad)));
        }
        onPressed: m => bar.dragValue = at(m.x)
        onPositionChanged: m => {
            if (pressed)
                bar.dragValue = at(m.x);
        }
        onReleased: m => bar.seek(at(m.x))
    }
}
