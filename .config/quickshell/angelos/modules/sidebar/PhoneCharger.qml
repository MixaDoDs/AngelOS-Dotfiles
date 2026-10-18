pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The phone's charger (Phone): an extension lead on the bottom of the screen with a string of
// fairy lights plugged into it — the one from behind her monitors — and the charger's cable out
// of it, ending in a plug. Pull the plug by hand into the phone's port (its bottom end): it
// charges (PhoneLine.plug); pull it out the same way. The cable hangs as a rope (a chain of
// points, gravity, the floor) between the lead and the plug; pulled tighter than it reaches, the
// plug pops out of the port. Turned round and round while plugged in, the phone winds the cable
// round itself (Phone.wind): tangled, the cable lies across it in bands, the charm is caught and
// the plug is stuck until the phone is turned back. Charging for hours, the lights blink faster.
//   cost      nothing while the cable lies still (the rope sleeps); a few dozen points a frame
//             while it swings
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property bool tangled: Math.abs(phone.wind) >= Math.PI * 2
    readonly property int turns: Math.min(3, Math.floor(Math.abs(phone.wind) / (Math.PI * 2)))

    // ---- where things are ----
    readonly property real floorY: height - k * 3
    // the lead lies on the floor under the phone's place, kept on the screen
    readonly property real stripW: k * 46
    readonly property real stripH: k * 11
    readonly property real stripX: Math.max(k * 8, Math.min(width - stripW - k * 8, phone.cx + k * 20))
    readonly property real stripY: floorY - stripH
    // the charger's socket (the lead's last one): where the cable starts
    readonly property var socket: [stripX + stripW - k * 8, stripY + k * 2]
    // the cable is long enough to reach the phone at its place with some slack
    readonly property real length: Math.max(k * 220, Math.hypot(phone.cx - socket[0], phone.cy + phone.bh / 2 - socket[1]) * 1.35 + k * 40)
    readonly property int n: 22

    // the plug: in the port, in the hand, or lying where it fell
    property string plugState: PhoneLine.plugged ? "in" : "rest"
    property var hand: [0, 0]
    readonly property var plugAt: plugState === "in" ? phone.portAt : plugState === "drag" ? hand : pts.length ? pts[n - 1] : [socket[0] + k * 30, floorY]

    // ---- the rope ----
    property var pts: []
    property var was: []
    property int still: 0
    function reset() {
        const out = [];
        const end = plugState === "in" ? phone.portAt : [socket[0] + k * 34, floorY - k];
        for (let i = 0; i < n; i++) {
            const t = i / (n - 1);
            // sagging between the ends
            out.push([socket[0] + (end[0] - socket[0]) * t, Math.min(floorY, socket[1] + (end[1] - socket[1]) * t + Math.sin(t * Math.PI) * k * 30)]);
        }
        pts = out;
        was = out.map(p => p.slice());
        wake();
    }
    function wake() {
        still = 0;
        if (visible)
            rope.running = true;
    }
    // the window starts 0×0: laid out again once it has its size (else the plug stays above the
    // screen, issue #95); the lead follows the phone's place, and the rope wakes when shown
    onWidthChanged: reset()
    onHeightChanged: reset()
    onSocketChanged: wake()
    onVisibleChanged: if (visible)
        wake()
    Component.onCompleted: reset()
    Connections {
        target: root.phone
        function onPortAtChanged() {
            if (root.plugState === "in")
                root.wake();
        }
    }
    FrameAnimation {
        id: rope
        onTriggered: {
            const dt = Math.min(frameTime, 0.033), g = root.k * 1400, seg = root.length / (root.n - 1);
            const p = root.pts.map(q => q.slice()), w = root.was;
            if (p.length !== root.n)
                return root.reset();
            let moved = 0;
            // gravity, with a little air
            for (let i = 1; i < root.n; i++) {
                const vx = (p[i][0] - w[i][0]) * 0.97, vy = (p[i][1] - w[i][1]) * 0.97;
                w[i] = p[i].slice();
                p[i][0] += vx;
                p[i][1] += vy + g * dt * dt;
            }
            // the ends: the lead's socket, and the plug (held, in the port) or free
            const pinned = root.plugState !== "rest";
            for (let it = 0; it < 14; it++) {
                p[0] = root.socket.slice();
                if (pinned)
                    p[root.n - 1] = root.plugAt.slice();
                // a piece longer than its share is pulled back; a pinned end doesn't give
                for (let i = 0; i < root.n - 1; i++) {
                    const a = p[i], b = p[i + 1], dx = b[0] - a[0], dy = b[1] - a[1], d = Math.hypot(dx, dy) || 1;
                    if (d <= seg)
                        continue;
                    const fixA = i === 0, fixB = i + 1 === root.n - 1 && pinned;
                    if (fixA && fixB)
                        continue;
                    const c = (d - seg) / d, ka = fixA ? 0 : fixB ? 1 : 0.5, kb = fixB ? 0 : fixA ? 1 : 0.5;
                    a[0] += dx * c * ka;
                    a[1] += dy * c * ka;
                    b[0] -= dx * c * kb;
                    b[1] -= dy * c * kb;
                }
                for (let i = 1; i < root.n; i++) {
                    if (p[i][1] > root.floorY) {
                        p[i][1] = root.floorY;
                        // the floor holds it: it slides a little, then stays
                        w[i][0] = p[i][0] - (p[i][0] - w[i][0]) * 0.6;
                    }
                    p[i][0] = Math.max(0, Math.min(root.width, p[i][0]));
                }
            }
            for (let i = 1; i < root.n; i++)
                moved = Math.max(moved, Math.abs(p[i][0] - w[i][0]) + Math.abs(p[i][1] - w[i][1]));
            root.was = w;
            root.pts = p;
            // pulled tighter than it reaches: the plug pops out (unless the cable is wound round it)
            if (root.plugState === "in" && !root.tangled && Math.hypot(root.phone.portAt[0] - root.socket[0], root.phone.portAt[1] - root.socket[1]) > root.length * 1.02) {
                root.plugState = "rest";
                PhoneLine.plug(false);
            }
            root.still = moved < 0.08 ? root.still + 1 : 0;
            if (root.still > 40 && root.plugState !== "drag")
                running = false;
        }
    }

    // ---- the plug by hand ----
    function grab(x, y) {
        // wound round the phone, the plug won't come out
        if (plugState === "in" && tangled) {
            phone.wiggle();
            return false;
        }
        hand = [x, y];
        if (plugState === "in")
            PhoneLine.plug(false);
        plugState = "drag";
        wake();
        return true;
    }
    function drag(x, y) {
        if (plugState === "drag") {
            hand = [x, y];
            wake();
        }
    }
    function drop() {
        if (plugState !== "drag")
            return;
        const port = phone.portAt;
        if (phone.present && !phone.flying && Math.hypot(hand[0] - port[0], hand[1] - port[1]) < k * 24) {
            plugState = "in";
            PhoneLine.plug(true);
        } else {
            plugState = "rest";
        }
        wake();
    }

    // ---- drawn: the cable in pixels, the lead, the lights, the plug ----
    readonly property color cableInk: phone.hell ? Theme.mix(Theme.hellFace, "#000000", 0.5) : "#2b2733"
    readonly property color cableLit: phone.hell ? Theme.hellAccent : "#5c5470"
    onPtsChanged: frame()
    onTurnsChanged: frame()
    // the canvas covers only the cable (and the phone while it is wound round it)
    function frame() {
        const p = pts, kk = k;
        if (p.length < 2)
            return;
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        const add = (x, y) => {
            x0 = Math.min(x0, x);
            y0 = Math.min(y0, y);
            x1 = Math.max(x1, x);
            y1 = Math.max(y1, y);
        };
        p.forEach(q => add(q[0], q[1]));
        if (turns > 0 && plugState === "in") {
            add(phone.hitBox.x, phone.hitBox.y);
            add(phone.hitBox.x + phone.hitBox.width, phone.hitBox.y + phone.hitBox.height);
        }
        cable.x = Math.floor(x0 / kk) * kk - kk * 4;
        cable.y = Math.floor(y0 / kk) * kk - kk * 4;
        cable.width = Math.ceil((x1 - x0) / kk) * kk + kk * 10;
        cable.height = Math.ceil((y1 - y0) / kk) * kk + kk * 10;
        cable.requestPaint();
    }
    Canvas {
        id: cable
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const c = getContext("2d"), kk = root.k, ox = x, oy = y;
            const p = root.pts.map(q => [q[0] - ox, q[1] - oy]);
            c.reset();
            if (p.length < 2)
                return;
            // the cable: whole pixels along each piece, a lit pixel on top
            const dot = (x, y, col) => {
                c.fillStyle = col;
                c.fillRect(Math.round(x / kk) * kk, Math.round(y / kk) * kk, kk * 2, kk * 2);
            };
            const line = (a, b, col) => {
                const steps = Math.max(1, Math.ceil(Math.hypot(b[0] - a[0], b[1] - a[1]) / kk));
                for (let s = 0; s <= steps; s++)
                    dot(a[0] + (b[0] - a[0]) * s / steps, a[1] + (b[1] - a[1]) * s / steps, col);
            };
            // wound round the phone: the cable's end runs into bands across it
            const hb = root.phone.hitBox, box = {
                "x": hb.x - ox,
                "y": hb.y - oy,
                "width": hb.width,
                "height": hb.height
            }, wound = root.turns > 0 && root.plugState === "in";
            const last = wound ? root.n - 2 : root.n - 1;
            for (let i = 0; i < last; i++)
                line(p[i], p[i + 1], root.cableInk);
            c.fillStyle = root.cableLit;
            for (let i = 0; i < last; i++)
                c.fillRect(Math.round(p[i][0] / kk) * kk, Math.round(p[i][1] / kk) * kk, kk, kk);
            if (wound) {
                for (let t = 0; t < root.turns; t++) {
                    const y0 = box.y + box.height * (0.25 + t * 0.22), y1 = y0 + box.height * 0.16;
                    line([box.x - kk, y0], [box.x + box.width + kk, y1], root.cableInk);
                    line([box.x - kk, y0 - kk], [box.x + box.width + kk, y1 - kk], root.cableLit);
                }
                line(p[root.n - 2], [box.x - kk, box.y + box.height * 0.25], root.cableInk);
            }
        }
    }

    // the plug: a little block along the cable's last piece, the pins to the port
    Item {
        id: plug
        z: 2
        readonly property var tip: root.plugAt
        readonly property var back: root.pts.length > 1 ? root.pts[root.n - 2] : [tip[0] - 1, tip[1]]
        x: tip[0]
        y: tip[1]
        rotation: Math.atan2(tip[1] - back[1], tip[0] - back[0]) * 180 / Math.PI
        Rectangle {
            x: -root.k * 10
            y: -root.k * 3
            width: root.k * 9
            height: root.k * 6
            color: "#e8e4ee"
            border.width: root.k
            border.color: root.cableInk
        }
        Rectangle {
            x: -root.k
            y: -root.k
            width: root.k * 3
            height: root.k * 2
            color: "#b9b2c4"
        }
    }
    // where the plug takes hold (and the window takes clicks while shut: SidebarHost's mask)
    readonly property Item plugBox: plugGrip
    MouseArea {
        id: plugGrip
        x: root.plugAt[0] - root.k * 12
        y: root.plugAt[1] - root.k * 8
        width: root.k * 18
        height: root.k * 16
        z: 3
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: m => {
            const p = mapToItem(root, m.x, m.y);
            if (!root.grab(p.x, p.y))
                m.accepted = false;
        }
        onPositionChanged: m => {
            if (pressed) {
                const p = mapToItem(root, m.x, m.y);
                root.drag(p.x, p.y);
            }
        }
        onReleased: root.drop()
        onCanceled: root.drop()
    }

    // the extension lead: three sockets, a red switch lit; the lights plugged into the first
    readonly property Item stripBox: strip
    Rectangle {
        id: strip
        x: root.stripX
        y: root.stripY
        width: root.stripW
        height: root.stripH
        color: "#efeae2"
        border.width: root.k
        border.color: "#4a4452"
        Row {
            x: root.k * 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.k * 3
            Repeater {
                model: 3
                Rectangle {
                    width: root.k * 6
                    height: root.k * 5
                    color: "#d4cdc3"
                    border.width: Math.max(1, root.k / 2)
                    border.color: "#7a7282"
                    Row {
                        anchors.centerIn: parent
                        spacing: root.k
                        Repeater {
                            model: 2
                            Rectangle {
                                width: root.k
                                height: root.k
                                color: "#3a3440"
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: root.k * 2
            anchors.verticalCenter: parent.verticalCenter
            width: root.k * 4
            height: root.k * 5
            color: root.hot ? "#ff5a3c" : "#d8352a"
            border.width: Math.max(1, root.k / 2)
            border.color: "#5a1a14"
        }
    }

    // the fairy lights: out of the first socket, along the floor; faster after hours of charging
    readonly property bool hot: PhoneLine.plugged && !!PhoneLine.batt && PhoneLine.now - (PhoneLine.batt.plugAt || PhoneLine.now) > 2 * 3600000
    property int blink: 0
    Timer {
        interval: root.hot ? 140 : 700
        running: root.visible && !Motion.still
        repeat: true
        onTriggered: root.blink++
    }
    Repeater {
        model: 14
        Item {
            id: bulb
            required property int index
            readonly property real bx: root.stripX - root.k * (6 + index * 9)
            readonly property real by: root.floorY - root.k * (2 + Math.abs(Math.sin(index * 0.9)) * 4)
            visible: bx > root.k * 2
            x: bx
            y: by
            Rectangle {
                // the wire to the next bulb
                x: 0
                y: root.k
                width: root.k * 9
                height: Math.max(1, root.k / 2)
                color: "#2f4a2a"
            }
            Rectangle {
                x: -root.k
                y: -root.k
                width: root.k * 3
                height: root.k * 4
                color: ["#ff5c7a", "#ffd34d", "#5cd1ff", "#8dff7a"][(bulb.index + root.blink) % 4]
                opacity: (bulb.index + root.blink) % 3 === 0 ? 0.45 : 1
                border.width: Math.max(1, root.k / 2)
                border.color: Qt.alpha("#000000", 0.4)
            }
        }
    }
}
