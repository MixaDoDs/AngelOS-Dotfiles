import QtQuick
import qs.config
import qs.services
import qs.widgets
import "RunnerSprites.js" as Sprite

// «Забег» (services/Waiting): while a build or an update runs the cat runs along the bar's middle
// and jumps the bugs by itself — a live «it's building». A click takes it over: a click is a
// jump, the score is the distance; a bug hit and it tumbles, the game is over, the autopilot
// runs on. The wait over, a finish flag comes, the cat crosses it, one line tells how it went.
// Everything in whole art pixels, the text colour; still when nobody looks or motion is off.
Item {
    id: root

    required property string screenName
    property real maxWidth: Theme.u * 200
    property bool barInk: false
    readonly property bool here: Waiting.shown && Waiting.screen === screenName
    readonly property color ink: barInk ? Theme.hellBarIcon : Theme.dark ? Theme.text : Theme.edge
    readonly property color dimInk: barInk ? Theme.hellTextDim : Theme.textDim

    implicitWidth: here ? Math.max(0, Math.min(maxWidth, Theme.u * 200)) : 0
    implicitHeight: Theme.u * 15
    clip: true

    Accessible.role: Accessible.Animation
    Accessible.name: Waiting.job ? I18n.t("Идёт ", "Running: ") + Waiting.job.name : I18n.t("Забег", "Run")

    readonly property int u: Theme.u
    // the field in art pixels: right of the line of words, the ground two rows above the bottom
    readonly property int cols: Math.max(40, Math.floor(field.width / u))
    readonly property int ground: Math.floor(height / u) - 2
    readonly property int catX: 3
    readonly property int jumpTicks: 24
    readonly property int jumpTop: 6

    readonly property bool moving: here && !Motion.still && !Shell.stillScreen(screenName)
    // art pixels a tick: faster the busier the build keeps the processor, and as the game goes on
    readonly property real speed: 1 + Math.min(1, Waiting.cpu) * 0.9 + (playing ? Math.min(0.5, dist / 4000) : 0)

    property int tick: 0
    property real dist: 0
    property real groundShift: 0
    property int air: -1               // ticks into a jump, -1 on the ground
    readonly property int lift: air < 0 ? 0 : Math.round(jumpTop * 4 * (air / jumpTicks) * (1 - air / jumpTicks))
    property var bugs: []              // [{x, kind}] art pixels from the field's left
    property real flagX: -100
    property bool flagOut: false
    property bool crossed: false
    property bool playing: false
    property int score: 0
    property int passed: 0             // bugs jumped this game
    property int down: 0               // ticks left on its back after a hit

    function reset() {
        bugs = [];
        dist = 0;
        air = -1;
        down = 0;
        playing = false;
        flagOut = false;
        crossed = false;
        flagX = -100;
    }
    onHereChanged: if (here)
        reset()
    Connections {
        target: Waiting
        function onSinceChanged() {
            root.reset();
        }
    }

    function jump() {
        if (air < 0 && down === 0)
            air = 0;
    }
    function gameOver() {
        Waiting.crashed();
        Waiting.scored(score);
        playing = false;
        down = 30;
        air = -1;
    }
    function step() {
        tick++;
        const v = speed;
        dist += v;
        groundShift = (groundShift + v) % 4;
        if (down > 0) {
            down--;
        } else if (air >= 0) {
            air++;
            if (air > jumpTicks)
                air = -1;
        }
        // the bugs come from the right; none once the wait is over, the flag instead
        const next = [];
        let lastX = -1e9;
        for (const b of bugs) {
            const x = b.x - v;
            if (x > -8) {
                next.push({
                    "x": x,
                    "kind": b.kind
                });
                lastX = Math.max(lastX, x);
            } else if (playing) {
                passed++;
                if (passed === 50)
                    Waiting.streak();
            }
        }
        const room = 34 + v * 14;
        if (Waiting.active && cols - lastX > room + Math.random() * 60 && Math.random() < 0.08)
            next.push({
                "x": cols + 2,
                "kind": Math.random() < 0.5 ? 0 : 1
            });
        bugs = next;
        if (playing)
            score = Math.floor(dist / 10);
        // the autopilot: off the ground so the middle of the jump is over the bug
        const ahead = next.filter(b => b.x + 2.5 > catX + 6.5).sort((a, b) => a.x - b.x)[0];
        if (!playing && down === 0 && ahead && ahead.x + 2.5 - (catX + 6.5) <= (jumpTicks / 2) * v)
            jump();
        // a hit: the cat's legs over a bug's body
        if (down === 0 && lift <= 3)
            for (const b of next)
                if (b.x + 1 <= catX + 10 && b.x + 4 >= catX + 3) {
                    if (playing)
                        gameOver();
                    else
                        jump();
                    break;
                }
        // the finish: the flag after the last bug, crossed when it is under the cat
        if (!Waiting.active && Waiting.finish && !flagOut) {
            flagOut = true;
            flagX = Math.max(cols + 2, lastX + room);
        }
        if (flagOut && !crossed) {
            flagX -= v;
            if (flagX + 2 < catX + 6) {
                crossed = true;
                if (playing) {
                    Waiting.scored(score);
                    playing = false;
                }
                doneLater.restart();
            }
        }
    }
    Timer {
        interval: 33
        repeat: true
        running: root.moving && !root.crossed
        onTriggered: root.step()
    }
    // nobody watching the finish (motion off, the screen asleep): the line, then gone
    Timer {
        running: root.here && !Waiting.active && !!Waiting.finish && !root.moving && !root.crossed
        interval: 1500
        onTriggered: {
            root.crossed = true;
            doneLater.restart();
        }
    }
    Timer {
        id: doneLater
        interval: 4000
        onTriggered: Waiting.done()
    }

    TapHandler {
        enabled: root.here && !root.crossed
        onTapped: {
            if (!root.playing) {
                if (root.down > 0)
                    return;
                root.playing = true;
                root.dist = 0;
                root.score = 0;
                root.passed = 0;
            }
            Waiting.jumped();
            root.jump();
        }
    }
    HoverHandler {
        enabled: root.here && !root.crossed
        cursorShape: Qt.PointingHandCursor
    }

    function clock(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    function jumpsWord(n) {
        if (I18n.english)
            return n === 1 ? "1 jump" : n + " jumps";
        const a = n % 10, b = n % 100;
        return n + (a === 1 && b !== 11 ? " прыжок" : a >= 2 && a <= 4 && (b < 12 || b > 14) ? " прыжка" : " прыжков");
    }
    // the finish line: «cargo build · 1:42 · 37 прыжков · рекорд!»
    readonly property string summary: {
        const f = Waiting.finish;
        if (!f)
            return "";
        let s = f.name + " · " + clock(f.secs);
        if (f.jumps > 0)
            s += " · " + jumpsWord(f.jumps);
        if (f.record)
            s += I18n.t(" · рекорд!", " · a record!");
        return s;
    }
    // ticks once a second for the time on the line while the cat runs on its own
    property double now: Date.now()
    Timer {
        interval: 1000
        repeat: true
        running: root.here && !root.playing && !!Waiting.job
        onTriggered: root.now = Date.now()
    }

    // the line of words on the left: what runs and for how long, or the score while playing
    PxText {
        id: label
        visible: !root.crossed
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: Math.min(implicitWidth, root.width * 0.45)
        elide: Text.ElideRight
        kind: "tiny"
        color: root.dimInk
        text: root.playing ? String(root.score).padStart(4, "0") + (Waiting.job && Waiting.bestOf(Waiting.job.name) > 0 ? "  " + I18n.t("рекорд ", "best ") + Waiting.bestOf(Waiting.job.name) : "") : Waiting.job ? Waiting.job.name + " · " + root.clock(root.now / 1000 - Waiting.job.start) : Waiting.finish ? Waiting.finish.name + " · " + root.clock(Waiting.finish.secs) : ""
    }

    Item {
        id: field
        visible: !root.crossed
        x: label.width + root.u * 4
        width: root.width - x
        height: parent.height
        clip: true

        // the ground: dashes running under the cat
        Repeater {
            model: Math.ceil(root.cols / 4) + 1
            Rectangle {
                required property int index
                x: Math.round(index * 4 - root.groundShift) * root.u
                y: (root.ground + 1) * root.u
                width: root.u * 2
                height: root.u
                color: root.ink
                opacity: 0.45
            }
        }
        Repeater {
            model: root.bugs.length
            PxIcon {
                required property int index
                readonly property var b: root.bugs[index]
                bitmap: Sprite.bugs[b ? b.kind : 0]
                pixel: root.u
                ink: root.ink
                x: Math.round(b ? b.x : -10) * root.u
                y: (root.ground - 3) * root.u
            }
        }
        PxIcon {
            visible: root.flagOut
            bitmap: Sprite.flag
            pixel: root.u
            ink: root.ink
            x: Math.round(root.flagX) * root.u
            y: (root.ground - 7) * root.u
        }
        PxIcon {
            bitmap: root.down > 0 ? Sprite.tumble : root.air >= 0 ? Sprite.jump : Sprite.run[root.moving ? Math.floor(root.tick / 3) % 4 : 0]
            pixel: root.u
            ink: root.ink
            x: root.catX * root.u
            y: (root.ground - 6 - root.lift) * root.u
        }
    }

    // past the flag: the cat sits at the line, the words next to it
    Row {
        visible: root.crossed
        anchors.centerIn: parent
        spacing: root.u * 4
        PxIcon {
            anchors.verticalCenter: parent.verticalCenter
            bitmap: Sprite.run[0]
            pixel: root.u
            ink: root.ink
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - root.u * 20)
            elide: Text.ElideRight
            text: root.summary
            color: root.barInk ? Theme.hellText : Theme.text
        }
    }
}
