pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import "../y2k/AngelSpriteMini.js" as AngelMini

// The setup wizard's life over its stage (SetupAssistant), drawn in pixels: now and then one
// random effect — a trail of sparkles across the screen, a feather falling through, the angel
// peeking in from an edge, pixels twinkling in the ground — a red/blue split of the title for a
// blink (the assistant draws it: `glitched`), the step change (the question breaks into blocks of
// its ground and comes back out, or slides in) and the gloss passing over the cards (SetupGloss,
// one at a time). What plays how often: data/setup-effects.json, one table.
//
// It all moves on the render thread (animators: XAnimator, YAnimator, OpacityAnimator and the
// pauses between them), frame by frame with the screen, smooth whatever the GUI thread is busy
// with; what goes in pixel steps (the trail, the blocks, the split) steps a whole number of the
// screen's frames (`stepMs`: hz/12 frames — 12 at 144 Hz, 5 at 60 Hz). The step changes are baked
// beforehand into pictures (scripts/setup-fx-bake.py, once per screen size and theme, while the
// first question is read): playing one only shows them in turn.
// Nothing at all while motion is off; no effects (but the slide) where `live` is off — a streamed
// screen in stream mode with «no effects».
Item {
    id: root

    property bool live: true                 // the effects (the assistant: not while motion is off, not on a quiet streamed screen)
    property string screen: ""               // the screen it is on: its refresh rate
    property Item area: null                 // what a step change breaks into blocks (the picture and the question)
    property string playing: ""              // the random effect on now ("" between two)
    property bool chroma: false              // the title is split now (the assistant sets it)

    readonly property bool moving: !Motion.still && visible
    readonly property real hz: {
        const o = (Outputs.outputs || {})[screen];
        const m = o && o.modes && o.current_mode !== null && o.current_mode !== undefined ? o.modes[o.current_mode] : null;
        return m && m.refresh_rate > 0 ? m.refresh_rate / 1000 : 60;
    }
    // a pixel step: a whole number of frames, about a twelfth of a second
    readonly property int stepMs: Math.round(Math.max(1, Math.round(hz / 12)) * 1000 / hz)

    // ---- the table ----
    property var table: ({})
    FileView {
        id: tableFile
        path: Quickshell.shellDir + "/data/setup-effects.json"
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        try {
            table = JSON.parse(tableFile.text());
        } catch (e) {
            table = {};
        }
        next.interval = between(table.first || [3500, 7000]);
        sheenNext.interval = between(table.sheen || [4500, 11000]);
    }
    function between(r) {
        return Math.round(r[0] + Math.random() * Math.max(0, r[1] - r[0]));
    }
    function pick() {
        const list = (table.effects || []).filter(e => e.weight > 0);
        let sum = 0;
        for (const e of list)
            sum += e.weight;
        let r = Math.random() * sum;
        for (const e of list) {
            r -= e.weight;
            if (r <= 0)
                return e;
        }
        return list[0] || null;
    }
    function msOf(id) {
        const e = (table.effects || []).find(x => x.id === id);
        if (id === "sparks")
            return (14 + 4) * stepMs;
        if (id === "pixels")
            return 20 * stepMs;
        return e && e.ms ? e.ms : 2600;
    }

    // ---- the random effects: one at a time, the next pause starts when the last one is over ----
    Timer {
        id: next
        running: root.live && root.moving && root.playing === "" && !root.turning
        onTriggered: {
            const e = root.pick();
            if (e)
                root.play(e.id);
        }
    }
    function play(id) {
        if (!live || !moving || playing !== "")
            return;
        if (id === "chroma") {
            glitch();
            next.interval = between(table.gap || [9000, 20000]);
            return;
        }
        playing = id;
        done.interval = msOf(id);
        done.restart();
    }
    Timer {
        id: done
        onTriggered: {
            root.playing = "";
            next.interval = root.between(root.table.gap || [9000, 20000]);
        }
    }
    onLiveChanged: if (!live) {
        done.stop();
        playing = "";
    }
    Loader {
        anchors.fill: parent
        active: root.playing !== ""
        sourceComponent: ({
                "sparks": sparks,
                "pixels": pixels,
                "feather": feather,
                "peek": peek
            })[root.playing] || null
    }
    function snap(v) {
        return Math.round(v / Theme.u) * Theme.u;
    }

    // ---- the title's split (the assistant plays it: 2 px, 2 px, 1 px, gone; calm: 1 px, 1 px),
    // never with a gloss on ----
    signal glitched
    function glitch() {
        if (!live || !moving || chroma || glossing())
            return;
        glitched();
    }

    // ---- the gloss over the cards: one of them passes now and then ----
    property var glosses: []
    function addGloss(g) {
        glosses = glosses.concat([g]);
    }
    function removeGloss(g) {
        glosses = glosses.filter(x => x !== g);
    }
    function glossing() {
        return glosses.some(g => g.passing);
    }
    Timer {
        id: sheenNext
        running: root.live && root.moving
        repeat: true
        onTriggered: {
            interval = root.between(root.table.sheen || [4500, 11000]);
            if (root.chroma || root.turning)
                return;
            const shown = root.glosses.filter(g => g.visible && g.width > 0);
            if (shown.length)
                shown[Math.floor(Math.random() * shown.length)].pass();
        }
    }

    // ---- the step change ----
    // blocks / sweep: three pixel steps the blocks come (the step changes under them, `swap`),
    // three they go; slide: the assistant slides the new step in (`swap` at once).
    // transition() returns false when there is nothing to play (motion off): the assistant puts
    // the step up at once. `over` once it is all done.
    signal swap
    signal over
    signal blocksGo
    property string trStyle: ""
    property bool turning: false
    function transition(stepId, index, dir) {
        if (!moving)
            return false;
        const tr = table.transitions || {};
        const list = tr.list || ["blocks", "sweep", "slide"];
        let style = live ? (tr.byStep || {})[stepId] || list[Math.abs(index) % list.length] : "slide";
        if (style === "sweep")
            style = dir > 0 ? "sweep+" : "sweep-";
        if (style !== "slide" && (!baked.ready || !area))
            style = "slide";
        swapAt.stop();
        trStyle = style;
        if (style === "slide") {
            turning = false;
            swap();
            over();
            return true;
        }
        const p = mapFromItem(area, 0, 0);
        cover.x = p.x;
        cover.y = p.y;
        cover.width = area.width;
        cover.height = area.height;
        turning = true;
        blocksGo();
        blocksDone.restart();
        // the change itself halfway through the third step: the blocks cover it all then
        swapAt.interval = Math.round(stepMs * 2.5);
        swapAt.restart();
        return true;
    }
    Timer {
        id: swapAt
        onTriggered: root.swap()
    }
    Timer {
        id: blocksDone
        interval: root.stepMs * 6 + 20
        onTriggered: {
            root.turning = false;
            root.over();
        }
    }

    // the baked frames of the step change: the stage's ground in blocks of 6 art pixels
    QtObject {
        id: baked
        readonly property int cell: Theme.u * 6
        readonly property color end: Theme.mix(Theme.desk, Theme.accent, Theme.dark ? 0.14 : 0.1)
        readonly property string key: [Math.round(root.width), Math.round(root.height), cell, Theme.hex(Theme.desk), Theme.hex(end), Theme.hex(Theme.accent)].join("-").replace(/#/g, "")
        readonly property string dir: Config.cacheDir + "/setup-fx/" + key
        property string doneKey: ""
        readonly property bool ready: doneKey === key
        onKeyChanged: bakeLater.restart()
    }
    Timer {
        id: bakeLater
        interval: 300
        running: true
        onTriggered: {
            if (Motion.still || root.width <= 0 || root.height <= 0 || bakeRun.running)
                return;
            bakeRun.key = baked.key;
            bakeRun.command = ["python3", Quickshell.shellDir + "/scripts/setup-fx-bake.py", baked.dir, String(Math.round(root.width)), String(Math.round(root.height)), String(baked.cell), Theme.hex(Theme.desk), Theme.hex(baked.end), Theme.hex(Theme.accent)];
            bakeRun.running = true;
        }
    }
    Connections {
        target: Motion
        function onStillChanged() {
            if (!Motion.still)
                bakeLater.restart();
        }
    }
    Process {
        id: bakeRun
        property string key: ""
        onExited: code => {
            if (code === 0)
                baked.doneKey = key;
            if (key !== baked.key)
                bakeLater.restart();
        }
    }
    Item {
        id: cover
        visible: root.turning
        clip: true
        Repeater {
            id: frames
            // all six up at once (loaded, waiting, unseen): the render thread shows them in turn
            model: baked.ready ? 6 : 0
            Image {
                id: blockFrame
                required property int index
                opacity: 0
                x: -cover.x
                y: -cover.y
                width: Math.ceil(root.width / baked.cell) * baked.cell
                height: Math.ceil(root.height / baked.cell) * baked.cell
                source: root.trStyle !== "slide" && root.trStyle !== "" ? "file://" + baked.dir + "/" + root.trStyle + "-" + index + ".png" : ""
                smooth: false
                mipmap: false
                cache: true
                // on through step `index`, off after it: on the render thread, each step a whole
                // number of frames
                SequentialAnimation {
                    id: shownInTurn
                    PauseAnimation {
                        duration: blockFrame.index * root.stepMs
                    }
                    OpacityAnimator {
                        target: blockFrame
                        to: 1
                        duration: 1
                    }
                    PauseAnimation {
                        duration: root.stepMs
                    }
                    OpacityAnimator {
                        target: blockFrame
                        to: 0
                        duration: 1
                    }
                }
                Connections {
                    target: root
                    function onBlocksGo() {
                        shownInTurn.stop();
                        blockFrame.opacity = 0;
                        shownInTurn.start();
                    }
                }
            }
        }
    }
    // ---- sparks: a trail of sparkles along an arc across the screen, each lit for a few pixel
    // steps (small, star, small) ----
    Component {
        id: sparks
        Item {
            id: flock
            readonly property bool fromLeft: Math.random() < 0.5
            readonly property real y0: height * (0.55 + Math.random() * 0.3)
            readonly property real lift: height * (0.2 + Math.random() * 0.2)
            Repeater {
                model: 14
                Item {
                    id: sp
                    required property int index
                    readonly property real t: index / 13
                    readonly property color tint: index % 3 === 0 ? Theme.accent2 : index % 3 === 1 ? "#ffffff" : Theme.accent
                    x: root.snap(flock.width * (flock.fromLeft ? 0.06 + t * 0.88 : 0.94 - t * 0.88))
                    y: root.snap(flock.y0 - Math.sin(t * Math.PI * 0.9) * flock.lift + (index % 2 ? 1 : -1) * Theme.u * 6)
                    PxIcon {
                        id: small
                        x: -width / 2
                        y: -height / 2
                        name: "sparkle"
                        pixel: Math.max(1, Theme.u * (sp.index % 3 === 0 ? 2 : 1))
                        fill: sp.tint
                        opacity: 0
                    }
                    PxIcon {
                        id: star
                        x: -width / 2
                        y: -height / 2
                        name: "sparkleStar"
                        pixel: Math.max(1, Theme.u * (sp.index % 3 === 0 ? 2 : 1))
                        fill: sp.tint
                        opacity: 0
                    }
                    SequentialAnimation {
                        running: true
                        PauseAnimation {
                            duration: sp.index * root.stepMs
                        }
                        OpacityAnimator {
                            target: small
                            to: 1
                            duration: 1
                        }
                        PauseAnimation {
                            duration: root.stepMs
                        }
                        ParallelAnimation {
                            OpacityAnimator {
                                target: small
                                to: 0
                                duration: 1
                            }
                            OpacityAnimator {
                                target: star
                                to: 1
                                duration: 1
                            }
                        }
                        PauseAnimation {
                            duration: root.stepMs
                        }
                        ParallelAnimation {
                            OpacityAnimator {
                                target: star
                                to: 0
                                duration: 1
                            }
                            OpacityAnimator {
                                target: small
                                to: 1
                                duration: 1
                            }
                        }
                        PauseAnimation {
                            duration: root.stepMs
                        }
                        OpacityAnimator {
                            target: small
                            to: 0
                            duration: 1
                        }
                    }
                }
            }
        }
    }

    // ---- pixels: the ground twinkles here and there, a pixel on for two steps ----
    Component {
        id: pixels
        Item {
            id: ground
            Repeater {
                model: 46
                Rectangle {
                    id: px
                    required property int index
                    width: Theme.u * (1 + (index % 3))
                    height: width
                    x: Math.round(Math.random() * (ground.width - width) / Theme.u) * Theme.u
                    y: Math.round(Math.random() * (ground.height - height) / Theme.u) * Theme.u
                    color: index % 4 === 0 ? Theme.accent2 : index % 4 === 1 ? Theme.accent : "#ffffff"
                    opacity: 0
                    SequentialAnimation {
                        running: true
                        PauseAnimation {
                            duration: Math.floor(Math.random() * 17) * root.stepMs
                        }
                        OpacityAnimator {
                            target: px
                            to: 0.5
                            duration: 1
                        }
                        PauseAnimation {
                            duration: root.stepMs * 2
                        }
                        OpacityAnimator {
                            target: px
                            to: 0
                            duration: 1
                        }
                    }
                }
            }
        }
    }

    // ---- feather: one falls through the screen, swaying ----
    readonly property var featherBits: ["....w..", "...ww#.", "..wwf#.", "..wf##.", ".wwf#..", ".wf##..", "wwf#...", "wf##...", "wf#....", "f##....", "f#.....", "#......", "#......"]
    Component {
        id: feather
        Item {
            id: fall
            PxIcon {
                id: fe
                readonly property real x0: root.snap(fall.width * (0.2 + Math.random() * 0.6))
                readonly property real reach: Theme.u * 26
                bitmap: root.featherBits
                pixel: Math.max(2, Theme.u * 2)
                ink: Theme.dark ? "#d8d0ee" : Theme.edge
                body: "#ffffff"
                light: "#ffffff"
                x: x0 - reach
                y: -height
                YAnimator {
                    target: fe
                    running: true
                    to: fall.height + fe.height
                    duration: Math.max(1000, root.msOf("feather") - 200)
                }
                SequentialAnimation {
                    running: true
                    loops: Animation.Infinite
                    XAnimator {
                        target: fe
                        from: fe.x0 - fe.reach
                        to: fe.x0 + fe.reach
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                    XAnimator {
                        target: fe
                        from: fe.x0 + fe.reach
                        to: fe.x0 - fe.reach
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // ---- peek: the angel looks in from an edge for a moment (a little overshoot out, a look
    // round, back in). On the game step the title splits as it arrives ----
    property bool peekGlitch: false
    Timer {
        id: peekArrived
        interval: 420
        onTriggered: if (root.peekGlitch) {
            root.peekGlitch = false;
            root.glitch();
        }
    }
    Component {
        id: peek
        Item {
            id: nook
            readonly property int side: Math.floor(Math.random() * 3)    // left, right, bottom
            Component.onCompleted: peekArrived.restart()
            PxIcon {
                id: an
                bitmap: AngelMini.up
                pixel: Theme.u * 4
                ink: Theme.dark ? Theme.text : Theme.edge
                body: "#ffd9c7"
                fill: Theme.accent
                fill2: "#3a1a46"
                fill3: Theme.dark ? "#ffe07a" : "#f5c542"
                light: "#ffffff"
                bad: "#d8203a"
                readonly property real reach: (nook.side === 2 ? height : width) * 0.62
                rotation: nook.side === 0 ? 90 : nook.side === 1 ? -90 : 0
                readonly property real inX: nook.side === 0 ? -width - (height - width) / 2 : nook.side === 1 ? nook.width + (height - width) / 2 : root.snap(nook.width * 0.72)
                readonly property real inY: nook.side === 2 ? nook.height : root.snap(nook.height * 0.42)
                readonly property real outX: nook.side === 0 ? inX + reach : nook.side === 1 ? inX - reach : inX
                readonly property real outY: nook.side === 2 ? inY - reach : inY
                x: inX
                y: inY
                SequentialAnimation {
                    running: true
                    ParallelAnimation {
                        XAnimator {
                            target: an
                            to: an.outX
                            duration: 420
                            easing.type: Easing.OutBack
                        }
                        YAnimator {
                            target: an
                            to: an.outY
                            duration: 420
                            easing.type: Easing.OutBack
                        }
                    }
                    PauseAnimation {
                        duration: 1300
                    }
                    ParallelAnimation {
                        XAnimator {
                            target: an
                            to: an.inX
                            duration: 380
                            easing.type: Easing.InQuad
                        }
                        YAnimator {
                            target: an
                            to: an.inY
                            duration: 380
                            easing.type: Easing.InQuad
                        }
                    }
                }
            }
        }
    }
    // a step's moment: the title splits on the steps the table names; on the game step the
    // angel peeks in and the title splits as it arrives
    function landed(stepId) {
        if (!live || !moving)
            return;
        if (stepId === "game" && playing === "") {
            peekGlitch = true;
            play("peek");
            return;
        }
        if (((table.chroma || {}).steps || []).includes(stepId))
            glitch();
    }
}
