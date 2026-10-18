pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "Phone3D.js" as P3
import "../../services/PhoneLore.js" as PL

// The sidebar's "phone" look (Config.sidebar.look, the default): a pixel flip phone of the
// 2000s, a thing of its own on the desk (services/PhoneLine: her calls, messages, the codes).
//   coming    the tab sends it out of its edge, shut and spinning; it settles and opens. The
//             tab again takes it away. Shut, it stays by the edge (Sidebar.shown): its little
//             outside screen shows the time, missed calls and messages, and who is ringing.
//   the lid   pull it by its edge (the earpiece, the top, its back while shut): it follows the
//             pointer in 3D and snaps open or shut when let go — a flick slams it; a click on
//             the shut phone opens it. Opening it while it rings answers, shutting it hangs up.
//   keys      PhoneKeys → key(): the green key, ◀ OK ▶, the red key, 1…9 * 0 #; the keyboard
//             too (digits, arrows, Enter, Esc, Backspace; letters while writing a message). The
//             red key at home shuts the lid, Esc on the shut phone takes it away.
//   screen    PhoneScreen: a phone's programs; on its side (Sidebar.turned) PhoneSide: sound,
//             wallpapers, theme
//   toys      it shakes and buzzes while it rings; a charm (a tiny her) swings on its strap as
//             it moves; the antenna pulls out (the screen's bars grow)
//   in hand   drag it by its body and it turns like a trackball about its middle, a fling keeps
//             it spinning (and a spin or a shake of the shut phone asks the magic ball); a double
//             click faces it to you again; it opens in whatever pose it is in. Held still it is
//             picked up; thrown, it tumbles as a solid box, knocks on the screen's edges, lies
//             down on the bottom (a hard landing cracks it: PhoneLine.drop), then floats back
//   tuning    the shell, rhinestones, a sticker, the charm, the screen's wallpaper
//             (PhoneLine.wearing, Config.phone.look); the torch lights the whole screen white
//   3D        every face (lid and base, front, back and edges, the hinge, the antenna) is a flat
//             Item put in place by one Matrix4x4 (Phone3D.js): no Qt Quick 3D. Faces turned away
//             are hidden, the rest drawn back to front; the edges are shaded by a light from the
//             top left. The phone leans a few degrees after the pointer (not with calm motion).
//   models    the tuning's model (PhoneLine.model): the flip; the 3310 brick (one solid box,
//             the screen above the keys, a green monochrome LCD; unbreakable: a hard landing
//             cracks the computer's screen instead, for a minute); the taco gamer (a wide box,
//             the screen between the pad and the keys; her calls are answered by turning it
//             edge-on to the ear). The bars have no lid: a click wakes the keys
//   battery   PhoneLine.battery: off (dead), the screen is dark and a key shows the empty cell;
//             the charger (PhoneCharger: the extension lead, the cable, the plug) goes into the
//             port at its bottom end. Turned round and round while plugged in, it winds the
//             cable round itself (wind): tangled, the lid won't open and it can't be picked up
//             until it is turned back
//   cost      nothing while away (the window and all of this are gone); shut on the desk, its
//             window takes clicks only on itself and nothing moves; while it moves, a dozen
//             matrices a frame
Item {
    id: root

    // where it rests (the centre of the open phone) and the edge it comes out of
    property real restX: width / 2
    property real restY: height / 2
    property string edge: "right"
    // kept on the screen whole, upright or on its side
    readonly property real halfW: bar ? w / 2 + k * 6 : (w / 2) * (1 - turn) + ((lh + bh) / 2) * turn + k * 6
    readonly property real halfH: bar ? bh / 2 + k * 6 : ((lh + bh) / 2) * (1 - turn) + (w / 2) * turn + k * 6
    readonly property real cx: Math.max(halfW, Math.min(width - halfW, restX))
    readonly property real cy: Math.max(halfH, Math.min(height - halfH, restY))
    signal gone()                        // shut and away: the window may go

    readonly property int k: Theme.u
    readonly property string model: PhoneLine.model
    readonly property bool bar: model !== "flip"
    readonly property bool taco: model === "ngage"
    // 0 upright … 1 on its side: the lid's screen grows into a wide one as it turns (the flip only)
    property real turn: Sidebar.turned && !bar ? 1 : 0
    Behavior on turn {
        NumberAnimation {
            duration: Motion.ms(560)
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }
    // the bars are one box: the base's faces alone (bh its height, no hinge)
    readonly property real w: taco ? k * 212 : bar ? k * 106 : k * (104 + 64 * turn)  // width (both halves)
    readonly property real lh: k * (122 + 96 * turn)       // the lid's height
    readonly property real bh: taco ? k * 112 : bar ? k * 230 : k * (124 + 8 * turn)  // the base's height
    readonly property real tl: k * 7                       // the lid's thickness
    readonly property real tb: taco ? k * 20 : bar ? k * 18 : k * 10  // the base's
    readonly property real g: bar ? 0 : k * 5              // half the hinge
    // the size of the screen (on the lid's front; on the bars' front), in its own pixels
    readonly property real screenW: bar ? k * 90 : w - k * 14
    readonly property real screenH: bar ? k * 91 : lh - g - k * 26

    // ---- on the desk, and the lid ----
    property real slide: 1               // 1 out past the edge … 0 in place
    property real lid: 180               // degrees: 180 shut … 0 open (a little past it, springing back)
    property real power: 0               // the screen: 0 dark … 1 lit
    readonly property bool present: Sidebar.shown
    readonly property bool lidUp: Sidebar.open
    property bool dragging: false
    onPresentChanged: present ? comeIn() : goAway()
    // a new model: the flip's lid where it should be (the bars have none)
    onModelChanged: {
        faceUp();
        if (!bar && present)
            swingTo(lidUp ? 0 : 180);
    }
    onLidUpChanged: {
        if (!lidUp)
            torch = false;
        if (bar)
            return;
        if (!dragging && present && !arriving.running)
            swingTo(lidUp ? 0 : 180);
        // a flip phone: open it to answer, shut it to hang up
        if (lidUp && PhoneLine.ringing && !PhoneLine.call.outgoing)
            PhoneLine.answer();
        else if (!lidUp && PhoneLine.talking)
            PhoneLine.hangUp();
    }
    Component.onCompleted: {
        PhoneLine.ensure();
        if (present)
            comeIn();
    }
    function comeIn() {
        leaving.stop();
        arriving.restart();
    }
    function goAway() {
        arriving.stop();
        leaving.restart();
    }
    SequentialAnimation {
        id: arriving
        NumberAnimation {
            target: root
            property: "slide"
            to: 0
            duration: Motion.ms(420)
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: if (root.lidUp && !root.bar)
                root.swingTo(0)
        }
    }
    SequentialAnimation {
        id: leaving
        ScriptAction {
            script: if (root.lid < 179 && !root.bar)
                root.swingTo(180)
        }
        PauseAnimation {
            duration: Motion.ms(360)
        }
        NumberAnimation {
            target: root
            property: "slide"
            to: 1
            duration: Motion.ms(300)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                Sidebar.turned = false;
                root.gone();
            }
        }
    }
    // the lid to an angle: opening springs a little past flat, shutting lands with a bounce
    NumberAnimation {
        id: swing
        target: root
        property: "lid"
        onFinished: PhoneLine.play(to > 90 ? "clack" : "click", 0.7)
    }
    function swingTo(a) {
        swing.stop();
        const far = Math.abs(lid - a) / 180;
        swing.to = a;
        swing.duration = Motion.ms(a < 90 ? 260 + far * 380 : 160 + far * 260);
        swing.easing.type = a < 90 ? Easing.OutBack : Easing.OutBounce;
        swing.easing.overshoot = 1.4;
        swing.easing.amplitude = 0.4;
        swing.start();
    }
    readonly property bool screenOn: present && !PhoneLine.dead && (bar || lid < 45)
    onScreenOnChanged: {
        lightUp.to = screenOn ? 1 : 0;
        lightUp.duration = Motion.ms(screenOn ? 260 : 110);
        lightUp.restart();
    }
    NumberAnimation {
        id: lightUp
        target: root
        property: "power"
    }

    // ---- pulling the lid by hand ----
    // where the hinge and the open lid's top are on the screen (rebuild): the pointer's place
    // along that line is the lid's cosine
    property var hingeAt: [0, 0]
    property var lidTopAt: [0, -1]
    property var pressAt: [0, 0]
    property double lastAt: 0
    property real lastLid: 0
    property real lidSpeed: 0             // degrees a millisecond, + shutting
    function angleAt(px, py) {
        const dx = lidTopAt[0] - hingeAt[0], dy = lidTopAt[1] - hingeAt[1];
        const t = ((px - hingeAt[0]) * dx + (py - hingeAt[1]) * dy) / Math.max(1, dx * dx + dy * dy);
        return Math.acos(Math.max(-1, Math.min(1, t))) * 180 / Math.PI;
    }
    function grabLid(item, mx, my) {
        const p = item.mapToItem(root, mx, my);
        pressAt = [p.x, p.y];
        lastAt = Date.now();
        lastLid = lid;
        lidSpeed = 0;
    }
    function pullLid(item, mx, my) {
        const p = item.mapToItem(root, mx, my);
        if (!dragging) {
            if (Math.hypot(p.x - pressAt[0], p.y - pressAt[1]) < k * 3)
                return;
            if (tangled && !lidUp) {
                wiggle();
                return;
            }
            dragging = true;
            swing.stop();
        }
        const a = Math.max(-8, Math.min(180, angleAt(p.x, p.y)));
        const t = Date.now();
        if (t > lastAt) {
            lidSpeed = lidSpeed * 0.5 + (a - lastLid) / (t - lastAt) * 0.5;
            lastAt = t;
            lastLid = a;
        }
        lid = a;
    }
    function dropLid() {
        if (!dragging) {
            // a click on the shut phone opens it (not wound in the cable)
            if (!lidUp && tangled)
                wiggle();
            else if (!lidUp)
                Sidebar.open = true;
            return;
        }
        dragging = false;
        const open = Math.abs(lidSpeed) > 0.35 ? lidSpeed < 0 : lid < 90;
        if (open === lidUp)
            swingTo(open ? 0 : 180);
        Sidebar.open = open;
    }
    // a press held on a face keeps that face in (Face.pressing)
    function holdFace(item, on) {
        let p = item;
        while (p && p.pressing === undefined)
            p = p.parent;
        if (p)
            p.pressing = on;
    }
    // the parts of the lid that take hold
    component Grip: MouseArea {
        id: grip
        onPressedChanged: root.holdFace(grip, pressed)
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: m => root.grabLid(grip, m.x, m.y)
        onPositionChanged: m => {
            if (pressed)
                root.pullLid(grip, m.x, m.y);
        }
        onReleased: root.dropLid()
        onCanceled: root.dropLid()
    }

    // ---- the motor: it shakes while it rings (and once for a message) ----
    readonly property bool ringingHere: present && PhoneLine.ringing && !PhoneLine.call.outgoing
    property real buzzX: 0
    property real buzzTurn: 0
    property int buzzLeft: 0              // ticks of a short buzz left (a message)
    property int buzzTick: 0
    Timer {
        interval: 30
        running: root.ringingHere || root.buzzLeft > 0
        repeat: true
        onTriggered: {
            root.buzzTick++;
            // 0.75 s on, 0.5 s off while it rings
            const on = root.buzzLeft > 0 || root.buzzTick % 42 < 25;
            if (root.buzzLeft > 0)
                root.buzzLeft--;
            if (on && root.buzzTick % 42 === 1 || root.buzzLeft === 15)
                PhoneLine.play("buzz", 0.5);
            root.buzzX = on && !Motion.still ? (Math.random() - 0.5) * root.k * 1.5 : 0;
            root.buzzTurn = on && !Motion.still ? (Math.random() - 0.5) * 1.5 : 0;
        }
        onRunningChanged: if (!running) {
            root.buzzX = 0;
            root.buzzTurn = 0;
            root.buzzTick = 0;
        }
    }
    Connections {
        target: PhoneLine
        function onTexted() {
            if (root.present)
                root.buzzLeft = 16;
        }
    }

    // ---- the antenna: pulled out, the bars grow ----
    property real antenna: 0              // 0 in … 1 all the way out
    readonly property int bars: 2 + Math.round(antenna * 2)
    property var antennaFoot: [0, 0]
    property var antennaTip: [0, -1]
    function pullAntenna(item, mx, my) {
        const p = item.mapToItem(root, mx, my);
        const dx = antennaTip[0] - antennaFoot[0], dy = antennaTip[1] - antennaFoot[1];
        const t = ((p.x - antennaFoot[0]) * dx + (p.y - antennaFoot[1]) * dy) / Math.max(1, dx * dx + dy * dy);
        const a = Math.max(0, Math.min(1, (t * 34 - 8) / 26));
        if ((a === 0 || a === 1) && a !== antenna)
            PhoneLine.play("click", 0.4);
        antenna = a;
    }

    // ---- the lean after the pointer ----
    property real leanX: 0
    property real leanY: 0
    property real tiltX: 0
    property real tiltY: 0
    function lean(px, py) {
        if (Motion.calm || !present || dragging) {
            leanX = 0;
            leanY = 0;
            return;
        }
        // only while the pointer is over it, and only a little: it looks up at the hand
        const b = hitBox, over = px >= b.x && px <= b.x + b.width && py >= b.y && py <= b.y + b.height;
        hovering = over;
        if (!over || turnFrom) {
            leanX = 0;
            leanY = 0;
            return;
        }
        const cl = v => Math.max(-1, Math.min(1, v));
        leanY = -cl((px - (b.x + b.width / 2)) / Math.max(1, b.width / 2)) * 3;
        leanX = -cl((py - (b.y + b.height / 2)) / Math.max(1, b.height / 2)) * 2.5;
    }
    FrameAnimation {
        running: root.visible && root.present && (Math.abs(root.tiltX - root.leanX) > 0.01 || Math.abs(root.tiltY - root.leanY) > 0.01)
        onTriggered: {
            const a = Math.min(1, frameTime * 5);
            root.tiltX += (root.leanX - root.tiltX) * a;
            root.tiltY += (root.leanY - root.tiltY) * a;
            if (Math.abs(root.tiltX - root.leanX) < 0.02)
                root.tiltX = root.leanX;
            if (Math.abs(root.tiltY - root.leanY) < 0.02)
                root.tiltY = root.leanY;
        }
    }

    // ---- in hand ----
    // Open, it is for using: a drag on its body only tips it a little (25° at most) and it
    // springs back to face you. Shut, it is a toy: a drag turns it like a trackball — the side
    // under the pointer goes with it — about its own middle, calmly under a slow hand (a quarter
    // of a degree a pixel), up to twice that under a quick one; a fling spins it on as fast as it
    // went and slows down; a hard spin or a shake asks the magic ball.
    // Press and hold still for half a second (at the start or in the middle of a turn) and it is
    // picked up: it comes closer and follows the pointer. Let go slowly and it floats home; let go
    // with a swing and it flies as a solid box: it tumbles, its corners knock on the screen's
    // edges, a knock turns it, and it comes to rest lying on the bottom — a hard landing cracks it.
    property var rot: [1, 0, 0, 0]        // its turn in the hand (P3 quaternion), about `pivot`
    property var spin: [0, 0, 0]          // radians a second about the world's axes (a fling)
    property var around: P3.turnZ(0)       // the turn around it (on its side, the lean): world axes → its own
    property var turnFrom: null           // the drag: {x, y, ax, ay (turned to), x0, y0, hx, hy (held at), trail, run, from}
    property bool turning: false
    property bool held: false             // picked up by a long press
    property int shakes: 0                // the drag's turns back (a shake asks the ball)
    property string answer: ""            // the magic ball on the outside screen
    readonly property real turnRate: 0.25 // degrees a pixel (a slow hand; turnGain)
    function clamp(v, a, b) {
        return Math.max(a, Math.min(b, v));
    }
    // a turn about an axis of the world (the screen's x right, y down, z to you)
    function turnBy(axis, rad) {
        rot = P3.qnorm(P3.qmul(P3.quat(P3.undir(around, axis), rad), rot));
        if (PhoneLine.plugged && rad > 0) {
            const sgn = Math.abs(axis[1]) >= Math.abs(axis[0]) ? Math.sign(axis[1]) : Math.sign(axis[0]);
            const was = Math.abs(wind) >= Math.PI * 2;
            wind += rad * sgn * (antenna > 0.3 ? 1.5 : 1);
            // turned back past half a turn: free again
            if (was && Math.abs(wind) < Math.PI)
                wind = 0;
        }
    }
    // the charger's cable wound round it (radians, either way); unplugged, it slides off
    property real wind: 0
    readonly property bool tangled: Math.abs(wind) >= Math.PI * 2
    onTangledChanged: if (tangled)
        PhoneLine.play("clack", 0.4)
    Connections {
        target: PhoneLine
        function onPluggedChanged() {
            if (!PhoneLine.plugged)
                root.wind = 0;
        }
    }
    // a little shake: it can't (tangled)
    property real wiggleX: 0
    function wiggle() {
        wiggleAnim.restart();
        PhoneLine.play("busy", 0.25);
    }
    SequentialAnimation {
        id: wiggleAnim
        NumberAnimation {
            target: root
            property: "wiggleX"
            to: root.k * 3
            duration: 40
        }
        NumberAnimation {
            target: root
            property: "wiggleX"
            to: -root.k * 3
            duration: 80
        }
        NumberAnimation {
            target: root
            property: "wiggleX"
            to: 0
            duration: 60
        }
    }
    function turnStart(item, mx, my) {
        const p = item.mapToItem(root, mx, my), t = Date.now();
        spinOn.running = false;
        faceAnim.stop();
        turnFrom = {
            "x": p.x,
            "y": p.y,
            "ax": p.x,
            "ay": p.y,
            "x0": p.x,
            "y0": p.y,
            "hx": p.x,
            "hy": p.y,
            "trail": [[t, p.x, p.y]],
            "run": 0,
            "from": P3.qangle(rot)
        };
        turning = false;
        shakes = 0;
        // caught on the fly, or on its way home: straight back in the hand
        if (flight.running || homeAnim.running) {
            pickUp();
        } else if (!Motion.still) {
            holdWait.restart();
        }
        turnTick.running = true;
    }
    Timer {
        id: holdWait
        interval: 450
        onTriggered: if (root.turnFrom && !root.held) {
            root.turning = false;
            root.pickUp();
        }
    }
    function pickUp() {
        // wound in the cable, it stays where it is
        if (tangled) {
            wiggle();
            return;
        }
        flight.running = false;
        homeAnim.stop();
        faceAnim.stop();
        spinOn.running = false;
        held = true;
        liftAnim.to = 1;
        liftAnim.restart();
        PhoneLine.play("click", 0.4);
    }
    // the pointer moved: only noted here, the phone catches up once a frame (turnStep) — a quick
    // mouse sends a thousand moves a second, and a rebuild for each fell behind the hand
    function turnMove(item, mx, my) {
        const f = turnFrom;
        if (!f)
            return;
        const p = item.mapToItem(root, mx, my), t = Date.now();
        // a face edge-on to the eye can't map the pointer back: that move is skipped
        if (!isFinite(p.x) || !isFinite(p.y))
            return;
        f.x = p.x;
        f.y = p.y;
        // the hand's last moments (its speed): some 60 ms of them
        f.trail.push([t, p.x, p.y]);
        while (f.trail.length > 2 && t - f.trail[1][0] > 60)
            f.trail.shift();
        // the hand moves: the pick-up waits for it to stand still again (by how far it went, not
        // by a step: a quick mouse moves a pixel a step)
        if (!held && Math.hypot(p.x - f.hx, p.y - f.hy) > k * 2) {
            f.hx = p.x;
            f.hy = p.y;
            if (!Motion.still)
                holdWait.restart();
        }
    }
    FrameAnimation {
        id: turnTick
        onTriggered: {
            // the hand is gone (release lost): nothing to follow
            if (!root.turnFrom)
                running = false;
            else
                root.turnStep();
        }
    }
    function turnStep() {
        const f = turnFrom;
        if (!f)
            return;
        const dx = f.x - f.ax, dy = f.y - f.ay;
        if (!dx && !dy)
            return;
        if (held) {
            // in the hand: it follows the pointer
            f.ax = f.x;
            f.ay = f.y;
            offX += dx;
            offY += dy;
            return;
        }
        if (!turning && Math.hypot(f.x - f.x0, f.y - f.y0) < k * 3)
            return;
        turning = true;
        f.ax = f.x;
        f.ay = f.y;
        const was = rot;
        turnBy([-dy, dx, 0], Math.hypot(dx, dy) * turnGain(handSpeed(f)) * Math.PI / 180);
        // open: no further than 25° (or than it already was)
        if (lidUp && P3.qangle(rot) > Math.max(25, f.from))
            rot = was;
        // a shake: back along x after a good run one way
        if (dx * f.run < 0) {
            if (Math.abs(f.run) > k * 8)
                shakes++;
            f.run = 0;
        }
        f.run += dx;
    }
    // the hand's speed (px a ms) over its last moments, up to now: [x, y, along its way (round
    // and round it goes further than it gets)]; a hand that stopped has none
    function handSpeed(f) {
        const tr = f.trail, a = tr[0], b = tr[tr.length - 1], now = Date.now();
        if (now - b[0] > 90)
            return [0, 0, 0];
        const dt = Math.max(8, now - a[0]);
        let way = 0;
        for (let i = 1; i < tr.length; i++)
            way += Math.hypot(tr[i][1] - tr[i - 1][1], tr[i][2] - tr[i - 1][2]);
        return [(b[1] - a[1]) / dt, (b[2] - a[2]) / dt, way / dt];
    }
    // degrees a pixel: calm under a slow hand, up to twice that under a quick one
    function turnGain(v) {
        const s = clamp((v[2] - 0.5) / 2, 0, 1);
        return turnRate * (1 + s * s * (3 - 2 * s));
    }
    function turnEnd() {
        holdWait.stop();
        turnTick.running = false;
        // what the hand did since the last frame
        turnStep();
        const f = turnFrom;
        turnFrom = null;
        if (!f)
            return;
        const v = handSpeed(f), vx = v[0], vy = v[1];
        if (held) {
            held = false;
            release(vx, vy);
            return;
        }
        if (!turning) {
            // a click on the shut phone opens it (the bars: wakes the keys); tangled, it can't
            if (PhoneLine.dead)
                deadFlash.restart();
            else if (!lidUp && tangled && !bar)
                wiggle();
            else if (!lidUp)
                Sidebar.open = true;
            return;
        }
        turning = false;
        // open: back to face you
        if (lidUp) {
            faceUp();
            return;
        }
        // the spin goes on as fast as the hand turned it; at most three turns a second
        const r = Math.min(Math.hypot(vx, vy) * 1000 * turnGain(v), 1080) * Math.PI / 180, l = Math.hypot(vx, vy) || 1;
        spin = [-vy / l * r, vx / l * r, 0];
        if (!Motion.still && r > 0.2)
            spinOn.running = true;
        // shut, a hard spin or a shake asks the ball
        if (Math.hypot(vx, vy) > 1.6 || shakes >= 4)
            askBall.restart();
    }
    FrameAnimation {
        id: spinOn
        onTriggered: {
            const dt = Math.min(frameTime, 0.05), s = root.spin, r = Math.hypot(s[0], s[1], s[2]);
            root.turnBy(s, r * dt);
            const keep = Math.exp(-dt * 2.4);
            root.spin = [s[0] * keep, s[1] * keep, s[2] * keep];
            if (!(r >= 0.1) || !root.present)
                running = false;
        }
    }
    // a double click (and the open phone let go): face to you again, the short way round
    property var faceFrom: [1, 0, 0, 0]
    property real faceT: 0
    onFaceTChanged: if (faceAnim.running)
        rot = P3.qslerp(faceFrom, [1, 0, 0, 0], faceT)
    function faceUp() {
        spinOn.running = false;
        faceFrom = rot;
        faceAnim.restart();
    }
    NumberAnimation {
        id: faceAnim
        target: root
        property: "faceT"
        from: 0
        to: 1
        duration: Motion.ms(520)
        easing.type: Easing.OutBack
        onFinished: root.rot = [1, 0, 0, 0]
    }
    Timer {
        id: askBall
        interval: 700
        onTriggered: {
            root.answer = PhoneLine.ballAnswer();
            ballGone.restart();
        }
    }
    Timer {
        id: ballGone
        interval: 4500
        onTriggered: root.answer = ""
    }
    // the ball from the menu too (PhoneScreen)
    function ask() {
        askBall.restart();
    }

    // ---- picked up, thrown: where it is off its place, how near (lift) ----
    property real offX: 0
    property real offY: 0
    property real lift: 0                 // 0 on the desk … 1 in the hand (a little closer)
    NumberAnimation {
        id: liftAnim
        target: root
        property: "lift"
        duration: Motion.ms(180)
        easing.type: Easing.OutCubic
    }
    property real flyX: 0                 // px a second
    property real flyY: 0
    property bool crackedNow: false
    property real flownFor: 0             // s in the air (it gives up after a while)
    property real restFor: 0              // s lying still on the bottom
    property real knockAt: 0              // the last knock's sound (ms), not a rattle of them
    function release(vx, vy) {
        liftAnim.to = 0;
        liftAnim.restart();
        if (Math.hypot(vx, vy) < 0.8 || Motion.still) {
            goHome(0);
            return;
        }
        flyX = clamp(vx, -4, 4) * 1000;
        flyY = clamp(vy, -4, 4) * 1000;
        PhoneLine.bump("throws");
        // a throw turns it end over end the way the hand went, and a little about itself
        spin = [-vy * 1.6 + (Math.random() - 0.5), vx * 1.6 + (Math.random() - 0.5), vx * 0.5 + (Math.random() - 0.5) * 2];
        crackedNow = false;
        flownFor = 0;
        restFor = 0;
        flight.running = true;
    }
    readonly property bool flying: flight.running
    // dropped by hand from the menu or a test: a throw straight down
    function fall() {
        release(0, 2.5);
    }
    // the shut phone as a box about its pivot (its corners) and its inertia (a solid box, mass 1)
    function corners() {
        const hw = w / 2, y1 = bar ? bh : Math.max(bh, lh), z0 = -tb, z1 = bar || lidUp ? 0 : tl, top = bar ? 0 : lidUp ? -lh : g;
        const list = [];
        for (const x of [-hw, hw])
            for (const y of [top, y1])
                for (const z of [z0, z1])
                    list.push([x, y, z]);
        return list;
    }
    function knock(p, centre, n, e, v) {
        // the corner's speed into the wall: the box's own and its turn's
        const s = spin, r = [p[0] - centre[0], p[1] - centre[1], p[2] - centre[2]];
        const vp = [v[0] + s[1] * r[2] - s[2] * r[1], v[1] + s[2] * r[0] - s[0] * r[2], s[0] * r[1] - s[1] * r[0]];
        const vn = P3.dot(vp, n);
        if (vn >= 0)
            return 0;
        const I = (w * w + (bh + g) * (bh + g)) / 12;
        const rn = P3.cross(r, n), j = -(1 + e) * vn / (1 + P3.dot(rn, rn) / I);
        // and it skids: friction along the wall, at most what stops the corner
        const vt = [vp[0] - vn * n[0], vp[1] - vn * n[1], vp[2] - vn * n[2]], tl_ = Math.hypot(vt[0], vt[1], vt[2]);
        let imp = [j * n[0], j * n[1], j * n[2]];
        if (tl_ > 1e-3) {
            const t = [vt[0] / tl_, vt[1] / tl_, vt[2] / tl_], rt = P3.cross(r, t);
            const jt = -Math.min(0.45 * j, tl_ / (1 + P3.dot(rt, rt) / I));
            imp = [imp[0] + jt * t[0], imp[1] + jt * t[1], imp[2] + jt * t[2]];
        }
        v[0] += imp[0];
        v[1] += imp[1];
        const dw = P3.cross(r, imp);
        spin = [s[0] + dw[0] / I, s[1] + dw[1] / I, s[2] + dw[2] / I];
        return -vn;
    }
    FrameAnimation {
        id: flight
        onTriggered: {
            const dt = Math.min(frameTime, 0.04) / 2, kk = root.k;
            // world: (0, 0) is the phone's place; the screen's edges around it
            const lo = [-root.cx, -root.cy], hi = [root.width - root.cx, root.height - root.cy];
            let floor = false;
            for (let step = 0; step < 2; step++) {
                const v = [root.flyX, root.flyY + kk * 1800 * dt, 0];
                root.offX += v[0] * dt;
                root.offY += v[1] * dt;
                const s = root.spin, r = Math.hypot(s[0], s[1], s[2]);
                root.turnBy(s, r * dt);
                const model = root.modelNow(), centre = P3.apply(model, root.pivot);
                // the deepest corner past each edge: pushed back, then knocked
                const walls = [[1, lo[0], [1, 0, 0]], [1, hi[0], [-1, 0, 0]], [0, lo[1], [0, 1, 0]], [0, hi[1], [0, -1, 0]]];
                for (let i = 0; i < 4; i++) {
                    const ax = i < 2 ? 0 : 1, edge = walls[i][1], n = walls[i][2];
                    let deep = 0, at = null;
                    for (const c of root.corners()) {
                        const p = P3.apply(model, c), past = (edge - p[ax]) * n[ax];
                        if (past > deep) {
                            deep = past;
                            at = p;
                        }
                    }
                    if (!at)
                        continue;
                    if (ax === 0)
                        root.offX += deep * n[0];
                    else
                        root.offY += deep * n[1];
                    const hit = root.knock(at, centre, n, i === 3 ? 0.32 : 0.5, v);
                    if (i === 3) {
                        floor = true;
                        // lying on it: it rolls to a stop
                        const keep = Math.exp(-dt * 4);
                        root.spin = root.spin.map(a => a * keep);
                        v[0] *= Math.exp(-dt * 2);
                    }
                    const now = Date.now();
                    if (hit > kk * 150 && now - root.knockAt > 90) {
                        root.knockAt = now;
                        PhoneLine.play("clack", Math.min(1, hit / (kk * 900)));
                    }
                    if (i === 3 && hit > kk * 900 && !root.crackedNow) {
                        root.crackedNow = true;
                        if (root.model === "3310")
                            root.crackDesk(at[0] + root.cx, at[1] + root.cy);
                        else
                            PhoneLine.drop();
                    }
                }
                root.flyX = v[0];
                root.flyY = v[1];
            }
            root.flownFor += dt * 2;
            const still = floor && Math.hypot(root.flyX, root.flyY) < kk * 40 && Math.hypot(...root.spin) < 0.8;
            root.restFor = still ? root.restFor + dt * 2 : 0;
            if (root.restFor > 0.3 || root.flownFor > 6) {
                running = false;
                root.spin = [0, 0, 0];
                root.goHome(root.crackedNow ? 900 : 400);
            }
        }
    }
    function goHome(wait) {
        homeWait.duration = wait;
        homeAnim.restart();
    }
    SequentialAnimation {
        id: homeAnim
        PauseAnimation {
            id: homeWait
            duration: 300
        }
        // back in place, it turns its face to you on the way
        ScriptAction {
            script: root.faceUp()
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "offX"
                to: 0
                duration: Motion.ms(650)
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: root
                property: "offY"
                to: 0
                duration: Motion.ms(650)
                easing.type: Easing.InOutCubic
            }
        }
    }

    // ---- the battery: dead, a key shows the empty cell; what eats it faster ----
    Timer {
        id: deadFlash
        interval: 1500
    }
    Binding {
        target: PhoneLine
        property: "hungry"
        value: root.present && root.screenOn && (root.torch || ["snake", "raid", "camera"].includes(screen.app))
    }
    Connections {
        target: PhoneLine
        function onPowered(on) {
            if (!on) {
                root.torch = false;
                Sidebar.open = false;
            }
        }
    }

    // ---- the brick's landing: the computer's screen cracks instead, for a minute ----
    property var deskCrack: null           // {x, y, at}
    function crackDesk(x, y) {
        deskCrack = {
            "x": x,
            "y": y,
            "seed": Math.floor(Math.random() * 100000) + 1
        };
        crackGone.restart();
        PhoneLine.play("clack", 1);
        Achievements.note("phone.drop");
    }
    Timer {
        id: crackGone
        interval: 60000
        onTriggered: root.deskCrack = null
    }
    Canvas {
        id: deskCanvas
        anchors.fill: parent
        z: -2
        visible: !!root.deskCrack
        renderStrategy: Canvas.Cooperative
        onVisibleChanged: requestPaint()
        Connections {
            target: root
            function onDeskCrackChanged() {
                deskCanvas.requestPaint();
            }
        }
        onPaint: {
            const c = getContext("2d"), d = root.deskCrack, kk = root.k;
            c.reset();
            if (!d)
                return;
            let seed = d.seed;
            const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
            // glass cracks from where it hit, in whole pixels, a dark line under a light one
            for (const pass of [["rgba(0,0,0,0.55)", kk * 2, kk], ["rgba(255,255,255,0.85)", kk, 0]]) {
                seed = d.seed;
                c.strokeStyle = pass[0];
                c.lineWidth = pass[1];
                for (let i = 0; i < 11; i++) {
                    let a = i / 11 * Math.PI * 2 + rnd() * 0.6, x = d.x, y = d.y;
                    c.beginPath();
                    c.moveTo(x + pass[2], y + pass[2]);
                    const n = 3 + Math.floor(rnd() * 4);
                    for (let j = 0; j < n; j++) {
                        a += (rnd() - 0.5) * 0.8;
                        const len = kk * (14 + rnd() * 46) * (1 + j * 0.4);
                        x += Math.cos(a) * len;
                        y += Math.sin(a) * len;
                        c.lineTo(Math.round(x / kk) * kk + pass[2], Math.round(y / kk) * kk + pass[2]);
                    }
                    c.stroke();
                }
            }
            c.fillStyle = "rgba(255,255,255,0.9)";
            c.fillRect(Math.round(d.x / kk) * kk - kk * 2, Math.round(d.y / kk) * kk - kk * 2, kk * 4, kk * 4);
        }
    }

    // ---- the charger: the extension lead on the floor, the cable, the plug ----
    PhoneCharger {
        id: charger
        anchors.fill: parent
        z: 800
        phone: root
        visible: root.present && root.slide < 0.5
    }
    readonly property Item plugBox: charger.plugBox
    readonly property Item stripBox: charger.stripBox

    // ---- the torch: the whole screen white ----
    property bool torch: false
    Rectangle {
        anchors.fill: parent
        z: -1
        visible: root.torch
        color: "#ffffff"
        // on stream softer: the viewers' eyes
        opacity: StreamMode.active ? 0.55 : 0.97
        MouseArea {
            anchors.fill: parent
            onPressed: root.torch = false
        }
    }

    // ---- the 3D: one rebuild for whatever moved ----
    readonly property var pose: [turn, slide, lid, tiltX, tiltY, cx, cy, width, height, buzzX, buzzTurn, antenna, rot, offX, offY, lift, wiggleX, model]
    onPoseChanged: rebuild()
    readonly property real eye: k * 760                    // the eye's distance from the screen (px)
    readonly property var light: {
        const l = [-0.35, -0.6, 0.72], n = Math.hypot(l[0], l[1], l[2]);
        return [l[0] / n, l[1] / n, l[2] / n];
    }

    function faces() {
        const hw = w / 2;
        return [
            // the base: z 0 its front, −tb its back; from the hinge (y g) down to bh
            {"item": baseFront, "o": [-hw, g, 0], "u": [1, 0, 0], "v": [0, 1, 0], "w": w, "h": bh - g},
            {"item": baseBack, "o": [hw, g, -tb], "u": [-1, 0, 0], "v": [0, 1, 0], "w": w, "h": bh - g},
            {"item": baseBottom, "o": [-hw, bh, 0], "u": [1, 0, 0], "v": [0, 0, -1], "w": w, "h": tb},
            {"item": baseLeft, "o": [-hw, g, -tb], "u": [0, 0, 1], "v": [0, 1, 0], "w": tb, "h": bh - g},
            {"item": baseRight, "o": [hw, g, 0], "u": [0, 0, -1], "v": [0, 1, 0], "w": tb, "h": bh - g},
            {"item": baseTop, "o": [-hw, g, -tb], "u": [1, 0, 0], "v": [0, 0, 1], "w": w, "h": tb},
            // the lid, drawn open (up from the hinge), then swung by `lid` about the hinge
            {"item": lidFront, "o": [-hw, -lh, 0], "u": [1, 0, 0], "v": [0, 1, 0], "w": w, "h": lh - g, "lid": true},
            {"item": lidBack, "o": [-hw, -g, -tl], "u": [1, 0, 0], "v": [0, -1, 0], "w": w, "h": lh - g, "lid": true},
            {"item": lidTop, "o": [-hw, -lh, -tl], "u": [1, 0, 0], "v": [0, 0, 1], "w": w, "h": tl, "lid": true},
            {"item": lidLeft, "o": [-hw, -lh, -tl], "u": [0, 0, 1], "v": [0, 1, 0], "w": tl, "h": lh - g, "lid": true},
            {"item": lidRight, "o": [hw, -lh, 0], "u": [0, 0, -1], "v": [0, 1, 0], "w": tl, "h": lh - g, "lid": true},
            {"item": lidBottom, "o": [-hw, -g, 0], "u": [1, 0, 0], "v": [0, 0, -1], "w": w, "h": tl, "lid": true},
            // the antenna, at the base's top right, beside the lid
            {"item": antennaFace, "o": [hw + k, g - antennaLen, -tb * 0.5], "u": [1, 0, 0], "v": [0, 1, 0], "w": k * 5, "h": antennaLen}
        ];
    }
    readonly property real antennaLen: k * (8 + 26 * antenna)
    // what it turns about in the hand: the shut phone's middle (the lid folded over the base)
    readonly property var pivot: bar ? [0, bh / 2, -tb / 2] : [0, (g + Math.max(bh, lh)) / 2, (tl - tb) / 2]
    // where it is and how it is turned in the world, before the lens
    function modelNow() {
        // out past its edge, spinning a little on the way
        const far = k * 300;
        const side = edge === "left" || edge === "right";
        const sx = (edge === "right" ? slide * (width - cx + far) : edge === "left" ? -slide * (cx + far) : 0) + buzzX + offX + wiggleX;
        const sy = (edge === "bottom" ? slide * (height - cy + far) : edge === "top" ? -slide * (cy + far) : 0) + offY;
        const spinY = side ? slide * (edge === "right" ? 70 : -70) : 0;
        const spinX = side ? 0 : slide * (edge === "bottom" ? -60 : 60);
        // turned about the open phone's middle; the base stays put while the lid swings (it is
        // pulled by hand: the hinge must not slide from under the pointer)
        const midY = bar ? bh / 2 : (bh - lh) / 2;
        const ax = tiltX + spinX;
        around = P3.chain(P3.turnZ(-90 * turn + buzzTurn), P3.turnX(ax), P3.turnY(tiltY + spinY));
        const c = pivot;
        return P3.chain(P3.move(sx, sy, lift * k * 40), around, P3.move(c[0], c[1] - midY, c[2]), P3.qmatrix(rot), P3.move(-c[0], -c[1], -c[2]));
    }
    function rebuild() {
        if (width <= 0)
            return;
        const model = modelNow();
        const lens = P3.lens(cx, cy, eye);
        const swing = P3.turnX(-lid);
        const list = faces();
        const depth = [];
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (const f of list) {
            const m = f.lid ? P3.mul(model, swing) : model;
            const seen = P3.look(m, f, eye);
            f.item.width = f.w;
            f.item.height = f.h;
            f.item.m = P3.chain(lens, m, P3.frame(f.o, f.u, f.v));
            const gone = bar && (f.lid || f.item === antennaFace);
            f.item.away = gone || !seen.facing && f.item !== antennaFace;
            if (gone)
                continue;
            if (seen.facing)
                for (const c of [[0, 0], [f.w, 0], [0, f.h], [f.w, f.h]]) {
                    const q = P3.project(f.item.m, [c[0], c[1], 0]);
                    x0 = Math.min(x0, q[0]);
                    y0 = Math.min(y0, q[1]);
                    x1 = Math.max(x1, q[0]);
                    y1 = Math.max(y1, q[1]);
                }
            const n = seen.normal, nl = Math.hypot(n[0], n[1], n[2]) || 1;
            f.item.shade = Math.max(0, (n[0] * light[0] + n[1] * light[1] + n[2] * light[2]) / nl);
            depth.push([seen.centre[2], f.item, f.lid ? "lid" : f.item === antennaFace ? "antenna" : "base"]);
        }
        // the hinge: a cylinder of eight strips and two round ends, drawn like the rest. It is
        // flattened where it meets the base and the lid (|y| ≤ g): poking into them, its strips
        // cut over their edges whichever of them was painted first
        const r = tb * 0.6, zc = -tb * 0.45, hl = w / 2 - k * 2, n8 = 8, ry = Math.min(r, g);
        const at = a => [0, Math.max(-ry, Math.min(ry, -r * Math.cos(a))), zc + r * Math.sin(a)];
        for (let i = 0; i < n8; i++) {
            const a0 = i * 2 * Math.PI / n8, a1 = (i + 1) * 2 * Math.PI / n8;
            const p0 = at(a0), p1 = at(a1), len = Math.hypot(p1[1] - p0[1], p1[2] - p0[2]);
            const f = {
                "o": [-hl, p0[1], p0[2]],
                "u": [1, 0, 0],
                "v": [0, (p1[1] - p0[1]) / len, (p1[2] - p0[2]) / len],
                "w": hl * 2,
                "h": len + 1
            };
            const it = hingeStrips.itemAt(i);
            if (!it)
                continue;
            const seen = P3.look(model, f, eye);
            it.width = f.w;
            it.height = f.h;
            it.m = P3.chain(lens, model, P3.frame(f.o, f.u, f.v));
            it.away = bar || !seen.facing;
            const nn = seen.normal, nl = Math.hypot(nn[0], nn[1], nn[2]) || 1;
            it.shade = Math.max(0, (nn[0] * light[0] + nn[1] * light[1] + nn[2] * light[2]) / nl);
            depth.push([seen.centre[2], it, "hinge"]);
        }
        for (let e = 0; e < 2; e++) {
            const it = hingeEnds.itemAt(e);
            if (!it)
                continue;
            const f = e ? {
                "o": [hl, -ry, zc + r],
                "u": [0, 0, -1],
                "v": [0, 1, 0],
                "w": r * 2,
                "h": ry * 2
            } : {
                "o": [-hl, -ry, zc - r],
                "u": [0, 0, 1],
                "v": [0, 1, 0],
                "w": r * 2,
                "h": ry * 2
            };
            const seen = P3.look(model, f, eye);
            it.width = f.w;
            it.height = f.h;
            it.m = P3.chain(lens, model, P3.frame(f.o, f.u, f.v));
            it.away = bar || !seen.facing;
            depth.push([seen.centre[2], it, "hinge"]);
        }
        // painted part by part (base, lid, hinge, antenna), the far part first: each part is a
        // convex box, so its faces turned to the eye never cover each other. Which of two parts
        // is nearer is told by a plane between them (the eye's side of it), not by their middles:
        // the shut lid lies on the base, and seen from a slant the base's middle came nearer and
        // its keys were painted over the lid's edges (the lid's inside over the base's, too)
        const spot = [model[3], model[7], model[11]];
        const seer = P3.undir(model, [-spot[0], -spot[1], eye - spot[2]]);    // the eye in the phone
        const seerLid = P3.undir(swing, seer);                                // … and in the lid
        const cut = P3.parting([[g, 0], [g, -tb], [bh, 0], [bh, -tb]], [[-g, 0], [-g, -tl], [-lh, 0], [-lh, -tl]].map(p => {
            const q = P3.dir(swing, [0, p[0], p[1]]);
            return [q[1], q[2]];
        }));
        const out = seer[0] > w / 2 + k / 2;    // the antenna stands beside them all
        // [nearer, farther]; a part's rank: how many parts it is nearer than
        const ahead = [cut[0] * seer[1] + cut[1] * seer[2] > cut[2] ? ["lid", "base"] : ["base", "lid"], seer[1] < g ? ["hinge", "base"] : ["base", "hinge"], seerLid[1] > -g ? ["hinge", "lid"] : ["lid", "hinge"], out ? ["antenna", "base"] : ["base", "antenna"], out ? ["antenna", "lid"] : ["lid", "antenna"], out ? ["antenna", "hinge"] : ["hinge", "antenna"]];
        const rank = {
            "base": 0,
            "lid": 0,
            "hinge": 0,
            "antenna": 0
        };
        for (const p of ahead)
            rank[p[0]]++;
        depth.sort((a, b) => rank[a[2]] - rank[b[2]] || a[0] - b[0]);
        for (let i = 0; i < depth.length; i++)
            depth[i][1].z = i + 1;
        // what the hand pulls: the lid by its line from the hinge, the antenna along itself
        const lm = P3.mul(lens, model);
        hingeAt = P3.project(lm, [0, 0, 0]);
        lidTopAt = P3.project(lm, [0, -lh, 0]);
        antennaFoot = P3.project(lm, [w / 2 + k * 3, g, -tb * 0.5]);
        antennaTip = P3.project(lm, [w / 2 + k * 3, g - k * 34, -tb * 0.5]);
        // the strap's ring: the base's bottom left corner; the charger's port: its bottom end
        strapAt = P3.project(lm, [-w / 2 + k * 5, bh - k * 2, -tb * 0.5]);
        portAt = P3.project(lm, [0, bh, -tb * 0.5]);
        // the taco rings: turned edge-on to the ear (its side to you), it answers
        if (taco && PhoneLine.ringing && !PhoneLine.call.outgoing && !sideAnswered) {
            const side = P3.dir(model, [1, 0, 0]), l = Math.hypot(side[0], side[1], side[2]) || 1;
            if (Math.abs(side[2] / l) > 0.82) {
                sideAnswered = true;
                PhoneLine.answer();
                sideBack.restart();
            }
        }
        // the shut phone on the desk takes clicks only here (SidebarHost's mask)
        hitBox.x = x0 - k * 2;
        hitBox.y = y0 - k * 2;
        hitBox.width = Math.max(1, x1 - x0 + k * 4);
        hitBox.height = Math.max(1, y1 - y0 + k * 4);
    }
    property var portAt: [0, 0]
    property bool sideAnswered: false
    Connections {
        target: PhoneLine
        function onRingingChanged() {
            if (PhoneLine.ringing)
                root.sideAnswered = false;
        }
    }
    // answered edge-on: back to face you to read her
    Timer {
        id: sideBack
        interval: 900
        onTriggered: root.faceUp()
    }
    readonly property Item hitBox: hitBoxItem
    Item {
        id: hitBoxItem
    }
    onWidthChanged: rebuild()

    // ---- colours: a pearly shell in the accent; hell's in its own ----
    readonly property bool hell: Theme.hell
    // the tuning (PhoneLine.wearing): the shell's colour, banded for the metal ones (pixel gloss)
    readonly property string shellLook: PhoneLine.wearing("shell")
    readonly property bool metal: shellLook === "chrome" || shellLook === "gold"
    readonly property color shellColor: ({
            "pearl": "#f2c4d6",
            "black": "#24212c",
            "chrome": "#c4c8d3",
            "hell": Theme.mix(Theme.hellFace, Theme.hellAccent, 0.3),
            "xray": Qt.rgba(0.62, 0.82, 0.95, 0.62),
            "gold": "#d6ad48"
        })[shellLook] || (hell ? Theme.mix(Theme.hellFace, Theme.hellAccent, 0.18) : Theme.dark ? Theme.mix(Theme.mix(Theme.faceAlt, "#ffffff", 0.18), Theme.accent, 0.42) : Theme.mix(Theme.face, Theme.accent, 0.3))
    readonly property string gems: PhoneLine.wearing("gems")
    readonly property string sticker: PhoneLine.wearing("sticker")
    readonly property string charm: PhoneLine.wearing("charm")
    readonly property string screenWall: PhoneLine.wearing("wall")
    // the rhinestones twinkle in turns, slowly
    property int twinkle: 0
    Timer {
        interval: 600
        running: root.present && root.gems !== "none" && !Motion.still
        repeat: true
        onTriggered: root.twinkle++
    }
    readonly property color trim: hell ? Theme.hellAccent : Theme.accent
    // the screen's ink: the brick's LCD is a light one with dark pixels (then tinted green)
    readonly property bool lightLcd: model === "3310"
    readonly property color screenInk: lightLcd ? "#1a2210" : hell ? Theme.hellText : Theme.text
    readonly property color screenDim: lightLcd ? "#4d5a34" : hell ? Theme.hellTextDim : Theme.textDim
    readonly property color ink: shellLook === "black" ? "#5a5466" : hell ? Theme.hellEdge : Theme.mix(Theme.edge, Theme.accent, 0.25)
    readonly property color glass: hell ? "#140608" : Theme.mix("#100c18", Theme.accent, 0.1)
    readonly property color lit: Theme.mix(shellColor, "#ffffff", shellLook === "black" ? 0.2 : hell ? 0.08 : 0.35)
    function shaded(c, s) {
        return Theme.mix(c, "#000000", 0.55 * (1 - s));
    }

    // what's on the keys and the screen
    SystemClock {
        id: clock
        enabled: root.visible
        precision: SystemClock.Minutes
    }
    readonly property alias now: clock.date
    readonly property var keyNames: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
    property string hint: ""             // the key under the pointer, shown on the screen's last line

    // the pointer anywhere over the window: the lean
    HoverHandler {
        onPointChanged: root.lean(point.position.x, point.position.y)
        onHoveredChanged: if (!hovered)
            root.lean(-1e6, -1e6)
    }
    // the pointer over the phone: what can be done with it, the first few times (and while held)
    property bool hovering: false
    onHoveringChanged: if (hovering && !lidUp && (PhoneLine.stats.hints || 0) < 6)
        PhoneLine.bump("hints")
    readonly property string tip: taco && ringingHere && !sideAnswered ? PhoneLine.tr(PL.sidetalk) : tangled && (hovering || turning) ? PhoneLine.tr(PL.tangled) : held ? I18n.t("отпусти — вернётся · брось — полетит", "let go: it goes home · throw: it flies") : hovering && !lidUp && !turning && (PhoneLine.stats.hints || 0) <= 6 ? I18n.t("тяни — крутить · зажми — взять · клик — открыть", "drag: turn · hold: pick up · click: open") : ""
    PxBox {
        z: 950
        visible: root.tip !== "" && root.present
        x: Math.round(Math.max(root.k * 2, Math.min(root.width - width - root.k * 2, root.hitBox.x + root.hitBox.width / 2 - width / 2)))
        y: Math.round(Math.min(root.height - height - root.k * 2, root.hitBox.y + root.hitBox.height + root.k * 2))
        width: tipText.implicitWidth + root.k * 6
        height: tipText.implicitHeight + root.k * 3
        color: Theme.menuSurface
        PxText {
            id: tipText
            anchors.centerIn: parent
            text: root.tip
            kind: "tiny"
        }
    }
    Connections {
        target: Sidebar
        enabled: Shell.dev
        function onDevLean(x, y) {
            root.lean(root.cx + x, root.cy + y);
        }
        function onDevKey(k) {
            if (k.startsWith("pull:")) {
                // the pointer where the lid's top would be at that angle
                const a = Number(k.slice(5)) * Math.PI / 180, c = Math.cos(a);
                const x = root.hingeAt[0] + (root.lidTopAt[0] - root.hingeAt[0]) * c, y = root.hingeAt[1] + (root.lidTopAt[1] - root.hingeAt[1]) * c;
                if (!root.dragging)
                    root.grabLid(root, root.hingeAt[0], root.hingeAt[1]);
                root.pullLid(root, x, y);
            } else if (k === "drop") {
                root.dropLid();
            } else if (k.startsWith("antenna:")) {
                root.antenna = Number(k.slice(8));
            } else if (k.startsWith("rot:")) {
                const a = k.slice(4).split(",").map(Number);
                root.rot = P3.qmul(P3.quat([1, 0, 0], (a[1] || 0) * Math.PI / 180), P3.quat([0, 1, 0], a[0] * Math.PI / 180));
            } else if (k.startsWith("spin:")) {
                root.spin = [0, Number(k.slice(5)) * Math.PI / 180, 0];
                spinOn.running = true;
            } else if (k === "fall") {
                root.fall();
            } else if (k.startsWith("throw:")) {
                const v = k.slice(6).split(",").map(Number);
                root.pickUp();
                root.held = false;
                root.release(v[0], v[1] || 0);
            } else if (k.startsWith("turn:")) {
                const d = k.slice(5).split(",").map(Number);
                root.turnStart(root, root.cx, root.cy);
                for (let i = 1; i <= 10; i++)
                    root.turnMove(root, root.cx + d[0] * i / 10, root.cy + (d[1] || 0) * i / 10);
                root.turnEnd();
            } else if (k === "face") {
                root.faceUp();
            } else if (k === "plug" || k === "unplug") {
                charger.plugState = k === "plug" ? "in" : "rest";
                PhoneLine.plug(k === "plug");
                charger.wake();
            } else if (k.startsWith("batt:")) {
                const v = Number(k.slice(5));
                PhoneLine._battSet({
                    "lvl": v,
                    "off": v <= 0
                });
                if (v <= 0)
                    PhoneLine.powered(false);
                PhoneLine._battCheck();
            } else if (k.startsWith("model:")) {
                PhoneLine.wear("model", k.slice(6));
            } else if (k.startsWith("wind:")) {
                root.wind = Number(k.slice(5));
            } else if (k === "lore") {
                PhoneLine.loreOut();
            } else if (k.startsWith("ring:")) {
                PhoneLine.ring(k.slice(5), "random");
            } else if (k === "sister") {
                PhoneLine.receive("demon", PhoneLine.sisterText());
            } else {
                root.key(k);
            }
        }
    }

    // the soft keys' words (the green key, OK, the red key), from the screen
    readonly property var soft: Sidebar.turned && !bar ? ["", I18n.t("Поставить", "Upright"), I18n.t("Поставить", "Upright")] : screen.soft
    // a key of the keypad or the keyboard: it beeps, then the screen has it
    function key(k) {
        PhoneLine.ensure();
        // the torch: any key puts it out
        if (torch) {
            torch = false;
            return;
        }
        if (PhoneLine.dead) {
            deadFlash.restart();
            return;
        }
        PhoneLine.tone(k.startsWith("t:") ? "" : k);
        if (Sidebar.turned && !bar) {
            if (k === "left" || k === "right")
                side.leaf(k === "left" ? -1 : 1);
            else if (k === "end" || k === "ok")
                Sidebar.turned = false;
            return;
        }
        if (!lidUp) {
            if (tangled && !bar) {
                wiggle();
                return;
            }
            Sidebar.open = true;
            // a bar has no lid to open: its keys work at once while it rings
            if (!(bar && PhoneLine.ringing))
                return;
        }
        // the red key with nothing to go back from shuts the lid
        if (!screen.key(k) && k === "end")
            Sidebar.open = false;
    }
    function leaf(step) {
        key(step < 0 ? "left" : "right");
    }

    // the keyboard while it is open
    focus: true
    Keys.onPressed: e => {
        const writing = screen.app === "write" && !Sidebar.turned && lidUp;
        const named = {
            [Qt.Key_Left]: "left",
            [Qt.Key_Right]: "right",
            [Qt.Key_Up]: "up",
            [Qt.Key_Down]: "down",
            [Qt.Key_Return]: "ok",
            [Qt.Key_Enter]: "ok",
            [Qt.Key_Escape]: "end",
            [Qt.Key_F1]: "call"
        }[e.key];
        if (e.key === Qt.Key_Backspace) {
            root.key(writing ? "t:\b" : ["dial", "composer"].includes(screen.app) ? "left" : "end");
        } else if (e.key === Qt.Key_Tab && !bar) {
            Sidebar.turned = !Sidebar.turned;
        } else if (named) {
            // Esc on the shut phone takes it away
            if (named === "end" && !lidUp)
                Sidebar.hide();
            else
                root.key(named);
        } else if (writing && e.text && e.text.length === 1 && e.text >= " ") {
            root.key("t:" + e.text);
        } else if (/^[0-9*#]$/.test(e.text) && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            root.key(e.text);
        } else {
            return;
        }
        e.accepted = true;
    }

    // ---- the strap: a tiny her on a string, swinging as the phone moves ----
    property var strapAt: [0, 0]
    readonly property real strapLen: k * 16
    property real strapAngle: 0           // radians from straight down
    property real strapSpin: 0            // radians a second
    property var strapWas: null           // the ring's last place and speed
    property double strapIdle: 0
    onStrapAtChanged: {
        strapIdle = 0;
        if (present && !Motion.still)
            strapRun.running = true;
    }
    FrameAnimation {
        id: strapRun
        onTriggered: {
            const dt = Math.max(0.001, Math.min(frameTime, 0.05));
            const p = root.strapAt, w = root.strapWas;
            let ax = 0, ay = 0, vx = 0, vy = 0;
            if (w) {
                vx = (p[0] - w.x) / dt;
                vy = (p[1] - w.y) / dt;
                ax = Math.max(-40000, Math.min(40000, (vx - w.vx) / dt));
                ay = Math.max(-40000, Math.min(40000, (vy - w.vy) / dt));
            }
            root.strapWas = {
                "x": p[0],
                "y": p[1],
                "vx": vx,
                "vy": vy
            };
            const L = root.strapLen, th = root.strapAngle;
            const acc = -(2400 / L) * Math.sin(th) - (ax * Math.cos(th) + ay * Math.sin(th)) / L - 2.2 * root.strapSpin;
            root.strapSpin += acc * dt;
            root.strapAngle = Math.max(-2.6, Math.min(2.6, th + root.strapSpin * dt));
            // settled and still: stop until the phone moves again
            root.strapIdle = Math.abs(root.strapSpin) < 0.02 && Math.abs(root.strapAngle) < 0.01 && Math.hypot(vx, vy) < 1 ? root.strapIdle + dt : 0;
            if (root.strapIdle > 0.3) {
                root.strapAngle = 0;
                root.strapSpin = 0;
                root.strapWas = null;
                running = false;
            }
        }
    }
    Item {
        id: strap
        z: 900
        visible: root.present && root.slide < 0.98 && root.charm !== "none"
        x: root.strapAt[0]
        y: root.strapAt[1]
        rotation: -root.strapAngle * 180 / Math.PI
        transformOrigin: Item.TopLeft
        // the string: pixels down to the charm
        Repeater {
            model: 6
            Rectangle {
                required property int index
                x: -root.k / 2
                y: index * root.strapLen / 6
                width: root.k
                height: Math.ceil(root.strapLen / 6) - (index % 2 ? 0 : 1)
                color: index % 2 ? root.trim : root.ink
            }
        }
        // the charm (the tuning): her, the other one, or a little thing
        PhoneCharm {
            visible: root.charm === "her" || root.charm === "other"
            x: -width / 2
            y: root.strapLen - root.k
            who: (root.charm === "other") !== root.hell ? "demon" : "angel"
            pixel: Math.max(1, Math.round(root.k * 0.75))
            tick: Math.round(root.strapAngle * 10)
        }
        PxIcon {
            visible: !["her", "other", "none"].includes(root.charm)
            x: -width / 2
            y: root.strapLen - root.k
            name: root.charm === "heart" ? "heart" : root.charm === "star" ? "star" : "ghost"
            pixel: Math.max(1, Math.round(root.k * 1.25))
            fill: root.trim
        }
    }

    // ---- the faces ----
    component Face: Item {
        id: face
        property var m: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        property real shade: 1
        // turned away: hidden — but a face that holds the pointer's press stays (see-through), or
        // the press would be cancelled under a quick hand (rebuild)
        property bool pressing: false
        property bool away: false
        visible: !away || pressing
        opacity: away ? 0 : 1
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11], m[12], m[13], m[14], m[15])
        }
        // the body: drag to turn it, a double click faces it to you (clicks beside it close it)
        MouseArea {
            id: body
            anchors.fill: parent
            z: -1
            cursorShape: root.held || root.turning ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressedChanged: face.pressing = pressed
            onPressed: m => root.turnStart(body, m.x, m.y)
            onPositionChanged: m => {
                if (pressed)
                    root.turnMove(body, m.x, m.y);
            }
            onReleased: root.turnEnd()
            onCanceled: root.turnEnd()
            onDoubleClicked: root.faceUp()
        }
    }
    // an edge of the shell: shaded, a lighter line where it meets the front
    component Edge: Face {
        id: edgeFace
        width: 1
        height: 1
        Rectangle {
            anchors.fill: parent
            color: root.shaded(root.shellColor, edgeFace.shade * 0.8 + 0.2)
        }
        Rectangle {
            width: parent.width
            height: root.k
            color: Qt.alpha(root.lit, 0.5 * edgeFace.shade)
        }
    }
    // a slab of the shell: the face, a pixel bevel, a darker rim
    component Slab: Rectangle {
        color: root.shellColor
        border.width: root.k
        border.color: root.ink
        // the metal shells: bands of light across, in whole pixels
        Repeater {
            model: root.metal ? [0.18, 0.24, 0.62] : []
            Rectangle {
                required property real modelData
                x: root.k
                y: Math.round(parent.height * modelData)
                width: parent.width - root.k * 2
                height: root.k * (modelData === 0.24 ? 1 : 2)
                color: Qt.alpha("#ffffff", 0.45)
            }
        }
        Rectangle {
            x: root.k
            y: root.k
            width: parent.width - root.k * 2
            height: root.k
            color: root.lit
        }
        Rectangle {
            x: root.k
            y: root.k
            width: root.k
            height: parent.height - root.k * 2
            color: root.lit
        }
    }

    // rhinestones over a face: round its edge, a heart, or all over
    component Gems: Item {
        id: gemsBox
        property string mode: "none"
        readonly property var spots: {
            const out = [], w = width, h = height, kk = root.k;
            if (mode === "edge") {
                for (let x = kk * 4; x < w - kk * 3; x += kk * 7)
                    out.push([x, kk * 3], [x, h - kk * 5]);
                for (let y = kk * 10; y < h - kk * 8; y += kk * 7)
                    out.push([kk * 3, y], [w - kk * 5, y]);
            } else if (mode === "heart") {
                for (let i = 0; i < 26; i++) {
                    const t = i / 26 * Math.PI * 2;
                    out.push([w / 2 + 16 * Math.pow(Math.sin(t), 3) * kk * 1.2, h * 0.7 - (13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t)) * kk * 1.2]);
                }
            } else if (mode === "full") {
                for (let y = kk * 4; y < h - kk * 4; y += kk * 6)
                    for (let x = kk * 4 + (y / (kk * 6)) % 2 * kk * 3; x < w - kk * 4; x += kk * 6)
                        out.push([x, y]);
            }
            return out;
        }
        Repeater {
            model: gemsBox.spots
            Rectangle {
                required property var modelData
                required property int index
                x: Math.round(modelData[0])
                y: Math.round(modelData[1])
                width: root.k * 2
                height: root.k * 2
                color: ["#ffffff", "#ffb3d9", "#a8ecff"][(index + root.twinkle) % 3]
                border.width: Math.max(1, root.k / 2)
                border.color: Qt.alpha(root.ink, 0.5)
            }
        }
    }
    // a broken screen: cracks from where it hit, in pixel lines
    component Cracks: Canvas {
        visible: PhoneLine.cracked
        renderStrategy: Canvas.Cooperative
        onVisibleChanged: if (visible)
            requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            if (!visible)
                return;
            c.strokeStyle = "rgba(255,255,255,0.8)";
            c.lineWidth = Math.max(1, root.k / 2);
            let seed = 7;
            const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
            const ox = width * 0.64, oy = height * 0.32;
            for (let i = 0; i < 9; i++) {
                let a = i / 9 * Math.PI * 2 + rnd() * 0.5, x = ox, y = oy;
                c.beginPath();
                c.moveTo(x, y);
                const n = 3 + Math.floor(rnd() * 4);
                for (let j = 0; j < n; j++) {
                    a += (rnd() - 0.5) * 0.9;
                    const len = (0.08 + rnd() * 0.18) * Math.max(width, height);
                    x += Math.cos(a) * len;
                    y += Math.sin(a) * len;
                    c.lineTo(Math.round(x), Math.round(y));
                }
                c.stroke();
            }
            c.strokeRect(ox - 3, oy - 3, 6, 6);
        }
    }

    Edge {
        id: baseBack
        Slab {
            anchors.fill: parent
            color: root.shaded(root.shellColor, 0.55 + baseBack.shade * 0.45)
            // the battery cover
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: parent.height * 0.55
                color: "transparent"
                border.width: root.k
                border.color: Qt.alpha(root.ink, 0.6)
            }
            Gems {
                anchors.fill: parent
                mode: root.gems === "full" ? "full" : "none"
            }
            PxText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.82
                kind: "tiny"
                text: "angelOS"
                color: Qt.alpha(root.ink, 0.7)
            }
        }
    }
    Edge {
        id: baseBottom
        // the charging port
        Rectangle {
            anchors.centerIn: parent
            width: root.k * 10
            height: Math.max(root.k, parent.height * 0.35)
            color: root.glass
        }
    }
    Edge {
        id: baseLeft
    }
    Edge {
        id: baseRight
    }
    Edge {
        id: lidTop
        Grip {
            anchors.fill: parent
        }
    }
    Edge {
        id: lidLeft
    }
    Edge {
        id: lidRight
    }

    // the antenna: a rod with a knob, pulled out by its knob
    Face {
        id: antennaFace
        Rectangle {
            x: root.k * 1.5
            y: root.k * 3
            width: root.k * 2
            height: Math.max(0, parent.height - root.k * 3)
            color: root.shaded(root.lit, 0.7)
            border.width: Math.max(1, root.k / 2)
            border.color: root.ink
        }
        Rectangle {
            width: parent.width
            height: root.k * 4
            color: root.trim
            border.width: Math.max(1, root.k / 2)
            border.color: root.ink
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -root.k * 2
            cursorShape: Qt.SizeVerCursor
            onPressedChanged: antennaFace.pressing = pressed
            onPositionChanged: m => {
                if (pressed)
                    root.pullAntenna(this, m.x, m.y);
            }
        }
    }

    // the hinge: eight strips and two round ends (rebuild)
    Repeater {
        id: hingeStrips
        model: 8
        Edge {
            required property int index
        }
    }
    Repeater {
        id: hingeEnds
        model: 2
        Face {
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.shaded(root.shellColor, 0.6)
                border.width: root.k
                border.color: root.ink
            }
        }
    }
    Edge {
        id: baseTop
    }
    Edge {
        id: lidBottom
    }

    // the base's front: the keys
    Face {
        id: baseFront
        Slab {
            anchors.fill: parent
        }
        PhoneKeys {
            // the flip: all of the base; the brick: under the screen; the taco: either side of it
            x: root.k * (root.taco ? 6 : root.bar ? 7 : 5)
            y: root.k * (root.taco ? 9 : root.bar ? 124 : 5)
            width: parent.width - x * 2
            height: parent.height - y - root.k * (root.taco ? 9 : 8)
            layout: root.taco ? "taco" : root.bar ? "brick" : "flip"
            gapW: root.k * 104
            phone: root
        }
        // the bars' earpiece and name (the flip has them on the lid)
        Rectangle {
            visible: root.bar && !root.taco
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.k * 5
            width: root.k * 18
            height: root.k * 2
            color: root.glass
        }
        PxText {
            visible: root.bar
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.taco ? parent.height - root.k * 8 : root.k * 113
            text: "angelOS"
            kind: "tiny"
            color: root.trim
        }
        // the microphone hole
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.k * 3
            width: root.k * 4
            height: root.k
            color: root.glass
        }
    }

    // the lid's back: the little outside screen, a heart in chrome
    Face {
        id: lidBack
        Slab {
            anchors.fill: parent
            color: root.shaded(root.shellColor, 0.6 + lidBack.shade * 0.4)
        }
        // the lid's free edge (the far end from the hinge) pulls it open; the rest turns the phone
        Grip {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * 0.22
            z: 2
        }
        Rectangle {
            id: outer
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.22
            width: parent.width * 0.56
            height: parent.height * 0.26
            color: root.glass
            border.width: root.k
            border.color: root.ringingHere && root.buzzTick % 14 < 7 ? "#ffffff" : root.trim
            // the magic ball's answer (a spin or a shake of the shut phone)
            PxText {
                visible: root.answer !== "" && !root.ringingHere
                anchors.centerIn: parent
                width: parent.width - root.k * 4
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.answer
                kind: "tiny"
                color: Theme.mix(root.trim, "#ffffff", 0.6)
            }
            Cracks {
                anchors.fill: parent
                z: 3
            }
            // the battery in its corner; dead, the little screen is dark
            PhoneBattery {
                visible: !PhoneLine.dead
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.k * 2
                color: Theme.mix(root.trim, "#ffffff", 0.4)
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.k
                z: 4
                visible: PhoneLine.dead
                color: root.glass
            }
            // who rings: her face and name, blinking
            Column {
                visible: root.ringingHere
                anchors.centerIn: parent
                spacing: root.k
                PhoneCharm {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: PhoneLine.herCall || PhoneLine.call && PhoneLine.call.kind === "prank" && (PhoneLine.call.voice === "angel" || PhoneLine.call.voice === "demon")
                    who: PhoneLine.call ? PhoneLine.call.who : "angel"
                    pixel: Math.max(1, Math.round(root.k * 0.75))
                    tick: Math.floor(root.buzzTick / 4)
                }
                PxIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !PhoneLine.herCall && !(PhoneLine.call && PhoneLine.call.kind === "prank" && (PhoneLine.call.voice === "angel" || PhoneLine.call.voice === "demon"))
                    name: PhoneLine.call && PhoneLine.call.voice === "bark" ? "skull" : PhoneLine.call && PhoneLine.call.voice === "robot" ? "bot" : "bell"
                    fill: root.trim
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: PhoneLine.call ? PhoneLine.call.name : ""
                    kind: "tiny"
                    color: Theme.mix(root.trim, "#ffffff", root.buzzTick % 14 < 7 ? 0.7 : 0.3)
                }
            }
            Column {
                visible: !root.ringingHere && root.answer === ""
                anchors.centerIn: parent
                spacing: root.k
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, "hh:mm")
                    kind: "title"
                    color: Theme.mix(root.trim, "#ffffff", 0.5)
                }
                // missed calls and her messages waiting
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: PhoneLine.missedCount + PhoneLine.unread > 0
                    spacing: root.k * 2
                    PxIcon {
                        visible: PhoneLine.missedCount > 0
                        anchors.verticalCenter: parent.verticalCenter
                        name: "phone"
                        fill: Theme.danger
                    }
                    PxText {
                        visible: PhoneLine.missedCount > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: PhoneLine.missedCount
                        kind: "tiny"
                        color: Theme.mix(root.trim, "#ffffff", 0.3)
                    }
                    PxIcon {
                        visible: PhoneLine.unread > 0
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chat"
                        fill: root.trim
                    }
                    PxText {
                        visible: PhoneLine.unread > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: PhoneLine.unread
                        kind: "tiny"
                        color: Theme.mix(root.trim, "#ffffff", 0.3)
                    }
                }
            }
        }
        // the logo, or the sticker on its place; the rhinestones over all
        PxIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            y: outer.y + outer.height + root.k * 8
            name: root.sticker === "none" ? (root.hell ? "heartHorns" : "heart") : root.sticker
            pixel: root.k * 2
            fill: root.trim
        }
        Gems {
            anchors.fill: parent
            mode: root.gems
        }
    }

    // the lid's front: the earpiece, the screen, the name under it
    Face {
        id: lidFront
        Slab {
            anchors.fill: parent
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.k * 5
            width: root.k * 16
            height: root.k * 2
            color: root.glass
        }
        // the band over the screen (the earpiece) pulls the lid
        Grip {
            width: parent.width
            height: root.k * 10
        }
        // the glass round the screen (on the bars it moves to the base's front)
        Rectangle {
            parent: root.bar ? baseFront : lidFront
            x: root.taco ? (parent.width - width) / 2 : root.bar ? root.k * 5 : root.k * 4
            y: root.taco ? (parent.height - height) / 2 : root.bar ? root.k * 12 : root.k * 10
            width: root.bar ? root.screenW + root.k * 6 : parent.width - root.k * 8
            height: root.screenH + root.k * 6
            color: root.glass
            Item {
                id: lcd
                // the brick's LCD: green and one colour, as it was
                layer.enabled: root.model === "3310"
                layer.effect: MultiEffect {
                    colorization: 1
                    colorizationColor: "#9aac5c"
                    brightness: 0.08
                    contrast: 0.35
                }
                x: root.k * 3
                y: root.k * 3
                width: root.screenW
                height: root.screenH
                clip: true
                Rectangle {
                    anchors.fill: parent
                    color: root.lightLcd ? "#d2dca6" : root.hell ? Theme.hellBody : Theme.face
                }
                // upright: the phone's pages; on its side: PhoneSide, turned to read upright
                PhoneScreen {
                    id: screen
                    anchors.centerIn: parent
                    width: root.k * 90
                    height: root.k * 91
                    phone: root
                    opacity: Math.max(0, 1 - root.turn * 2)
                    visible: opacity > 0
                }
                PhoneSide {
                    id: side
                    anchors.centerIn: parent
                    width: root.k * 187
                    height: root.k * 154
                    rotation: 90
                    phone: root
                    opacity: Math.max(0, root.turn * 2 - 1)
                    visible: opacity > 0
                }
                // the torch: the screen all white too; the cracks over everything
                Rectangle {
                    anchors.fill: parent
                    visible: root.torch
                    color: "#ffffff"
                }
                Cracks {
                    anchors.fill: parent
                }
                // the screen off, and the line of light as it comes on
                Rectangle {
                    anchors.fill: parent
                    color: root.glass
                    opacity: 1 - root.power
                    visible: opacity > 0
                }
                Rectangle {
                    visible: root.power > 0 && root.power < 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Math.max(root.k, parent.height * root.power)
                    color: "#ffffff"
                    opacity: (1 - root.power) * 0.8
                }
                // dead: a key shows the empty cell a moment (the charging one while it fills)
                Column {
                    visible: deadFlash.running || PhoneLine.dead && PhoneLine.plugged
                    anchors.centerIn: parent
                    spacing: root.k * 3
                    PhoneBattery {
                        anchors.horizontalCenter: parent.horizontalCenter
                        scale: 2
                        color: Theme.mix(root.trim, "#ffffff", 0.4)
                    }
                    PxText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !PhoneLine.plugged
                        text: PhoneLine.tr(PL.battery.dead)
                        kind: "tiny"
                        color: Theme.mix(root.trim, "#ffffff", 0.4)
                    }
                }
            }
        }
        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.k * 3
            text: "angelOS"
            kind: "tiny"
            color: root.trim
        }
    }
}
