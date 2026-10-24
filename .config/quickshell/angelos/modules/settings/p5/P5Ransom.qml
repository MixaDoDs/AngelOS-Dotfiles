import QtQuick
import qs.config

// A title cut out of a magazine, P5's way: every letter on a plate of its own — its own colours,
// font size and lean — and now and then one of them hops.
Row {
    id: root

    property string text: ""
    property var pal: ({})
    property bool small: false
    // a big window: the letters a size up
    property bool large: false
    property bool still: false
    spacing: Theme.u / 2

    readonly property var pairs: [["paper", "black"], ["black", "paper"], ["accent", "black"], ["paper", "accent"], ["black", "accent2"]]
    Repeater {
        id: letters
        model: root.text.split("")
        Item {
            id: l
            required property string modelData
            required property int index
            readonly property bool gap: modelData === " "
            readonly property var pair: root.pairs[(index * 7 + root.text.length) % root.pairs.length]
            property real hop: 0
            width: gap ? Theme.u * 4 : g.implicitWidth + Theme.u * 4
            height: g.implicitHeight + Theme.u * 2
            y: ((index * 5) % 7 - 3) * Theme.u / 2 - hop * Theme.u * 3
            anchors.bottom: undefined
            P5Plate {
                visible: !l.gap
                anchors.fill: parent
                tilt: ((l.index * 13) % 11 - 5) + l.hop * -8
                color: root.pal[l.pair[0]] || "white"
                pad: Theme.u * 6
            }
            P5Glyphs {
                id: g
                visible: !l.gap
                x: Theme.u * 2
                y: Theme.u
                text: l.modelData
                big: (root.small ? 1 : root.large ? 3 : 2) + ((l.index * 3) % 4 === 3 ? 1 : 0)
                tilt: ((l.index * 13) % 11 - 5) + l.hop * -8
                color: root.pal[l.pair[1]] || "black"
                family: Theme.p5Ransom[(l.index * 7 + 3) % Theme.p5Ransom.length]
            }
            SequentialAnimation {
                id: hopRun
                PropertyAction {
                    target: l
                    property: "hop"
                    value: 1
                }
                PauseAnimation {
                    duration: 175
                }
                PropertyAction {
                    target: l
                    property: "hop"
                    value: 0
                }
            }
            function jump() {
                hopRun.restart();
            }
        }
    }
    Timer {
        running: !root.still && root.visible
        repeat: true
        interval: 500 + Math.random() * 400
        onTriggered: {
            const it = letters.itemAt(Math.floor(Math.random() * letters.count));
            if (it && !it.gap)
                it.jump();
            interval = 500 + Math.random() * 400;
        }
    }
}
