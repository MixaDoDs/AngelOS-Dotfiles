pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import "SetupPrequelRooms.js" as Rooms

// The first run's intro, its first minute (SetupIntro's phase "pre"), on one screen: the night
// of 31.12.2002, as the game recorded it — slow. A few long shots, cut one to another
// (`b.shots`): her room from the window, from close behind her, from the door (the author's
// pictures, shaders/setup_prequel.frag, the camera creeping in), and her monitor filling the
// screen (SetupPrequelDesk): the board, the thread of those alone tonight, his messages, what
// she types and rubs out, the disc. Her desk close by the glass: the blister, two pills out of
// it. The goggles go on; three times the picture cuts
// to what she sees in them (`b.inserts`, shaders/setup_goggles.frag): the title, the fall,
// deeper and redder, until there is fire in the game too. Behind her back the cigarette she left
// in the ashtray catches the papers — seen close, in quiet, before she laughs. Fireworks all along (`b.fireworks`: each lights her window a
// moment before its bang is heard), at midnight all of them; the game is saving when the recording
// breaks up — blue, «НЕТ СИГНАЛА» — and the installer of today comes out of it
// (SetupIntroScreen under this).
// Under all of it, as a novel has it, what she thinks — a line at a time, typed out (`b.says`):
// it is why she does each thing. One thing at a time: when a message or an answer comes up on
// her screen the camera goes in on it (`b.focus`), the rest dark, and comes back before
// anything else. After the second pill the picture swims (`b.high`, shaders/setup_high.frag)
// and there is next to nothing left of her thoughts.
// Your other screens are her other monitors, whole (the messenger; the player and the clock).
// Calm motion: the blister stays full; the tearing, the swimming and the eyes' pictures apart
// at half.
Item {
    id: root

    property var intro: null
    property bool hosting: false
    property var here: null
    property var host: null
    readonly property bool on: !!intro && intro.phase === "pre"
    readonly property real t: intro ? intro.pre : 0
    readonly property var b: intro ? intro.preBeats : ({})
    readonly property bool tall: height > width
    readonly property real px: Math.max(2, Math.floor(Math.min(width, height) / 270))
    visible: on

    // ---- which shot ----
    // [from, "window" | "monitor" | "rear" | "desk" | "screen", which picture of that side]
    readonly property var shots: b.shots || [[0, "screen", 0]]
    readonly property int shotAt: {
        let i = 0;
        while (i < shots.length - 1 && t >= shots[i + 1][0])
            i++;
        return i;
    }
    readonly property var shot: shots[shotAt]
    readonly property real shotEnd: shotAt < shots.length - 1 ? shots[shotAt + 1][0] : (b.length || 60)
    // how far through it — through all of it when the same side goes on in the next picture
    readonly property real along: {
        let a = shotAt, c = shotAt;
        while (a > 0 && shots[a - 1][1] === shot[1])
            a--;
        while (c < shots.length - 1 && shots[c + 1][1] === shot[1])
            c++;
        const end = c < shots.length - 1 ? shots[c + 1][0] : (b.length || 60);
        return Math.max(0, Math.min(1, (t - shots[a][0]) / Math.max(0.1, end - shots[a][0])));
    }
    readonly property var place: Rooms.rooms[shot[1]] || Rooms.rooms.rear
    // ANGELOS_SETUP_INTRO_SIDE=2|3: this screen as one of her other monitors (trying it on one screen)
    readonly property int forced: Number(Quickshell.env("ANGELOS_SETUP_INTRO_SIDE") || 0)
    readonly property int view: forced ? forced : !hosting ? (here && host && here.x > host.x ? 3 : 2) : shot[1] === "screen" ? 1 : 0
    // in the goggles: which of the cuts (−1: not)
    readonly property var cuts: b.inserts || []
    readonly property int cutTo: {
        for (let i = 0; i < cuts.length; i++)
            if (t >= cuts[i][0] && t < cuts[i][1])
                return i;
        return -1;
    }
    readonly property bool last: cutTo === cuts.length - 1
    readonly property bool inGoggles: view < 2 && cutTo >= 0
    readonly property real cut: b.cut || 1e9
    readonly property bool noSignal: t >= cut + 0.9
    // the tape: a jolt at every cut to the goggles and back, and at the end all of it
    readonly property real tear: {
        let g = Math.max(0, Math.min(1, (t - cut + 0.6) / 1.5));
        for (const c of cuts)
            if (Math.abs(t - c[0]) < 0.07 || Math.abs(t - c[1]) < 0.07)
                g = Math.max(g, 0.5);
        return g * (Motion.calm ? 0.5 : 1);
    }

    // ---- something has come up on her screen: the camera leans to it, slowly, and back ----
    readonly property var inOn: {
        for (const f of b.focus || [])
            if (t >= f[0] && t < f[1])
                return f;
        return null;
    }
    readonly property real near: {
        if (!inOn)
            return 0;
        const x = Math.max(0, Math.min(1, Math.min((t - inOn[0]) / 2.4, (inOn[1] - t) / 1.6)));
        return x * x * (3 - 2 * x);
    }
    // the last spot stays while the camera is on its way back
    property vector4d spot: Qt.vector4d(0, 0, 1, 1)
    onInOnChanged: if (inOn)
        spot = Qt.vector4d(inOn[2] / 320, inOn[3] / 240, inOn[4] / 320, inOn[5] / 240)
    // ---- she laughs: the picture shakes with it (`b.laugh.env`: how loud, 20 times a second) —
    // by whole art pixels — and the camera goes in on her; no thought with it, it is the pills ----
    readonly property real laughFor: b.laugh ? t - b.laugh.at : -1
    readonly property bool laughs: laughFor >= 0 && laughFor * 20 < b.laugh.env.length
    readonly property real laughing: laughs ? b.laugh.env[Math.floor(laughFor * 20)] * (Motion.calm ? 0.5 : 1) : 0
    readonly property real laughIn: {
        if (!laughs)
            return 0;
        const x = Math.min(1, laughFor / 3.6);
        return x * x * (3 - 2 * x);
    }
    // ---- the pills: none, then more and more ----
    readonly property real high: b.high ? Math.max(0, Math.min(1, (t - b.high[0]) / (b.high[1] - b.high[0]))) * (Motion.calm ? 0.5 : 1) : 0

    // (hidden by its picture, not by `visible`: under an unseen item a window that opens later is
    // never drawn)
    SetupPrequelDesk {
        id: desk
        t: root.t
        b: root.b
        calm: Motion.calm
    }
    ShaderEffectSource {
        id: deskPicture
        sourceItem: desk
        hideSource: true
        textureSize: Qt.size(960, 240)
        live: root.on
        smooth: false
        visible: false
    }
    // the room's pictures, all of them ready before their shots
    Repeater {
        id: pictures
        model: root.on && root.hosting ? ["window-1", "window-3", "monitor-1", "monitor-2", "monitor-3", "rear-1", "rear-3", "desk-6", "desk-5", "desk-4", "ash-3"] : []
        Image {
            required property string modelData
            source: Qt.resolvedUrl("../../data/intro/room-" + modelData + ".png")
            smooth: false
            visible: false
        }
    }
    readonly property Item picture: {
        const name = shot[1] + "-" + (shot[1] === "desk" && Motion.calm ? 6 : shot[2]);
        for (let i = 0; i < pictures.count; i++)
            if (pictures.itemAt(i) && pictures.itemAt(i).modelData === name)
                return pictures.itemAt(i);
        return null;
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }
    // ---- in the goggles ----
    readonly property real lens: (tall ? 0.72 : 0.84) * Math.min(width, height) / 2
    readonly property real lensOff: (tall ? 0.36 : 0.80) * Math.min(width, height) / 2
    readonly property real deep: cuts.length > 1 ? Math.max(0, cutTo) / (cuts.length - 1) : 0
    readonly property real saved: cutTo >= 0 ? Math.max(0, Math.min(1, (t - cuts[cutTo][0]) / (cuts[cutTo][1] - cuts[cutTo][0]))) : 0
    Item {
        id: stage
        anchors.fill: parent
        layer.enabled: root.high > 0
        layer.effect: ShaderEffect {
            property real high: root.high
            property real time: root.t
            fragmentShader: Qt.resolvedUrl("../../shaders/setup_high.frag.qsb")
        }
    ShaderEffect {
        anchors.fill: parent
        visible: !root.inGoggles && (root.view !== 0 || !!root.picture)
        readonly property var s: root.place.screens
        readonly property var h: root.place.hearths
        property size itemSize: Qt.size(width, height)
        property real px: root.px
        property real view: root.view
        property real picAspect: root.place.aspect
        // creeping in on her all through the shot; an upright screen sees a third of the picture
        // across, and drifts along it (from the window to her, where the window is to be seen)
        // (once it burns, what burns is kept in sight)
        readonly property real middle: root.place.fire && root.t >= root.b.caught + 2 ? root.place.fire : root.place.focus[0]
        property vector3d cam: Qt.vector3d(!root.tall ? middle : root.place.pan ? root.place.pan[0] + (root.place.pan[1] - root.place.pan[0]) * root.along : middle + 0.09 * (root.along - 0.5), root.place.focus[1] - 0.04 * root.laughIn + Math.round(2.4 * root.laughing * Math.sin(root.t * 44)) / 270, 1 + 0.10 * root.along + 0.16 * root.laughIn)
        property real time: root.t
        // a thread from the cigarette; once it has caught, the room fills
        property real smoke: root.t < root.b.caught ? 0.04 + 0.1 * root.t / root.b.caught : Math.min(1, 0.14 + 0.86 * (root.t - root.b.caught) / 22)
        property real burn: root.t - root.b.caught
        // fireworks: each one its sound has (`b.fireworks`: when, how big, which colour) — the
        // light a moment before the bang, as from a few streets away
        readonly property var shell: {
            let last = null;
            for (const f of root.b.fireworks || [])
                if (root.t >= f[0])
                    last = f;
            return last;
        }
        property real burst: shell ? shell[1] * Math.exp(-3.2 * (root.t - shell[0])) : 0
        property vector3d spark: [Qt.vector3d(1.0, 0.45, 0.8), Qt.vector3d(0.5, 0.62, 1.0), Qt.vector3d(1.0, 0.82, 0.45), Qt.vector3d(0.5, 1.0, 0.7)][shell ? shell[2] : 0]
        property real glitch: root.tear
        // (a 3×3 homography, as the 4×4 that does the same to (x, y, 0, 1))
        function screen(m) {
            return Qt.matrix4x4(m[0], m[1], 0, m[2], m[3], m[4], 0, m[5], 0, 0, 1, 0, m[6], m[7], 0, m[8]);
        }
        property matrix4x4 s0: screen(s[0])
        property matrix4x4 s1: screen(s[1])
        property matrix4x4 s2: screen(s[2])
        property vector4d h0: Qt.vector4d(h[0][0], h[0][1], h[0][2], h[0][3])
        property vector4d h1: Qt.vector4d(h[1][0], h[1][1], h[1][2], h[1][3])
        property vector4d h2: Qt.vector4d(h[2][0], h[2][1], h[2][2], h[2][3])
        property vector4d h3: Qt.vector4d(h[3][0], h[3][1], h[3][2], h[3][3])
        property vector4d h4: Qt.vector4d(h[4][0], h[4][1], h[4][2], h[4][3])
        property point ember: Qt.point(root.place.ember[0], root.place.ember[1])
        property vector4d pane: Qt.vector4d(root.place.pane[0], root.place.pane[1], root.place.pane[2], root.place.pane[3])
        property vector4d shellA: Qt.vector4d(root.place.shells[0][0], root.place.shells[0][1], root.place.shells[0][2], 0)
        property vector4d shellB: Qt.vector4d(root.place.shells[1][0], root.place.shells[1][1], root.place.shells[1][2], 0)
        property vector4d spot: root.spot
        property real near: root.view === 1 ? root.near : 0
        property var room: root.picture || deskPicture     // (her screen whole: no room in it)
        property var desk: deskPicture
        fragmentShader: Qt.resolvedUrl("../../shaders/setup_prequel.frag.qsb")
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.inGoggles
        property size itemSize: Qt.size(width, height)
        property real px: root.px
        property real time: root.t
        property real depth: 0.05 + 0.9 * root.deep
        property real apart: (0.01 + 0.14 * root.deep) * (Motion.calm ? 0.5 : 1)
        property real burn: root.last ? root.saved : 0
        property real still: root.cutTo === 0 ? 1 : 0
        fragmentShader: Qt.resolvedUrl("../../shaders/setup_goggles.frag.qsb")
    }
    }
    component Hud: Text {
        font.family: Theme.fontHellText
        font.pixelSize: 11 * Math.max(1, Math.round(root.px / 2))
        renderType: Text.NativeRendering
        antialiasing: false
        color: "#ffe9a8"
        style: Text.Outline
        styleColor: "#1a0a10"
    }
    // the game's own words, once for each eye
    Repeater {
        model: root.inGoggles ? 2 : 0
        Item {
            id: eye
            required property int index
            x: root.width / 2 + (index ? 1 : -1) * root.lensOff - width / 2
            y: root.height / 2 - height / 2
            // (on an upright screen the lenses overlap: the words keep to their own)
            width: Math.min(root.lens * 1.25, root.lensOff * 1.9)
            height: root.lens * 1.25
            // the title: the publisher's wheel with an eye, the game's two words
            Column {
                visible: root.cutTo === 0
                anchors.centerIn: parent
                spacing: root.px * 3
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: Qt.resolvedUrl("../y2k/sprites/angel-ophanim/body.png")
                    smooth: false
                    width: sourceSize.width * Math.max(1, Math.round(root.px / 2))
                    height: sourceSize.height * Math.max(1, Math.round(root.px / 2))
                }
                Hud {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 22 * Math.max(1, Math.round(root.px / 2))
                    text: "СОХРАНИ СЕБЯ"
                }
                Hud {
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: Math.floor(root.t * 2) % 2 ? 1 : 0.2
                    text: "НОВАЯ ИГРА"
                }
            }
            Hud {
                visible: root.cutTo > 0
                text: "КРУГ " + (root.last ? "VIII" : "IV")
            }
            Hud {
                visible: root.cutTo > 0
                anchors.right: parent.right
                color: "#ff5a6e"
                opacity: Math.floor(root.t * 2) % 2 ? 1 : 0.3
                text: "● REC"
            }
            Hud {
                visible: root.cutTo > 0
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                color: root.last ? "#ffffff" : "#ffe9a8"
                text: root.last ? "СОХРАНЕНИЕ… " + Math.min(99, Math.floor(80 + 20 * root.saved)) + " %" : "ИГРОК ЗАПИСАН: 47 %\nПУЛЬС " + Math.floor(112 + root.t % 3)
            }
        }
    }

    // ---- the recording's frame: it is the game that records her — from the moment the goggles
    // are on, its own count of time; before that nobody is filming ----
    Item {
        id: tape
        readonly property real rec: root.t - (root.b.goggles || 0)
        anchors.fill: parent
        anchors.margins: root.px * 6
        visible: !root.inGoggles && !root.noSignal && rec >= 0
        Hud {
            color: "#ff5a6e"
            visible: root.t < root.cut && Math.floor(root.t * 1.5) % 2 === 0
            text: "● REC"
        }
        Hud {
            anchors.right: parent.right
            color: "#f4eefc"
            text: "SP  0:0" + Math.floor(tape.rec / 60) + ":" + (tape.rec % 60 < 10 ? "0" : "") + Math.floor(tape.rec % 60)
        }
        Hud {
            anchors.bottom: parent.bottom
            color: "#f4eefc"
            text: (desk.clock < "12" ? "01.01.2003  " : "31.12.2002  ") + desk.clock
        }
    }
    // her screen's words, for those who do not read Russian
    Column {
        readonly property var said: {
            const b = root.b, lines = [];
            const during = (a, c, s) => {
                if (root.t >= a && root.t < c)
                    lines.push(s);
            };
            for (const m of b.messages || [])
                during(m.at, m.until, "sneg: " + m.en);
            if (b.typing && b.erase && b.replies) {
                during(b.typing[0][0], b.typing[2][0], "«yeah... there is that.»");
                during(b.typing[2][0], b.erase[1], "«yeah... there is that. I still—»");
                during(b.replies[0], b.replies[1], "«listen, I do not know — take this torrent link, there is an interesting little game, clear your head»");
                during(b.replies[1], b.replies[1] + 4, "«do not run it alone»");
            }
            return lines;
        }
        visible: root.view < 2 && !root.inGoggles && !root.noSignal && I18n.t("", "en") === "en"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: thought.visible ? thought.top : parent.bottom
        anchors.bottomMargin: thought.visible ? root.px * 5 : root.px * 22
        width: parent.width - root.px * 24
        spacing: root.px
        Repeater {
            model: parent.said
            Hud {
                required property string modelData
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: "#f4eefc"
                text: modelData
            }
        }
    }

    // ---- what she thinks ----
    readonly property var says: b.says || []
    readonly property int sayAt: {
        let i = -1;
        for (let k = 0; k < says.length; k++)
            if (t >= says[k][0])
                i = k;
        return i;
    }
    readonly property string saying: sayAt >= 0 ? I18n.t(says[sayAt][1], says[sayAt][2]) : ""
    readonly property real sayFor: sayAt >= 0 ? t - says[sayAt][0] : 0
    // (a size up from the recording's own lettering: this is the one to read)
    readonly property int sayPx: 11 * (Math.max(1, Math.round(px / 2)) + 1)
    Rectangle {
        id: thought
        // (it stays a while after the last letter, then leaves the picture to itself)
        visible: root.hosting && root.view < 2 && !root.noSignal && root.t < root.cut && root.shot[1] !== "ash" && root.saying !== "" && root.sayFor < root.saying.length / (root.b.cps || 26) + 3.2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Math.round(root.high * 2 * Math.sin(root.t * 5.1)) * root.px
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.px * (14 + Math.round(root.high * 1.5 * Math.sin(root.t * 3.7)))
        width: Math.min(parent.width - root.px * 12, root.px * 250)
        height: words.implicitHeight + root.px * 10
        color: "#e6120c1c"
        border.color: "#b98be0"
        border.width: Math.max(1, Math.round(root.px / 2))
        Rectangle {
            x: root.px * 4
            y: -height / 2
            width: who.implicitWidth + root.px * 6
            height: who.implicitHeight + root.px * 2
            color: "#b98be0"
            Hud {
                id: who
                anchors.centerIn: parent
                style: Text.Normal
                color: "#1a0a1c"
                text: I18n.t("Алиса", "Alice")
            }
        }
        Hud {
            id: words
            x: root.px * 5
            y: root.px * 6
            width: parent.width - root.px * 10
            wrapMode: Text.WordWrap
            style: Text.Normal
            color: "#f4eefc"
            font.pixelSize: root.sayPx
            // (the whole line is laid out from the first letter: it does not jump as it types)
            text: root.saying
            visible: false
        }
        Hud {
            x: words.x
            y: words.y
            width: words.width
            wrapMode: Text.WordWrap
            style: Text.Normal
            color: "#f4eefc"
            font.pixelSize: root.sayPx
            text: root.saying.slice(0, Math.floor(root.sayFor * (root.b.cps || 26)))
        }
    }

    // ---- the end of the tape: no signal. Its tone gone, what a television of that country
    // showed when something had happened and it would not say what: the little swans, in step
    // with their record (`b.swan`: from when, how long a step) — a breath before the minute ----
    readonly property real swanFor: b.swan ? t - b.swan.at : -1
    readonly property real swans: Math.max(0, Math.min(1, (swanFor + 0.4) / 1.2))
    Rectangle {
        anchors.fill: parent
        visible: root.noSignal
        color: "#1a1ad6"
        Hud {
            anchors.centerIn: parent
            font.pixelSize: 22 * Math.max(1, Math.round(root.px / 2))
            color: "#ffffff"
            styleColor: "#0a0a70"
            text: I18n.t("НЕТ СИГНАЛА", "NO SIGNAL")
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.noSignal && root.swans > 0
        opacity: root.swans
        color: "#000000"
        // a black-and-white broadcast, 4:3, 96×72 cells of it: the stage, four dancers hand in
        // hand, the tube's lines and grain
        Canvas {
            id: ballet
            // (two pictures a step: down on the beat, up between)
            readonly property int frame: root.b.swan ? Math.max(0, Math.floor(root.swanFor / (root.b.swan.step / 2))) : 0
            width: 96
            height: 72
            anchors.centerIn: parent
            scale: Math.max(1, Math.floor(Math.min(parent.width / width, parent.height / height)))
            smooth: false
            onFrameChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                const cell = (x, y, w, h, c) => {
                    g.fillStyle = c;
                    g.fillRect(x, y, w, h);
                };
                const step = Math.floor(frame / 2), up = frame % 2;
                cell(0, 0, 96, 72, "#0c0c0e");
                // the light on the stage, its floor
                for (let i = 0; i < 6; i++)
                    cell(14 + i * 3, 8 + i * 2, 68 - i * 6, 46 - i * 2, ["#111114", "#15151a", "#191920", "#1d1d25", "#20202a", "#23232e"][i]);
                cell(0, 54, 96, 18, "#1a1a20");
                cell(0, 54, 96, 1, "#33333c");
                // the four of them: across the stage and back, sixteen steps each way
                const along = step % 32 < 16 ? step % 16 : 16 - step % 16;
                const white = "#e9e9ee", shade = "#8d8d98";
                for (let k = 0; k < 4; k++) {
                    const x = 22 + k * 12 + along, y = 54 - up;
                    const lead = (step + k) % 2;                    // which leg works
                    cell(x - 1, y - 21, 3, 3, white);               // the head, its knot of hair
                    cell(x + (Math.floor(step / 4) % 2 ? 1 : -1), y - 22, 1, 1, white);
                    cell(x, y - 18, 1, 1, shade);
                    cell(x - 1, y - 17, 3, 4, white);               // the bodice
                    cell(x - 5, y - 13, 11, 1, white);              // the skirt, flat out
                    cell(x - 4, y - 12, 9, 1, white);
                    cell(x - 2, y - 11, 5, 1, shade);
                    // her arms down and out to her neighbours' hands (the ends' to nobody's)
                    for (let i = 0; i < 3; i++) {
                        cell(x - 2 - i, y - 17 + i, 1, 1, white);
                        cell(x + 2 + i, y - 17 + i, 1, 1, white);
                    }
                    cell(x - 6, y - 15, 2, 1, white);
                    cell(x + 5, y - 15, 2, 1, white);
                    // the legs: one on its point, the other's knee out and its foot at the knee
                    cell(x + (lead ? 1 : -1), y - 10, 1, 10, white);
                    cell(x + (lead ? -1 : 1), y - 10, 1, 3, white);
                    cell(x + (lead ? -2 : 2), y - 7, 1, 2 + up, white);
                    cell(x + (lead ? -1 : 1), y - 5 + up, 1, 2, shade);
                }
                // the tube: every other line darker, grain (the same for a picture, new with the next)
                for (let y = 0; y < 72; y += 2)
                    cell(0, y, 96, 1, "rgba(0, 0, 0, 0.22)");
                let seed = frame * 7919 + 13;
                for (let i = 0; i < 90; i++) {
                    seed = (seed * 1103515245 + 12345) % 2147483648;
                    cell(Math.floor(seed / 256) % 96, Math.floor(seed / 65536) % 72, 1 + Math.floor(seed / 4096) % 2, 1, Math.floor(seed / 1024) % 3 ? "rgba(255, 255, 255, 0.10)" : "rgba(0, 0, 0, 0.35)");
                }
            }
        }
    }

    // the way out, from its moment on
    Hud {
        visible: root.hosting && !root.noSignal && root.t >= (root.b.hint || 30)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.px * 4
        opacity: 0.3
        color: "#f4eefc"
        text: I18n.t("пробел ×5 — пропустить", "space ×5 to skip")
    }
}
