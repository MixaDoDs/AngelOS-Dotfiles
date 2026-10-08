import QtQuick
import Quickshell.Services.Pipewire
import qs.config

// Pixel VU meter for a PipeWire node (a microphone by default): lit segments
// follow the live peak in dB, a hollow segment holds the recent maximum.
// The capture stream exists only while `active` (no cost when hidden).
Item {
    id: root

    property var node: null
    property bool active: visible
    property int segments: 24
    property real floorDb: -60
    readonly property real peak: monitor.peak || 0
    // Quickshell gives the peak on PipeWire's cubic volume scale (a 0.1 sine reads 0.464,
    // its cube root): the amplitude is peak³, so dB = 60·log10(peak). Read as amplitude
    // the meter showed a quiet room at -24 dB instead of -66 dB
    readonly property real db: peak > 0 ? 60 * Math.log(peak) / Math.LN10 : -120
    // 0..1 along the meter
    readonly property real level: Math.max(0, Math.min(1, (db - floorDb) / -floorDb))
    property real shown: 0          // smoothed: fast attack, slower release
    property real hold: 0
    readonly property bool clipping: db > -1

    implicitWidth: Theme.u * 100
    implicitHeight: Theme.u * 6

    PwNodePeakMonitor {
        id: monitor
        node: root.node
        enabled: root.active && !!root.node
    }
    FrameAnimation {
        // every frame while there is something to animate, idle otherwise; the falls were
        // tuned per 16 ms (`k` keeps their speed at any refresh rate)
        running: root.active && (root.level > 0 || root.shown > 0.001 || root.hold > 0.001)
        onTriggered: {
            const k = Math.min(frameTime, 0.1) / 0.016;
            root.shown = root.level > root.shown ? root.level : Math.max(root.level, root.shown - 0.035 * k);
            if (root.shown >= root.hold) {
                root.hold = root.shown;
                holdTimer.restart();
            } else if (!holdTimer.running) {
                root.hold = Math.max(root.shown, root.hold - 0.02 * k);
            }
        }
    }
    Timer {
        id: holdTimer
        interval: 700
    }

    PxBox {
        anchors.fill: parent
        sunken: true
        color: Theme.sunken
    }
    Row {
        id: row
        anchors.fill: parent
        anchors.margins: Theme.u * 2
        spacing: Math.max(1, Theme.u / 2)
        Repeater {
            model: root.segments
            Rectangle {
                required property int index
                readonly property real at: (index + 1) / root.segments
                readonly property bool lit: root.shown >= at - 0.5 / root.segments
                readonly property bool held: !lit && Math.abs(root.hold - at) < 0.5 / root.segments
                // green body, yellow from -12 dB, red from -3 dB
                readonly property color zone: at > 1 - 3 / -root.floorDb ? Theme.danger : at > 1 - 12 / -root.floorDb ? Theme.accent3 : Theme.ok
                width: (row.width - row.spacing * (root.segments - 1)) / root.segments
                height: row.height
                color: lit ? zone : held ? "transparent" : Qt.alpha(Theme.text, 0.08)
                border.width: held ? Math.max(1, Theme.u / 2) : 0
                border.color: zone
            }
        }
    }
}
