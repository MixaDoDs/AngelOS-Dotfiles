pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "P5Lines.js" as Lines

// The P5 window's character, part of the background like Joker in P5's menus, big and cut by the
// window's edges: the owner's dynamic poses (dolls/, made by assets/settings-p5/dolls/import.py
// from ~/Pictures/AngelOS_Dynamic_Poses) — the angel in the light theme, a sister of the circles
// per section in the dark one. A pose is a little puppet: the arms and legs turn a few degrees
// round their joints, the pupils follow the pointer, her head bobs as she talks; it all
// moves in hard steps. Every section frames her its own way (`shots`) and every tab anew
// (another pose, a closer or a tilted shot). She reacts: a click on her, carrying her off (drag),
// a value changed (flap), the selected row (lookY); what she says goes out through `say` (the
// window's speech plate). Motion off: no idle motion, cuts.
Item {
    id: root

    // who can be in a shot (picked per section by its name)
    property var cast: ["angel"]
    property var shots: ({})
    property real zone: 0.24
    // wide: where her right edge and her top go (this item's coordinates); -1: by `zone` and the shot
    property real edgeX: -1
    property real topY: 0
    // where her eyes must be (this item's coordinates; empty: anywhere): never under the menu, the
    // card or the title — she turns to face it and moves until they are in (the owner, 23.10:
    // «глазки было видно у всех всегда»)
    property rect eyeZone: Qt.rect(0, 0, 0, 0)
    property color accent: "#ff2d8a"
    property color black: "#000000"
    property color paper: "#ffffff"
    // 0 … 1 as she comes in: a black silhouette, then the accent, then her colours
    property real reveal: 1
    property bool still: false
    // at rest (decisions №16–17, 25.10) she keeps still, and with `restSolid` set she stands as a
    // flat silhouette, her eyes still lit; a move, a gesture, a word or the pointer on her wakes
    // her into her colours for a while
    property color restSolid: "transparent"
    readonly property bool awake: wakeT.running || run.running || gRun.running || talk.running || carried || hand.hovering
    readonly property bool resting: !awake && restSolid.a > 0 && reveal >= 0.85
    function wake() {
        wakeT.restart();
    }
    Timer {
        id: wakeT
        interval: 2500
    }
    // the selected row's pull, in fractions of the window
    property real lookY: 0
    // the pointer over the window, in this item's coordinates (x < 0: none)
    property point gaze: Qt.point(-1, -1)
    signal say(string text)
    // the figure at art resolution, for the window's silhouette wipe (P5Slash)
    readonly property alias sprite: sprite

    readonly property bool en: I18n.english

    // ---- the dolls ----
    readonly property var everyone: ["angel", "limbo", "heresy", "fraud", "greed"]
    property var docs: ({})
    Instantiator {
        model: root.everyone
        delegate: FileView {
            required property string modelData
            path: Quickshell.shellDir + "/modules/settings/p5/dolls/" + modelData + "/dolls.json"
            onLoaded: {
                try {
                    const d = Object.assign({}, root.docs);
                    d[modelData] = JSON.parse(text());
                    root.docs = d;
                    if (root.shot)
                        root.settle(root.shot);
                } catch (e) {
                    console.warn("P5Doll: " + modelData + ": " + e);
                }
            }
        }
    }
    function hash(s) {
        let h = 7;
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 100003;
        return h;
    }
    // who sits in which section when they share (the dark): each sister where her sin is at
    // home — Vera doubting the system (and the angel's own section), Lucky hoarding devices and
    // programs, Lisa greeting and dressing up (the show, the fakes), the network and the stream,
    // Sola in the quiet of windows, search and accessibility
    readonly property var seats: ({
            "main": "fraud",
            "system": "heresy",
            "devices": "greed",
            "network": "fraud",
            "personal": "fraud",
            "windows": "limbo",
            "apps": "greed",
            "stream": "fraud",
            "a11y": "limbo",
            "game": "heresy",
            "angelos": "heresy",
            "search": "limbo"
        })
    function whoFor(name) {
        if (cast.length < 2)
            return cast[0] || "angel";
        return cast.includes(seats[name]) ? seats[name] : cast[hash(name) % cast.length];
    }
    // her poses dealt out, never the same art twice while there are enough (the owner, 23.10:
    // «сеть» и «персонализация» с одним артом — «халтурно»): first one each to her sections' first
    // tabs, then the other tabs in a row — section by section, tab by tab
    property var tabCounts: ({})
    function poseFor(who, name, v) {
        const d = docs[who];
        if (!d)
            return null;
        const n = d.poses.length;
        const mine = Object.keys(shots).filter(s => whoFor(s) === who);
        const k = mine.indexOf(name);
        if (k < 0)
            return d.poses[(hash(name + who) + (v || 0) * 5) % n];
        if (!v)
            return d.poses[k % n];
        let at = mine.length;
        for (let i = 0; i < k; i++)
            at += Math.max(0, (tabCounts[mine[i]] || 1) - 1);
        return d.poses[(at + v - 1) % n];
    }

    // ---- the shot on screen ----
    property string shot: ""
    property int variant: 0
    property string who: "angel"
    property var pose: null
    readonly property var layers: pose ? pose.layers : []
    // a layer of the pose on screen
    function partOf(id) {
        return shownLayers.find(l => l.id === id) || null;
    }
    function atlasOf(w, p) {
        return p ? Qt.resolvedUrl("dolls/" + w + "/pose" + (p.n < 10 ? "0" : "") + p.n + ".png") : "";
    }
    // the pose on screen: the one asked for once its atlas is read (in the background: a pose
    // read at once stopped the window for a frame); its layers are windows into that one picture
    property var shownPose: null
    property url shownAtlas: ""
    readonly property var shownLayers: shownPose ? shownPose.layers : []
    // her eyes on the texture (288×416, the canvas from -16): the two pupils' centres (one twice
    // when only one is drawn), for the silhouettes — they keep burning eyes (the owner, 23.10:
    // «глазки было видно у всех всегда»)
    readonly property vector4d eyeSpots: {
        const e = shownLayers.filter(l => l.id.startsWith("pupil_") && l.pivot && (l.pivot[0] || l.pivot[1])).map(l => l.pivot);
        if (!e.length)
            return Qt.vector4d(0, 0, 0, 0);
        const b = breathY + talkY, a = e[0], c = e[e.length - 1];
        return Qt.vector4d((a[0] + pupX + 16) / 288, (a[1] + pupY + b + 16) / 416, (c[0] + pupX + 16) / 288, (c[1] + pupY + b + 16) / 416);
    }
    readonly property size eyeR: shownLayers.some(l => l.id.startsWith("pupil_") && l.pivot && (l.pivot[0] || l.pivot[1])) ? Qt.size(7 / 288, 6 / 416) : Qt.size(0, 0)
    Image {
        id: preload
        visible: false
        asynchronous: true
        source: root.atlasOf(root.who, root.pose)
        onStatusChanged: root.adopt()
    }
    function adopt() {
        if (preload.status !== Image.Ready || shownAtlas === preload.source)
            return;
        shownPose = pose;
        shownAtlas = preload.source;
        m = next;
    }
    // the frame for the pose asked for: it goes on screen with that pose, not before (the old pose
    // in the new frame stood for a few frames with her eyes under the menu)
    property var next: m
    function frame(name) {
        next = matrix(name, variant);
        if (pose === shownPose)
            m = next;
    }

    function shotOf(name, v) {
        // (a tab: another pose in the same place — the owner, 23.10: «новая поза, место то же»)
        return shots[name] || shots.main || {
            "a": [0.5, 0.5],
            "dx": 0,
            "wy": 0.6,
            "s": 0.95,
            "r": 0
        };
    }
    function matrix(name, v) {
        const sh = shotOf(name, v), W = width, H = height;
        const mouth = layers.find(l => l.id === "mouth");
        const a = sh.a === "face" ? (mouth ? [mouth.pivot[0] / 256, mouth.pivot[1] / 384] : [0.5, 0.35]) : sh.a || [0.5, 0.5];
        // whole art pixels on screen: the figure stays crisp (the canvas is 384 tall, she fills it)
        // (a close shot no taller than one and a half windows: whole pixels jump a lot)
        const k = Math.max(1, Math.min(Math.round(sh.s * H * 1.15 / 384), Math.floor(H * 1.5 / 384)));
        if (edgeX >= 0) {
            // one size everywhere, her canvas's right edge (turned) at edgeX, its top at topY: she
            // leans onto the card the same bit in every section, never further
            const kk = Math.max(1, Math.round(H * 1.15 / 384)), r = Math.max(-6, Math.min(6, sh.r || 0));
            const c = Math.cos(r * Math.PI / 180), sn = Math.sin(r * Math.PI / 180);
            const eyes = layers.filter(l => l.id.startsWith("pupil_") && l.pivot && (l.pivot[0] || l.pivot[1])).map(l => l.pivot);
            const pad = 10 * kk;
            // her place facing one way (ff), and the box round her eyes on screen
            const place = ff => {
                const at = q => [(q[0] - 128) * ff * kk * c - q[1] * kk * sn, (q[0] - 128) * ff * kk * sn + q[1] * kk * c];
                const corners = [[0, 0], [256, 0], [0, 384], [256, 384]].map(at);
                const x = edgeX - Math.max(...corners.map(q => q[0])), y = topY - Math.min(...corners.map(q => q[1]));
                const e = eyes.map(at);
                return {
                    "f": ff,
                    "x": x,
                    "y": y,
                    "lo": x + Math.min(...e.map(q => q[0])) - pad,
                    "hi": x + Math.max(...e.map(q => q[0])) + pad,
                    "up": y + Math.min(...e.map(q => q[1])) - pad,
                    "dn": y + Math.max(...e.map(q => q[1])) + pad
                };
            };
            const z = eyeZone;
            const off = p => Math.max(0, z.x - p.lo) + Math.max(0, p.hi - z.x - z.width);
            let p = place(sh.f || 1);
            if (eyes.length && z.width > 0 && z.height > 0) {
                const q = place(-p.f);
                if (off(q) < off(p))
                    p = q;
                // (past the field the card hides her: moving either way never covers its words)
                p.x += p.lo < z.x ? z.x - p.lo : p.hi > z.x + z.width ? z.x + z.width - p.hi : 0;
                p.y += p.up < z.y ? z.y - p.up : p.dn > z.y + z.height ? z.y + z.height - p.dn : 0;
            }
            return {
                "x": p.x,
                "y": p.y,
                "r": r,
                "k": kk,
                "f": p.f,
                "ax": 128,
                "ay": 0
            };
        }
        return {
            "x": (zone + sh.dx) * W,
            "y": sh.wy * H,
            "r": sh.r || 0,
            "k": k,
            "f": sh.f || 1,
            "ax": a[0] * 256,
            "ay": a[1] * 384
        };
    }

    // the camera: a base matrix and an offset (ox, oy px, dr degrees, z zoom) on it
    property var m: ({
            "x": 0,
            "y": 0,
            "r": 0,
            "k": 1,
            "f": 1,
            "ax": 0,
            "ay": 0
        })
    property real ox: 0
    property real oy: 0
    property real dr: 0
    property real zoom: 1

    // a few keyframes [{ox, oy, dr, z}] on the camera, in `steps` jumps over `ms`
    property var keys: []
    property int steps: 4
    property real t: 0
    onTChanged: {
        if (!keys.length)
            return;
        const q = Math.min(1, Math.floor(t * steps) / steps) * (keys.length - 1);
        const i = Math.min(keys.length - 2, Math.floor(q)), f = q - i;
        const a = keys[i], b = keys[i + 1];
        ox = a.ox + (b.ox - a.ox) * f;
        oy = a.oy + (b.oy - a.oy) * f;
        dr = a.dr + (b.dr - a.dr) * f;
        zoom = a.z + (b.z - a.z) * f;
    }
    NumberAnimation {
        id: run
        target: root
        property: "t"
        from: 0
        to: 1
    }
    function play(frames, ms, n) {
        run.stop();
        keys = frames.map(k => ({
                    "ox": k[0] || 0,
                    "oy": k[1] || 0,
                    "dr": k[2] || 0,
                    "z": k[3] === undefined ? 1 : k[3]
                }));
        steps = n;
        run.duration = ms;
        wake();
        t = 0;
        run.start();
    }
    function settle(name) {
        run.stop();
        keys = [];
        who = whoFor(name);
        pose = poseFor(who, name, variant);
        Qt.callLater(adopt);
        frame(name);
        ox = 0;
        oy = 0;
        dr = 0;
        zoom = 1;
    }

    // ---- what she does ----
    // to a shot (a section, `v` its tab's variant), under the window's wipe; dir +1 down the
    // list, -1 up: she lands from that side in hard steps
    function go(name, dir, cut, v) {
        const first = shot === "";
        const before = who;
        shot = name;
        variant = v || 0;
        settle(name);
        if (who !== "angel" && !sistersSeen.includes(who))
            sistersSeen = sistersSeen.concat([who]);
        if (still || cut || !width)
            return;
        if (first) {
            play([[0, height * 0.6, -10, 1.25], [0, -height * 0.03, 2, 1.04], [0, 0, 0, 1]], 300, 5);
            gesture("wave");
            return;
        }
        play([[dir * width * 0.07, dir * height * 0.02, dir * 4, 1.08], [-dir * width * 0.008, 0, -dir * 1, 0.99], [0, 0, 0, 1]], 150, 3);
        gesture(before !== who ? "wave" : "jolt");
    }
    // a value changed: an arm swings that way, a smile
    function flap(dir) {
        if (still)
            return;
        gesture(dir < 0 ? "flapL" : "flapR");
        if (Math.random() < 0.12)
            speak(Lines.react(who, "flap", en));
    }
    // a line in the plate, her head bobbing while it types (the mouth stays as drawn: the pack's
    // other mouths sat wrong on many poses, and the drawn one has skin in it — it won't stretch)
    function speak(text) {
        if (!text)
            return;
        say(text);
        if (!still)
            talk.left = Math.min(14, 4 + Math.round(text.length / 6));
        quiet.restart();
    }
    Timer {
        id: talk
        property int left: 0
        running: left > 0
        repeat: true
        interval: 110
        onTriggered: {
            left--;
            root.talkY = left > 0 && left % 2 ? -1 : 0;
        }
    }
    // a quiet minute: she says something of her own
    Timer {
        id: quiet
        running: root.visible && root.shot !== ""
        interval: 60000
        onTriggered: root.speak(Lines.react(root.who, "idle", root.en))
    }
    // the sisters she has been in the dark this session (the angel remembers them, a few times)
    property var sistersSeen: []

    // ---- the puppet ----
    // a beat drives the idle (8 a second); limbs swing in steps on their own periods
    property int beat: 0
    Timer {
        running: root.visible && !root.still && root.awake
        repeat: true
        interval: 125
        onTriggered: {
            root.beat = (root.beat + 1) % 840;
            root.aim();
        }
    }
    function swing(period, phase) {
        const p = ((beat + phase) % period) / period;
        // a triangle in 4 steps a side: -1 … 1 … -1
        const tri = p < 0.5 ? p * 4 - 1 : 3 - p * 4;
        return Math.round(tri * 2) / 2;
    }
    readonly property real breathY: still ? 0 : (beat % 16 < 8 ? 0 : -1)
    // accents on top of the idle: degrees per limb, played by `gesture`
    property real gArmF: 0
    property real gArmB: 0
    property real gLegF: 0
    property real gLegB: 0
    property var gKeys: []
    property real gt: 0
    onGtChanged: {
        if (!gKeys.length)
            return;
        const q = Math.min(1, Math.floor(gt * 6) / 6) * (gKeys.length - 1);
        const i = Math.min(gKeys.length - 2, Math.floor(q)), f = q - i;
        const a = gKeys[i], b = gKeys[i + 1];
        gArmF = a[0] + (b[0] - a[0]) * f;
        gArmB = a[1] + (b[1] - a[1]) * f;
        gLegF = a[2] + (b[2] - a[2]) * f;
        gLegB = a[3] + (b[3] - a[3]) * f;
    }
    NumberAnimation {
        id: gRun
        target: root
        property: "gt"
        from: 0
        to: 1
    }
    // the joints are drawn with a little overlap only: a few degrees, short (the poses' README)
    readonly property var gestures: ({
            "wave": [[0, 0, 0, 0], [-4, 2, 0, 0], [4, -2, 1, 0], [-4, 2, 0, 0], [0, 0, 0, 0]],
            "jolt": [[0, 0, 0, 0], [4, -4, -2, 2], [-2, 2, 1, -1], [0, 0, 0, 0]],
            "flapL": [[0, 0, 0, 0], [-4, -3, 0, 0], [0, 0, 0, 0]],
            "flapR": [[0, 0, 0, 0], [4, 3, 0, 0], [0, 0, 0, 0]],
            "kick": [[0, 0, 0, 0], [2, -2, -4, 2], [0, 0, 0, 0]],
            "squirm": [[0, 0, 0, 0], [4, -4, 3, -3], [-4, 4, -3, 3], [4, -4, 3, -3], [0, 0, 0, 0]]
        })
    function gesture(kind) {
        if (still || !gestures[kind])
            return;
        gRun.stop();
        wake();
        gKeys = gestures[kind];
        gRun.duration = 120 * gKeys.length;
        gt = 0;
        gRun.start();
    }
    readonly property real armF: (still ? 0 : swing(16, 0) * 1.5) + gArmF
    readonly property real armB: (still ? 0 : swing(20, 7) * 1.5) + gArmB
    readonly property real legF: (still ? 0 : swing(28, 3) * 0.75) + gLegF
    readonly property real legB: (still ? 0 : swing(24, 13) * 0.75) + gLegB

    property real talkY: 0

    readonly property real angle: m.r + dr + (still ? 0 : [0, 0.5, 1, 1, 0.5, 0, -0.5, -0.5][Math.floor(beat / 4) % 8])
    // a point of this item on her canvas (the camera undone; the sprite itself is never moved)
    function toArt(x, y) {
        const a = -angle * Math.PI / 180;
        const px = x - (m.x + ox + dragX), py = y - (m.y + oy + dragY + lookY * height);
        const rx = px * Math.cos(a) - py * Math.sin(a), ry = px * Math.sin(a) + py * Math.cos(a);
        return Qt.point(rx / (m.f * m.k * zoom) + m.ax, ry / (m.k * zoom) + m.ay - breathY - talkY);
    }

    // the pupils: an art pixel towards the pointer (or the selected row), none past the eye
    property real pupX: 0
    property real pupY: 0
    function aim() {
        const p = partOf("pupil_left") || partOf("pupil_right");
        if (!p)
            return;
        let dx = 0, dy = 0;
        if (gaze.x >= 0) {
            const q = toArt(gaze.x, gaze.y);
            const ex = q.x - p.pivot[0], ey = q.y - p.pivot[1];
            dx = Math.abs(ex) > 6 ? Math.sign(ex) : 0;
            dy = Math.abs(ey) > 6 ? Math.sign(ey) : 0;
        } else {
            // the card is on her right; the row picked pulls the eyes up or down
            dx = m.f;
            dy = lookY > 0.004 ? 1 : lookY < -0.004 ? -1 : 0;
        }
        pupX = dx;
        pupY = dy;
    }
    onGazeChanged: aim()
    onLookYChanged: aim()

    // ---- poked and carried off ----
    property int pokes: 0
    property real dragX: 0
    property real dragY: 0
    property bool carried: false
    function poke() {
        pokes++;
        gesture(pokes % 3 === 0 ? "squirm" : pokes % 2 ? "jolt" : "kick");
        play([[0, 0, 0, 1], [m.k * 3, -m.k * 4, 3, 1.03], [0, 0, 0, 1]], 200, 3);
        if (pokes === 1 || Math.random() < 0.5)
            speak(Lines.react(who, "poke", en));
        poked();
    }
    signal poked
    MouseArea {
        id: hand
        anchors.fill: parent
        cursorShape: carried ? Qt.ClosedHandCursor : hovering ? Qt.OpenHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        property bool hovering: false
        property point from
        // only on her: the box of her body, a little inside; elsewhere the press goes on
        // to what is under her (the window's background)
        function onHer(x, y) {
            const b = root.partOf("base");
            if (!b || !b.src)
                return false;
            const q = root.toArt(x, y);
            const ix = b.src[2] * 0.15, iy = b.src[3] * 0.1;
            return q.x > b.at[0] + ix && q.x < b.at[0] + b.src[2] - ix && q.y > b.at[1] + iy && q.y < b.at[1] + b.src[3] - iy;
        }
        onPositionChanged: mouse => {
            if (!pressed) {
                hovering = onHer(mouse.x, mouse.y);
                return;
            }
            const dx = mouse.x - from.x, dy = mouse.y - from.y;
            if (!root.carried && Math.hypot(dx, dy) > Theme.u * 6) {
                root.carried = true;
                root.gesture("squirm");
                root.speak(Lines.react(root.who, "drag", root.en));
            }
            if (root.carried) {
                // she follows in whole art pixels, a little behind
                const k = root.m.k * 2;
                root.dragX = Math.round(dx / k) * k;
                root.dragY = Math.round(dy / k) * k;
            }
        }
        onPressed: mouse => {
            if (!onHer(mouse.x, mouse.y)) {
                mouse.accepted = false;
                return;
            }
            from = Qt.point(mouse.x, mouse.y);
        }
        onReleased: {
            if (!root.carried) {
                root.poke();
                return;
            }
            root.carried = false;
            // back to her place in steps, a bump at the end
            const x = root.dragX, y = root.dragY;
            root.dragX = 0;
            root.dragY = 0;
            if (!root.still)
                root.play([[x, y, x > 0 ? 8 : -8, 1], [-x * 0.08, -y * 0.08, x > 0 ? -3 : 3, 1.02], [0, 0, 0, 1]], 260, 5);
            root.gesture("jolt");
            root.speak(Lines.react(root.who, "drop", root.en));
        }
        onExited: hovering = false
    }

    onWidthChanged: if (shot && !run.running)
        settle(shot)
    onHeightChanged: if (shot && !run.running)
        settle(shot)
    onCastChanged: if (shot)
        settle(shot)
    // (the frame only: a move under way plays on)
    onEdgeXChanged: if (shot)
        frame(shot)
    onEyeZoneChanged: if (shot)
        frame(shot)

    // ---- the figure, in art pixels ----
    Item {
        id: sprite
        width: 256
        height: 384
        Item {
            id: figure
            width: 256
            height: 384
            y: root.breathY + root.talkY
            Repeater {
                model: root.shownLayers
                Item {
                    id: part
                    required property var modelData
                    readonly property string id_: modelData.id
                    visible: !!modelData.src && !modelData.hidden
                    x: modelData.at ? modelData.at[0] : 0
                    y: modelData.at ? modelData.at[1] : 0
                    width: modelData.src ? modelData.src[2] : 0
                    height: modelData.src ? modelData.src[3] : 0
                    clip: true
                    // the whole atlas (one picture read once), shifted to this layer's piece
                    Image {
                        x: part.modelData.src ? -part.modelData.src[0] : 0
                        y: part.modelData.src ? -part.modelData.src[1] : 0
                        source: part.modelData.src ? root.shownAtlas : ""
                        asynchronous: true
                        smooth: false
                    }
                    // (as far as this limb turns without tearing her: import.py tries it, `give` of 4°)
                    readonly property real turn: (id_ === "arm_front" ? root.armF : id_ === "arm_back" ? root.armB : id_ === "leg_front" ? root.legF : id_ === "leg_back" ? root.legB : 0) * (modelData.give === undefined ? 1 : modelData.give / 4)
                    readonly property bool pupil: id_.startsWith("pupil_")
                    transform: [
                        Rotation {
                            origin.x: part.modelData.pivot ? part.modelData.pivot[0] - part.x : 0
                            origin.y: part.modelData.pivot ? part.modelData.pivot[1] - part.y : 0
                            angle: part.turn
                        },
                        Translate {
                            x: part.pupil ? root.pupX : 0
                            y: part.pupil ? root.pupY : 0
                        }
                    ]
                }
            }
        }
    }

    Translate {
        id: camA
        x: -root.m.ax - 16
        y: -root.m.ay - 16
    }
    Scale {
        id: camB
        xScale: root.m.f * root.m.k * root.zoom
        yScale: root.m.k * root.zoom
    }
    Rotation {
        id: camC
        angle: root.angle
    }
    Translate {
        id: camD
        x: root.m.x + root.ox + root.dragX
        y: root.m.y + root.oy + root.dragY + root.lookY * root.height
    }
    // ---- the smear (Spider-Verse's trick for moves on twos): each jump she makes leaves copies of
    // her behind, along it, in the accent, the second accent and black — a print off register —
    // gone in a few frames ----
    property real trailX: 0
    property real trailY: 0
    property real trailA: 0
    property point lastAt: Qt.point(0, 0)
    FrameAnimation {
        running: root.visible && !root.still && (root.awake || root.trailA > 0)
        onTriggered: {
            const p = root.mapToItem(root.parent, camD.x, camD.y);
            const dx = p.x - root.lastAt.x, dy = p.y - root.lastAt.y;
            root.lastAt = p;
            if (Math.abs(dx) + Math.abs(dy) > Theme.u * 3 && Math.abs(dx) + Math.abs(dy) < root.height) {
                root.trailX = dx;
                root.trailY = dy;
                root.trailA = 1;
            } else if (root.trailA > 0) {
                root.trailA = root.trailA < 0.08 ? 0 : root.trailA * 0.55;
            }
        }
    }
    Repeater {
        model: 3
        Item {
            id: ghost
            required property int index
            visible: root.trailA > 0
            opacity: root.trailA * [0.75, 0.5, 0.3][index]
            width: 288
            height: 416
            transform: [camA, camB, camC, camD, behind]
            Translate {
                id: behind
                x: -root.trailX * (ghost.index + 1) * 0.5
                y: -root.trailY * (ghost.index + 1) * 0.5
            }
            Flat {
                solid: [root.accent, Theme.mix(root.accent, root.paper, 0.5), root.black][ghost.index]
            }
        }
    }
    // the camera: art pixels -> the window; under her, her hard shadow in the accent (P5's cut-outs)
    Item {
        id: cam
        width: 288
        height: 416
        // (one camera for both her views: this one and the one over the card)
        transform: [camA, camB, camC, camD]
        Flat {
            x: 3
            y: 3
            solid: root.resting ? "transparent" : root.who === "angel" ? root.black : root.paper
        }
        ShaderEffectSource {
            id: tex
            width: parent.width
            height: parent.height
            sourceItem: sprite
            hideSource: true
            smooth: false
            live: true
            // a little room round the canvas: the limbs turn past it
            sourceRect: Qt.rect(-16, -16, 288, 416)
        }
        // over the colours (they stay under it, the texture drawn): flat
        Flat {
            solid: root.cutIn
            eyes: root.eyeSpots
            eyeR: root.eyeR
        }
    }
    // a strip of her drawn again over the card's edge (the owner: «чутка на настройки находили»,
    // as P5's figures break the menu's frame): `front` is an item over the card, `frontBand` the
    // strip in this item's coordinates; the rest of her stays behind the card
    readonly property color cutIn: reveal < 0.5 ? black : reveal < 0.85 ? accent : resting ? restSolid : "transparent"
    property Item front: null
    property rect frontBand: Qt.rect(0, 0, 0, 0)
    Item {
        id: frontClip
        parent: root.front
        visible: !!root.front && root.frontBand.width > 0
        x: root.frontBand.x
        y: root.frontBand.y
        width: root.frontBand.width
        height: root.frontBand.height
        clip: true
        Item {
            x: -frontClip.x
            y: -frontClip.y
            width: 288
            height: 416
            transform: [camA, camB, camC, camD]
            Flat {
                solid: root.cutIn
                eyes: root.eyeSpots
                eyeR: root.eyeR
            }
        }
    }
    // flat as P5 draws Joker: the angel black, accent and paper; a sister black, accent and a
    // pale accent (the owner, 23.10: «плоские в стиле P5»); cut by brightness, her own way
    component Flat: ShaderEffect {
        width: 288
        height: 416
        property var source: tex
        readonly property bool angel: root.who === "angel"
        property color dark: root.black
        property color mid: root.accent
        property color light: angel ? root.paper : Theme.mix(root.accent, root.paper, 0.55)
        property color solid: "transparent"
        property real cut1: angel ? 0.5 : 0.2
        property real cut2: angel ? 0.84 : 0.55
        property vector4d eyes: Qt.vector4d(0, 0, 0, 0)
        property size eyeR: Qt.size(0, 0)
        property color glow: root.paper
        fragmentShader: Qt.resolvedUrl("../../../shaders/p5_flat.frag.qsb")
    }
}
