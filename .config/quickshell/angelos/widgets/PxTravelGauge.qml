pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// One key's travel as a scale, left = up, right = the bottom: how deep it is now, its
// actuation point, the dead zones at both ends and, for a Rapid Trigger key that is in play,
// the stretch it still has to move before it switches (widgets/PxKeyTravel draws the whole
// keyboard; this is the key picked on it, large).
Item {
    id: root

    property Item cap: null             // the key's item of PxKeyTravel: mm, down, turn, armed, rule
    property real travel: 3.3           // mm
    readonly property var rule: cap ? cap.rule : null
    readonly property real mm: cap ? cap.mm : 0
    readonly property bool down: cap ? cap.down : false

    implicitHeight: marks.height + track.height + ticks.height + Theme.u * 4
    readonly property int inner: track.width - track.inset * 2
    function at(v) {
        return Math.round(Math.max(0, Math.min(1, v / root.travel)) * root.inner);
    }

    // above the scale: the actuation point's value, and Rapid Trigger's stretch
    Item {
        id: marks
        width: parent.width
        height: Theme.u * 11
        PxText {
            visible: !!root.rule
            x: Math.max(0, Math.min(parent.width - width, track.inset + root.at(root.rule ? root.rule.actuation : 0) - width / 2))
            kind: "tiny"
            text: root.rule ? root.rule.actuation.toFixed(2) : ""
        }
        Rectangle {
            // from the turning point to where the key switches
            readonly property bool on: !!root.rule && root.rule.trigger !== "normal" && !!root.cap && root.cap.armed
            readonly property real from: !on ? 0 : root.down ? root.cap.turn - root.rule.release : root.cap.turn
            readonly property real to: !on ? 0 : root.down ? root.cap.turn : root.cap.turn + root.rule.press
            visible: on
            x: track.inset + root.at(from)
            y: parent.height - Theme.u * 3
            width: Math.max(Theme.u, root.at(to) - root.at(from))
            height: Theme.u * 2
            color: root.down ? Theme.accent3 : Theme.ok
        }
    }
    PxBox {
        id: track
        y: marks.height
        width: parent.width
        height: Theme.u * 14
        sunken: true
        color: Theme.sunken
        Rectangle {
            width: root.at(root.mm)
            height: parent.height
            color: root.down ? Theme.accent : Theme.accent2
        }
        // the dead zones: travel that counts for nothing, at the top and at the bottom
        Rectangle {
            visible: !!root.rule && root.rule.pressDead > 0
            width: root.at(root.rule ? root.rule.pressDead : 0)
            height: parent.height
            color: Qt.alpha(Theme.text, 0.22)
        }
        Rectangle {
            visible: !!root.rule && root.rule.releaseDead > 0
            x: root.inner - width
            width: root.at(root.rule ? root.rule.releaseDead : 0)
            height: parent.height
            color: Qt.alpha(Theme.text, 0.22)
        }
        Rectangle {
            visible: !!root.rule
            x: root.at(root.rule ? root.rule.actuation : 0)
            width: Theme.u
            height: parent.height
            color: Theme.text
        }
    }
    Item {
        id: ticks
        y: track.y + track.height
        width: parent.width
        height: Theme.u * 10
        Repeater {
            // a tick every half a millimetre, and the bottom
            model: {
                const out = [];
                for (let v = 0; v < root.travel - 0.25; v += 0.5)
                    out.push(v);
                out.push(root.travel);
                return out;
            }
            Item {
                id: tick
                required property real modelData
                x: track.inset + root.at(modelData)
                Rectangle {
                    width: Math.max(1, Theme.u / 2)
                    height: Theme.u * 2
                    color: Theme.textDim
                }
                PxText {
                    y: Theme.u * 3
                    x: tick.modelData === 0 ? 0 : tick.modelData >= root.travel ? -width : -width / 2
                    kind: "tiny"
                    dim: true
                    text: tick.modelData === Math.round(tick.modelData) ? String(tick.modelData) : tick.modelData.toFixed(1)
                }
            }
        }
    }
}
