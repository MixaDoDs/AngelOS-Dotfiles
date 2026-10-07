pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The look of RadialMenu in the circle of fraud: masks on a string, hung in an oval round
// the pointer — bone and dark faces by turns, each tilted its own way, two slits for eyes
// above the entry it hides; the one you're on straightens and leans out. Opening, they swing
// in on the string.
// The toy (CircleToy): the masks are the frauds of Malebolge — a flatterer, a soothsayer, a
// thief… (story/toys.json → fraud). Right-click one and it tells you which entry it is, lying;
// believe it and it laughs at you, tear the mask off and it confesses its real name and lets
// you open it. Tug the string (a click or a drag) and they swing; a right click past them turns
// every face over (the bone ones go dark, the dark ones bone: two faces, as befits the place).
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property int n: Math.max(1, menu.slots.length)
    readonly property real maskW: Math.round(Theme.u * 20 * k)
    readonly property real maskH: Math.round(Theme.u * 25 * k)
    readonly property real labelRoom: menu.labels ? Theme.sizeTiny + Theme.u * 3 : 0
    // an oval half as wide again as it is tall, room for every mask and its name round it
    readonly property real ry: Math.max(Theme.u * 56 * k, n * (maskW + (menu.labels ? Theme.u * 26 : Theme.u * 10) * k) / (2 * Math.PI * 1.25))
    readonly property real rx: ry * 1.5
    readonly property real reach: rx + maskW / 2 + Theme.u * 10
    readonly property Item blurItem: null
    function angleOf(i) {
        return -Math.PI / 2 + i * 2 * Math.PI / n;
    }
    function pointOf(i, grow) {
        const a = angleOf(i), s = (0.6 + 0.4 * menu.reveal) * (grow || 1);
        return Qt.point(menu.cx + Math.cos(a) * rx * s, menu.cy + Math.sin(a) * ry * s);
    }
    // the toy: the swing (degrees) and how fast it goes; the faces turned over
    property real sway: 0
    property real swayV: 0
    property real lastX: 0
    property bool turned: false
    property real turning: 0                // 0 … 1, the faces edge-on halfway
    // the talk: who each mask is this opening (a shift into toys.json → fraud.masks), the
    // ones torn off, the score
    property int cast: 0
    property var bare: []
    property int unmasked: 0
    property int fooled: 0
    function maskAt(x, y) {
        for (let i = 0; i < n; i++) {
            const p = pointOf(i);
            if (Math.abs(p.x - x) < maskW * 0.6 && Math.abs(p.y - y) < maskH * 0.6)
                return i;
        }
        return -1;
    }
    function nameOf(i) {
        const e = DeskMenu.entry(menu.slots[i]);
        return e ? (e.short || e.label) : "?";
    }
    function persona(i) {
        const list = HellToys.part("fraud").masks || [];
        return list.length ? list[(i + cast) % list.length] : null;
    }
    function converse(i) {
        const f = HellToys.part("fraud"), m = persona(i);
        if (!m)
            return;
        menu.current = i;
        const p = pointOf(i);
        talk.at = Qt.point(p.x, p.y - maskH / 2);
        // it claims to be another entry
        let other = i;
        if (n > 1)
            while (other === i)
                other = Math.floor(Math.random() * n);
        const who = HellToys.t(m.who);
        talk.say(who, HellToys.t(m.claim, nameOf(other)), [{
                "label": HellToys.t(f.believe),
                "run": () => {
                    look.fooled++;
                    look.swayV += 60;
                    Sounds.play("demon");
                    talk.say(who, HellToys.t(m.fooled), [], 1600);
                }
            }, {
                "label": HellToys.t(f.unmask),
                "run": () => {
                    if (!look.bare.includes(i)) {
                        look.bare = look.bare.concat([i]);
                        look.unmasked++;
                    }
                    Sounds.playSoft("click", 1);
                    talk.say(who, HellToys.t(m.confess, look.nameOf(i)), [{
                            "label": HellToys.t(f.open, look.nameOf(i)),
                            "run": () => {
                                talk.hide();
                                look.menu.activate(i);
                            }
                        }, {
                            "label": HellToys.t(f.hang),
                            "run": () => talk.hide()
                        }]);
                }
            }]);
    }
    function nav(e) {
        if (e.key === Qt.Key_Escape && talk.open) {
            talk.hide();
            return true;
        }
        return menu.walk(e);
    }
    anchors.fill: parent
    readonly property bool talking: talk.open
    Connections {
        target: look.menu && look.menu.opened ? look.menu : null
        ignoreUnknownSignals: true
        function onOpened() {
            look.cast = Math.floor(Math.random() * 8);
            look.bare = [];
        }
    }

    // the swing settles like a pendulum
    FrameAnimation {
        running: look.sway !== 0 || look.swayV !== 0
        onTriggered: {
            const dt = Math.min(0.05, frameTime);
            look.swayV += (-28 * look.sway - 2.2 * look.swayV) * dt;
            look.sway = Math.max(-35, Math.min(35, look.sway + look.swayV * dt));
            if ((Math.abs(look.sway) < 0.05 && Math.abs(look.swayV) < 0.05) || Motion.still) {
                look.sway = 0;
                look.swayV = 0;
            }
        }
    }
    SequentialAnimation {
        id: turnAnim
        NumberAnimation {
            target: look
            property: "turning"
            from: 0
            to: 1
            duration: Motion.ms(140)
        }
        ScriptAction {
            script: look.turned = !look.turned
        }
        NumberAnimation {
            target: look
            property: "turning"
            to: 0
            duration: Motion.ms(160)
        }
    }
    CircleToy {
        menu: look.menu
        radius: look.reach
        center: Qt.point(look.menu.cx, look.menu.cy)
        cursorShape: held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        hoverEnabled: on
        onDown: (x, y, right) => {
            if (right) {
                held = false;
                const i = look.maskAt(x, y);
                if (i >= 0) {
                    look.converse(i);
                    return;
                }
                turnAnim.restart();
                Sounds.playSoft("click", 0.9);
                return;
            }
            look.lastX = x;
            look.swayV += (x < look.menu.cx ? -1 : 1) * 40;
        }
        onDrag: (x, y) => {
            look.swayV += (x - look.lastX) * 2.5;
            look.lastX = x;
        }
    }

    // the string they hang on
    Canvas {
        x: look.menu.cx - look.rx - Theme.u * 4
        y: look.menu.cy - look.ry - Theme.u * 4
        width: (look.rx + Theme.u * 4) * 2
        height: (look.ry + Theme.u * 4) * 2
        scale: 0.6 + 0.4 * look.menu.reveal
        opacity: look.menu.reveal
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const u = Theme.u, cx = width / 2, cy = height / 2;
            ctx.fillStyle = Theme.hellRim.toString();
            for (let t = 0; t < 2 * Math.PI; t += 0.012) {
                const x = cx + Math.cos(t) * look.rx, y = cy + Math.sin(t) * look.ry;
                ctx.fillRect(Math.round(x / u) * u, Math.round(y / u) * u, u, u);
            }
        }
    }

    CircleHub {
        menu: look.menu
        size: Math.round(look.maskW * 1.1)
        color: Theme.hellFace
        nameGap: Theme.u * 2
    }

    Repeater {
        model: look.menu.slots
        CircleEntry {
            id: mask
            menu: look.menu
            readonly property point at: look.pointOf(index, hot ? 1.08 : 1)
            readonly property bool bone: (index % 2 === 0) !== look.turned
            // torn off: the face under it, raw
            readonly property bool torn: look.bare.includes(index)
            readonly property color face: torn ? Theme.mix(Theme.hellBlood, Theme.hellText, 0.25) : bone ? Theme.hellText : Theme.mix(Theme.hellFaceAlt, Theme.hellTextDim, 0.25)
            readonly property color type: torn ? Theme.hellText : bone ? Theme.hellBody : Theme.hellText
            width: look.maskW
            height: look.maskH + look.labelRoom
            // the swing hangs from the string: each its own way, a little more or less
            transformOrigin: Item.Top
            rotation: look.sway * (index % 2 ? 1 : 0.7)
            x: at.x - width / 2
            y: at.y - look.maskH / 2
            opacity: Math.min(1, look.menu.reveal * 1.4)
            Behavior on x {
                NumberAnimation {
                    duration: Motion.ms(90)
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Motion.ms(90)
                }
            }
            Item {
                id: shape
                width: look.maskW
                height: look.maskH
                transform: Scale {
                    origin.x: shape.width / 2
                    xScale: Math.max(0.05, 1 - look.turning)
                }
                rotation: mask.hot ? 0 : (mask.index % 3 - 1) * 8 + (1 - look.menu.reveal) * 30
                Behavior on rotation {
                    NumberAnimation {
                        duration: Motion.ms(120)
                    }
                }
                // the face: broad brow, narrow chin
                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: width * 0.3
                    topRightRadius: width * 0.3
                    bottomLeftRadius: width / 2
                    bottomRightRadius: width / 2
                    color: mask.face
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: mask.hot ? Theme.hellAccent : Theme.hellRim
                }
                // the eye slits, slanted — sad on the dark ones
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        width: look.maskW * 0.26
                        height: Math.max(2, Theme.u * 1.5)
                        radius: height / 2
                        x: index ? shape.width * 0.62 : shape.width * 0.38 - width
                        y: shape.height * 0.28
                        rotation: (index ? -1 : 1) * (mask.bone ? -12 : 12)
                        color: Theme.hellBody
                    }
                }
                CircleIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.45
                    hot: mask.hot
                    name: mask.icon
                    pixel: Math.max(1, Math.round(Theme.u * look.k * 0.75))
                    ink: mask.type
                    light: mask.face
                    body: Theme.mix(mask.face, mask.type, 0.2)
                    fill: mask.hot ? Theme.hellBlood : Theme.mix(mask.type, mask.face, 0.35)
                }
            }
            CircleLabel {
                visible: look.menu.labels
                hot: mask.hot
                anchors.horizontalCenter: shape.horizontalCenter
                y: look.maskH + Theme.u * 2
                text: mask.label
            }
        }
    }

    CircleHint {
        menu: look.menu
        rule: "masks"
        below: look.ry + look.maskH / 2 + look.labelRoom
        status: look.unmasked || look.fooled ? HellToys.t(HellToys.part("fraud").unmasked, look.unmasked, look.fooled) : ""
    }
    CircleTalk {
        id: talk
        menu: look.menu
    }

    CircleFly {
        menu: look.menu
        reach: look.reach
        at: look.menu.flyIndex >= 0 ? look.pointOf(look.menu.flyIndex, 1.15) : Qt.point(look.menu.cx, look.menu.cy)
    }
}
