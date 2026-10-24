import QtQuick

// A number stepped by − and + (PxSpin).
CatEntry {
    kind: "spin"
    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string suffix: ""
    signal moved(real value)
}
