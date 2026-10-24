import QtQuick
import qs.config

// A value on a track (PxSlider): moved while dragging, released when let go.
CatEntry {
    kind: "slider"
    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    property bool live: true
    property string suffix: ""
    property int decimals: 0
    property bool showValue: true
    property real valueScale: 1
    property color fill: Theme.accent
    signal moved(real value)
    signal released(real value)
}
