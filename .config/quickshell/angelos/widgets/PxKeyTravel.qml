pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// A Hall-effect keyboard, live: the layout of a device description (data/devices), and in
// every key how far down it is right now — the cap fills from the top as the key goes down,
// the line across it is its actuation point, and the fill changes colour once the key counts
// as pressed by its own settings (services/Devices; Settings → Devices → Device driver).
//
// Travel comes as a plain array (`source`, mm by matrix number) changed in place by the
// service; this item reads it once a frame of the monitor while `moving`, eases every key to
// its value, and sleeps when all of them stand still.
Item {
    id: root

    property var keys: []               // [{m, x, y, w, h, label}] in key widths
    property var settings: ({})         // "m" -> {actuation, trigger, press, release, …} in mm
    property real travel: 3.3           // the switch's whole travel, mm
    property var source: []             // m -> mm, changed in place
    property bool moving: false         // there is news in `source`
    property bool active: visible
    property var selection: []          // the keys picked (matrix numbers)
    property var paired: ({})           // m -> its Snap Tap partner's number
    property var legends: ({})          // "m" -> what the cap says instead of its layout label
    property var subs: ({})             // "m" -> a small second line (a value, a kind)
    property var marked: ({})           // "m" -> true: changed from the factory (a dot in the corner)
    property var dimmed: ({})           // "m" -> true: the legend is not the key's own (an Fn layer's empty key)
    property var lit: ({})              // "m" -> true: held down right now, by the system's own key events
    property bool showTravel: true      // the fill of how deep each key is, with the actuation marks
    property bool showDepth: true       // without showTravel: the fill alone, quieter (the editing tabs)
    property int lastKey: -1            // the key that went down last
    property int downCount: 0           // keys held past their actuation point right now
    signal picked(int m, int modifiers)

    readonly property real cols: keys.reduce((a, k) => Math.max(a, k.x + (k.w || 1)), 1)
    readonly property real rows: keys.reduce((a, k) => Math.max(a, k.y + (k.h || 1)), 1)
    // a key width in whole art pixels, so every edge sits on the grid
    readonly property int cell: Math.max(Theme.u * 6, Math.floor(width / cols / Theme.u) * Theme.u)
    readonly property int gap: Theme.u
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: Theme.p5For(root.parent)
    implicitHeight: rows * cell
    implicitWidth: cols * cell

    // the keys' items by matrix number, and where each one is drawn now (mm)
    property var caps: ({})
    property int capsVersion: 0         // caps is filled in place: this tells bindings it changed
    property var shown: ({})
    property bool settled: true

    // Is the key pressed, as its settings would have it. A plain key: past its actuation
    // point. Rapid Trigger: the first press is at the actuation point too; from then on the
    // key lets go as soon as it comes up by "release" from its deepest point and presses
    // again as soon as it goes down by "press" from its highest — until it leaves the range
    // (above the actuation point; continuous: only all the way up). Worked out here from the
    // settings read from the keyboard: the keyboard does not report its own decision.
    function pressedNow(cap, mm) {
        const s = cap.rule;
        if (!s)
            return mm > 0.05;
        if (s.trigger === "normal")
            return mm >= s.actuation;
        const top = s.trigger === "continuous" ? Math.max(0.05, s.pressDead) : s.actuation;
        if (mm < top) {
            cap.armed = false;
            return false;
        }
        if (!cap.armed) {
            if (mm < s.actuation)
                return false;
            cap.armed = true;
            cap.turn = mm;
            return true;
        }
        let now;
        if (cap.down) {
            cap.turn = Math.max(cap.turn, mm);
            now = mm > cap.turn - s.release;
        } else {
            cap.turn = Math.min(cap.turn, mm);
            now = mm >= cap.turn + s.press;
        }
        if (now !== cap.down)
            cap.turn = mm;
        return now;
    }

    FrameAnimation {
        running: root.active && (root.moving || !root.settled)
        onTriggered: {
            const src = root.source, shown = root.shown, caps = root.caps;
            // an eighth of a frame's worth of lag at 60 Hz: the steps of the report vanish, the
            // finger does not feel followed late
            const a = 1 - Math.exp(-Math.min(frameTime, 0.05) / 0.006);
            let busy = false, down = 0;
            for (const m in caps) {
                const cap = caps[m];
                const t = src[m] || 0;
                let s = shown[m] || 0;
                if (t !== s) {
                    s += (t - s) * a;
                    if (Math.abs(t - s) < 0.006)
                        s = t;
                    else
                        busy = true;
                    shown[m] = s;
                    cap.mm = s;
                    const was = cap.down;
                    cap.down = root.pressedNow(cap, s);
                    if (cap.down && !was)
                        root.lastKey = cap.m;
                }
                if (cap.down)
                    down++;
            }
            root.downCount = down;
            root.settled = !busy;
        }
    }
    // the device went away, another was picked: every key back up
    onSourceChanged: {
        for (const m in caps) {
            caps[m].mm = 0;
            caps[m].down = false;
            caps[m].turn = 0;
            caps[m].armed = false;
        }
        shown = ({});
        downCount = 0;
        settled = false;
    }

    Repeater {
        model: root.keys
        Item {
            id: cap
            required property var modelData
            readonly property int m: modelData.m
            readonly property var rule: root.settings[String(m)] || null
            property real mm: 0
            property bool down: false
            property real turn: 0           // Rapid Trigger's turning point (pressedNow)
            property bool armed: false      // …and whether the key is inside its range
            x: Math.round(modelData.x * root.cell)
            y: Math.round(modelData.y * root.cell)
            width: Math.round((modelData.w || 1) * root.cell) - root.gap
            height: Math.round((modelData.h || 1) * root.cell) - root.gap
            Component.onCompleted: {
                root.caps[m] = cap;
                root.capsVersion++;
            }
            Component.onDestruction: {
                if (root.caps[m] === cap) {
                    delete root.caps[m];
                    root.capsVersion++;
                }
            }

            readonly property int well: box.height - box.inset * 2
            // the fill's height in whole screen pixels
            readonly property int fillH: Math.round(Math.min(1, mm / root.travel) * well)
            readonly property int pointY: Math.round(Math.min(1, (rule ? rule.actuation : 0) / root.travel) * well)
            readonly property bool chosen: root.selection.includes(m)
            readonly property bool inPair: root.paired[m] !== undefined
            readonly property bool held: !!root.lit[String(m)]
            readonly property string legendText: root.legends[String(m)] !== undefined ? root.legends[String(m)] : (modelData.label || "")
            readonly property string subText: root.subs[String(m)] || ""

            PxBox {
                id: box
                anchors.fill: parent
                color: cap.held ? Theme.mix(Theme.tone("face", root.p5), Theme.tone("ok", root.p5), 0.55) : cap.chosen ? Theme.mix(Theme.tone("face", root.p5), Theme.accent, 0.22) : Theme.tone("face", root.p5)
                edgeColor: cap.held ? Theme.tone("ok", root.p5) : cap.chosen ? Theme.accent : Theme.tone("edge", root.p5)
                // how deep the key is: the cap fills from the top down, as the key goes
                Rectangle {
                    visible: root.showTravel || root.showDepth
                    width: parent.width
                    height: cap.fillH
                    color: !root.showTravel ? Theme.mix(Theme.tone("face", root.p5), Theme.accent, 0.3) : cap.down ? Theme.accent : Theme.mix(Theme.tone("face", root.p5), Theme.accent, 0.42)
                }
                // the fill's lower edge, a row of art pixels brighter: the surface that moves
                Rectangle {
                    visible: (root.showTravel || root.showDepth) && cap.fillH > Theme.u
                    y: cap.fillH - Theme.u
                    width: parent.width
                    height: Theme.u
                    color: cap.down ? Theme.tone("hi", root.p5) : Theme.accent
                }
                // the actuation point: a notch at each side
                Rectangle {
                    visible: root.showTravel && !!cap.rule
                    y: cap.pointY
                    width: Theme.u * 3
                    height: Theme.u
                    color: Theme.tone("text", root.p5)
                }
                Rectangle {
                    visible: root.showTravel && !!cap.rule
                    x: parent.width - width
                    y: cap.pointY
                    width: Theme.u * 3
                    height: Theme.u
                    color: Theme.tone("text", root.p5)
                }
                // a key of a Snap Tap pair: a bar along its top
                Rectangle {
                    visible: cap.inPair
                    width: parent.width
                    height: Theme.u
                    color: Theme.accent3
                }
                // a key that is not plain: Rapid Trigger (continuous: the other colour)
                Rectangle {
                    visible: root.showTravel && !!cap.rule && cap.rule.trigger !== "normal"
                    x: parent.width - width - Theme.u
                    y: parent.height - height - Theme.u
                    width: Theme.u * 2
                    height: Theme.u * 2
                    color: cap.rule && cap.rule.trigger === "continuous" ? Theme.accent3 : Theme.tone("ok", root.p5)
                }
                // changed from the factory: a dot in the top left corner
                Rectangle {
                    visible: !!root.marked[String(cap.m)]
                    x: Theme.u
                    y: Theme.u * 2
                    width: Theme.u * 2
                    height: Theme.u * 2
                    color: Theme.accent2
                }
                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.u * 2
                    spacing: 0
                    PxText {
                        id: legend
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        kind: "tiny"
                        text: cap.legendText
                        opacity: root.dimmed[String(cap.m)] ? 0.45 : 1
                        // under a pressed key's fill the legend takes the cap's colour to stay read
                        color: root.showTravel && cap.down && cap.fillH > cap.well / 2 ? Theme.tone("face", root.p5) : Theme.tone("text", root.p5)
                    }
                    PxText {
                        visible: cap.subText !== "" && cap.height > Theme.u * 14
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        kind: "tiny"
                        dim: true
                        text: cap.subText
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => root.picked(cap.m, mouse.modifiers)
            }
        }
    }
}
