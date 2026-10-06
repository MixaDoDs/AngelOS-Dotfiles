import QtQuick
import "AngelRig.js" as Rig

// The angel asleep on the second camera: angelOS's own picture-rig (modules/y2k/sprites/angel,
// copied in by `angelos sddm build` with its rig.json as AngelRig.js). Eyes shut, the wings
// rising and falling with her breath, a z drifting up; now and then she peeks.
Item {
    id: root

    property int px: 4                       // screen px of one sprite pixel
    property real time: 0                    // seconds, from the theme
    property color zColor: "#ffffff"
    property color zEdge: "#140c20"
    property string font: ""
    readonly property var rig: Rig.rig
    readonly property bool ready: !!rig && !!rig.size

    // 4 ticks a second; a breath is one sweep of the wings and back
    readonly property int tick: Math.floor(time * 4)
    // she peeks for ~1.5 s once every 11 s
    readonly property bool peek: (time % 11) > 9.5
    readonly property int breath: Math.floor(time / 2.4) % 2

    implicitWidth: ready ? rig.size[0] * px : 0
    implicitHeight: ready ? rig.size[1] * px : 0

    component Part: Item {
        id: part
        required property var modelData
        readonly property var p: modelData
        readonly property int period: Math.max(1, (p.frames - 1) * 2)
        // back and forth, slowly: 0 1 2 3 4 3 2 1 …
        readonly property int frame: {
            const i = Math.floor(root.tick / 2) % period;
            return i < p.frames ? i : period - i;
        }
        x: p.x * root.px
        y: p.y * root.px
        width: p.w * root.px
        height: p.h * root.px
        clip: true
        Image {
            x: -part.frame * part.width
            width: part.width * part.p.frames
            height: part.height
            source: "angel/" + part.p.name + ".png"
            smooth: false
        }
    }
    function parts(under) {
        return !ready ? [] : Object.keys(rig.parts).filter(k => !!rig.parts[k].under === under).map(k => Object.assign({
                "name": k
            }, rig.parts[k]));
    }

    Item {
        id: figure
        width: root.implicitWidth
        height: root.implicitHeight
        // breathing: one sprite pixel up and down
        y: root.breath * root.px
        Repeater {
            model: root.parts(true)
            Part {}
        }
        Item {
            visible: root.ready
            x: root.ready ? root.rig.body.x * root.px : 0
            y: root.ready ? root.rig.body.y * root.px : 0
            width: root.ready ? root.rig.body.w * root.px : 0
            height: root.ready ? root.rig.body.h * root.px : 0
            Image {
                anchors.fill: parent
                source: "angel/body.png"
                smooth: false
            }
            Image {
                anchors.fill: parent
                visible: !root.peek
                source: "angel/eyes.png"
                smooth: false
            }
        }
        Repeater {
            model: root.parts(false)
            Part {}
        }
    }

    // z z z, rising from beside her head while she sleeps
    Repeater {
        model: 3
        Text {
            required property int index
            readonly property real phase: ((root.time / 3.6) + index / 3) % 1
            visible: !root.peek
            x: root.width * 0.62 + Math.round(phase * root.px * 14)
            y: root.height * 0.18 - Math.round(phase * root.px * 26)
            opacity: phase < 0.15 ? phase / 0.15 : 1 - (phase - 0.15) / 0.85
            text: "z"
            color: root.zColor
            style: Text.Outline
            styleColor: root.zEdge
            font.family: root.font
            font.pixelSize: root.px * (5 + index * 2)
            renderType: Text.NativeRendering
        }
    }
}
