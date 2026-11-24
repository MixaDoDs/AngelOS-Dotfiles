import QtQuick

// serp-skin: a cloud of the weather scene: a rounded base and two puffs, drawn whole and then
// faded as one (a layer, so the overlaps don't show). `drift` slides it softly while `live`.
Item {
    id: cl
    property color tint: "white"
    property real drift: 12               // px either way
    property int period: 9000
    property bool live: true
    property real baseX: 0
    width: 100
    height: width * 0.58
    layer.enabled: opacity < 1
    layer.smooth: true

    property real d: 0
    x: baseX + (d - 0.5) * 2 * drift
    SequentialAnimation on d {
        running: cl.live
        loops: Animation.Infinite
        NumberAnimation {
            to: 1
            duration: cl.period / 2
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: cl.period / 2
            easing.type: Easing.InOutSine
        }
    }

    Rectangle {
        x: 0
        y: cl.height * 0.46
        width: cl.width
        height: cl.height * 0.54
        radius: height / 2
        color: cl.tint
    }
    Rectangle {
        x: cl.width * 0.14
        y: cl.height * 0.22
        width: cl.width * 0.42
        height: width
        radius: width / 2
        color: cl.tint
    }
    Rectangle {
        x: cl.width * 0.36
        y: 0
        width: cl.width * 0.5
        height: width
        radius: width / 2
        color: cl.tint
    }
}
