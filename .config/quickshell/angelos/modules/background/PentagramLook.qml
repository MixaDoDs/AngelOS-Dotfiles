pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.background.circles

// Hell's look of RadialMenu (while the demon rules, or picked by hand): a pentagram that
// draws itself around the pointer in the circle's colours (HellLook via Theme.hell*). The
// first five entries sit on its points, the rest are runes on the outer circle between
// them; an unlit candle stands at each point; flyouts open as a FlyColumn in hell's
// colours. The middle (horned logo) closes. Only the drawing moves — hell is still.
// The toy (Settings → Right-click menu → toys): click a candle to light it, again to blow it
// out; light all five and the pentagram wakes and pulls a soul up out of the circles — a
// sinner from one of them (story/toys.json → summon) to ask who it is and why it's here, then
// let go: it sinks back and the candles go out.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property color blood: Theme.hellRim
    readonly property color ember: Theme.hellAccent
    readonly property color bone: Theme.hellText
    readonly property color pit: Theme.hellPlate
    readonly property real slotSize: Math.round(Theme.u * 22 * k)
    readonly property real runeSize: Math.round(Theme.u * 16 * k)
    readonly property real labelRoom: menu.labels ? Theme.sizeTiny + Theme.u * 3 : 0
    readonly property int rays: Math.min(5, menu.slots.length)
    readonly property int runes: Math.max(0, menu.slots.length - 5)
    readonly property real star: Math.round(Theme.u * 58 * k)                 // the points' radius
    readonly property real ring: star + slotSize * 0.5 + labelRoom + runeSize * 0.7 + Theme.u * 4
    readonly property real reach: ring + runeSize + labelRoom
    readonly property Item blurItem: null
    function angleOf(i) {
        if (i < 5)
            return -Math.PI / 2 + i * 2 * Math.PI / 5;
        // runes: one in each gap while they fit, else evenly all around
        const j = i - 5;
        if (runes <= 5)
            return -Math.PI / 2 + (j + 0.5) * 2 * Math.PI / 5;
        return -Math.PI / 2 + (j + 0.5) * 2 * Math.PI / runes;
    }
    function radiusOf(i) {
        return i < 5 ? star : ring;
    }
    // the toy: which candles burn, and the glow when all five do
    property var candles: [false, false, false, false, false]
    property real wake: 0
    readonly property bool toys: Config.desktop.menuToys !== false
    // the soul pulled up: who (toys.json → summon.souls[…]), how far out, what's been asked
    property var soul: null
    property real soulUp: 0
    property var asked: []
    readonly property color soulInk: soul && HellLook.looks[soul.circle] && HellLook.looks[soul.circle].palette ? HellLook.looks[soul.circle].palette.accent : Theme.hellAccent
    function summon() {
        const list = HellToys.part("summon").souls || [];
        if (!list.length)
            return;
        soul = list[HellToys.summoned % list.length];
        HellToys.summoned++;
        asked = [];
        Achievements.note("hell.summon", soul.circle);
        riseAnim.restart();
        smoke.burst(menu.cx, menu.cy, {
            "n": 24,
            "colors": [Qt.alpha(Theme.hellTextDim, 0.6), Qt.alpha(look.ember, 0.6)],
            "size": 3,
            "speed": 60,
            "up": 80,
            "gravity": -40,
            "life": 1400
        });
    }
    // what the soul says, and what's left to ask it
    function speak(words) {
        const sm = HellToys.part("summon");
        const ask = [];
        if (!asked.includes("who"))
            ask.push({
                "label": HellToys.t(sm.askWho),
                "run": () => {
                    look.asked = look.asked.concat(["who"]);
                    look.speak(HellToys.t(look.soul.who));
                }
            });
        if (!asked.includes("why"))
            ask.push({
                "label": HellToys.t(sm.askWhy),
                "run": () => {
                    look.asked = look.asked.concat(["why"]);
                    look.speak(HellToys.t(look.soul.why));
                }
            });
        ask.push({
            "label": HellToys.t(sm.letGo),
            "run": () => look.release()
        });
        talk.at = Qt.point(menu.cx, menu.cy - slotSize * 0.6 - soulSprite.height);
        talk.say(HellToys.t(soul.name), words, ask);
    }
    function release() {
        if (!soul)
            return;
        talk.say(HellToys.t(soul.name), HellToys.t(soul.bye), [], 900);
        sinkAnim.restart();
    }
    function light(i, at) {
        if (soul)
            return;
        const c = candles.slice();
        c[i] = !c[i];
        candles = c;
        if (!noted) {
            noted = true;
            Achievements.note("deskmenu.toy", "pentagram");
        }
        sparks.burst(at.x, at.y, {
            "n": c[i] ? 6 : 5,
            "colors": c[i] ? [Theme.hellFlame, Theme.hellGold] : [Qt.alpha(Theme.hellTextDim, 0.7)],
            "size": 1.5,
            "speed": c[i] ? 50 : 25,
            "up": c[i] ? 60 : 40,
            "spread": 0.8,
            "gravity": c[i] ? 200 : -30,
            "life": c[i] ? 500 : 1000
        });
        if (c.every(x => x)) {
            wakeAnim.restart();
            Sounds.play("demon");
            summonSoon.restart();
        } else {
            Sounds.playSoft("key", 0.7);
        }
    }
    property bool noted: false
    function nav(e) {
        if (e.key === Qt.Key_Escape && soul) {
            release();
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
            look.noted = false;
            look.soul = null;
            look.soulUp = 0;
            look.candles = [false, false, false, false, false];
            look.wake = 0;
        }
    }
    Timer {
        id: summonSoon
        interval: Motion.still ? 1 : 900
        onTriggered: look.summon()
    }
    SequentialAnimation {
        id: riseAnim
        NumberAnimation {
            target: look
            property: "soulUp"
            from: 0
            to: 1
            duration: Motion.ms(1200)
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: look.speak(HellToys.t(look.soul.hello))
        }
    }
    // back down, and the candles go out one by one
    SequentialAnimation {
        id: sinkAnim
        PauseAnimation {
            duration: 1600
        }
        NumberAnimation {
            target: look
            property: "soulUp"
            to: 0
            duration: Motion.ms(900)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                look.soul = null;
                outOne.count = 0;
                outOne.start();
            }
        }
    }
    Timer {
        id: outOne
        property int count: 0
        interval: 160
        repeat: true
        onTriggered: {
            const c = look.candles.slice();
            c[count] = false;
            look.candles = c;
            count++;
            if (count >= 5) {
                stop();
                look.wake = 0;
            }
        }
    }
    SequentialAnimation {
        id: wakeAnim
        NumberAnimation {
            target: look
            property: "wake"
            to: 1
            duration: Motion.ms(300)
        }
        NumberAnimation {
            target: look
            property: "wake"
            to: 0.45
            duration: Motion.ms(900)
            easing.type: Easing.InOutSine
        }
    }

    // the dark of the pit under it
    Rectangle {
        x: look.menu.cx - width / 2
        y: look.menu.cy - height / 2
        width: (look.ring + look.runeSize) * 2 * Math.max(0.3, look.menu.reveal)
        height: width
        radius: width / 2
        color: Qt.alpha(Theme.hellBody, 0.7 * look.menu.reveal)
        border.width: Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(look.blood, 0.35 * look.menu.reveal)
    }

    // awake: a red glow from under the star
    Rectangle {
        visible: look.wake > 0 && look.candles.every(x => x)
        x: look.menu.cx - width / 2
        y: look.menu.cy - height / 2
        width: look.ring * 2.1
        height: width
        radius: width / 2
        color: Qt.alpha(look.ember, 0.22 * look.wake)
        border.width: Math.max(1, Theme.u * 2)
        border.color: Qt.alpha(look.ember, 0.6 * look.wake)
    }
    // the pentagram and its circles, drawn stroke by stroke as it opens — a shader
    // (shaders/pentagram.frag): the blurred Canvas it replaces stuttered on opening
    ShaderEffect {
        id: sigil
        readonly property real d: (look.ring + look.runeSize) * 2
        x: look.menu.cx - d / 2
        y: look.menu.cy - d / 2
        width: d
        height: d
        property real progress: look.menu.reveal
        property real side: d
        property real star: look.star
        property real ring: look.ring
        property real u: Theme.u
        property color blood: look.blood
        property color ember: look.ember
        fragmentShader: Qt.resolvedUrl("../../shaders/pentagram.frag.qsb")
    }

    // the middle: the (horned) logo; closes
    Rectangle {
        id: hub
        x: look.menu.cx - width / 2
        y: look.menu.cy - height / 2
        width: Math.round(look.slotSize * 1.2)
        height: width
        radius: width / 2
        scale: look.menu.reveal
        color: hubMouse.containsMouse ? Theme.hellFaceAlt : look.pit
        border.width: Math.max(1, Theme.u)
        border.color: look.blood
        AngelLogo {
            anchors.centerIn: parent
            emblemOnly: true
            hell: true
            pixel: Math.max(1, Math.round(Theme.u * look.k * 0.75))
        }
        MouseArea {
            id: hubMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                look.menu.current = -1;
                look.menu.fly = "";
            }
            onClicked: look.menu.close()
        }
    }
    // the hovered entry's full name, burnt above the middle
    Rectangle {
        visible: !!look.menu.hoveredEntry && look.menu.reveal > 0.6
        x: look.menu.cx - width / 2
        y: look.menu.cy - hub.height / 2 - height - Theme.u * 3
        width: hoverName.implicitWidth + Theme.u * 8
        height: hoverName.implicitHeight + Theme.u * 4
        color: look.pit
        border.width: Math.max(1, Theme.u / 2)
        border.color: look.blood
        PxText {
            id: hoverName
            anchors.centerIn: parent
            kind: "tiny"
            font.bold: true
            color: look.bone
            text: look.menu.hoveredEntry ? look.menu.hoveredEntry.label : ""
        }
    }

    // the points and the runes
    Repeater {
        model: look.menu.slots
        Item {
            id: slot
            required property string modelData
            required property int index
            readonly property var e: DeskMenu.entry(modelData)
            readonly property bool ray: index < 5
            readonly property real size: ray ? look.slotSize : look.runeSize
            readonly property real a: look.angleOf(index)
            readonly property bool sel: look.menu.current === index
            readonly property bool open: look.menu.fly === modelData
            // they light up once the stroke has reached them
            readonly property real lit: Math.max(0, Math.min(1, look.menu.reveal * 1.6 - (ray ? index * 0.12 : 0.6)))
            width: size
            height: size + look.labelRoom
            x: look.menu.cx + Math.cos(a) * look.radiusOf(index) - width / 2
            y: look.menu.cy + Math.sin(a) * look.radiusOf(index) - size / 2
            opacity: lit
            Rectangle {
                id: tile
                width: slot.size
                height: slot.size
                radius: slot.ray ? 0 : width / 2
                rotation: slot.ray ? 45 : 0
                scale: slot.sel || slot.open ? 1.15 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.ms(90)
                    }
                }
                color: slot.sel || slot.open ? Theme.hellFaceAlt : look.pit
                border.width: Math.max(1, Theme.u / 2)
                border.color: slot.sel || slot.open ? look.ember : look.blood
            }
            PxIcon {
                anchors.centerIn: tile
                name: slot.e ? slot.e.icon : "heart"
                pixel: Math.max(1, Math.round(Theme.u * look.k * (slot.ray ? 1 : 0.75)))
                // bone and the dim ink; the one you're on takes the accent
                ink: look.bone
                fill: slot.sel || slot.open ? look.ember : Theme.hellTextDim
                fill2: look.blood
                fill3: Theme.hellTextDim
                body: Theme.hellFaceAlt
                light: look.bone
                bad: look.ember
            }
            // a candle outside each point: a stub of wax, a wick, one ember — lit by the one
            // you're on, or for good by a click (the toy)
            PxIcon {
                id: candle
                readonly property bool burning: slot.ray && !!look.candles[slot.index]
                visible: slot.ray
                bitmap: ["..y..", "..#..", ".###.", ".#w#.", ".#w#.", ".###."]
                pixel: Math.max(1, Math.round(Theme.u * 0.75))
                ink: Theme.hellEdge
                light: Theme.hellTextDim
                fill3: candle.burning ? Theme.hellGold : slot.sel || slot.open ? look.ember : Theme.hellRim
                x: tile.width / 2 + Math.cos(slot.a) * (slot.size * 0.95) - width / 2
                y: tile.height / 2 + Math.sin(slot.a) * (slot.size * 0.95) - height / 2
                // its flame, flickering
                PxIcon {
                    visible: candle.burning
                    bitmap: ["..r..", ".rr..", ".ryr.", ".ryr."]
                    pixel: candle.pixel
                    bad: Theme.hellFlame
                    fill3: Theme.hellGold
                    x: (candle.width - width) / 2
                    y: -height + candle.pixel
                    SequentialAnimation on opacity {
                        running: candle.burning && !Motion.still
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.65
                            duration: 160
                        }
                        NumberAnimation {
                            to: 1
                            duration: 220
                        }
                    }
                }
                MouseArea {
                    enabled: look.toys
                    anchors.fill: parent
                    anchors.margins: -Theme.u * 3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: look.light(slot.index, mapToItem(look, width / 2, 0))
                }
            }
            PxText {
                visible: look.menu.labels
                anchors.horizontalCenter: tile.horizontalCenter
                y: slot.size + Theme.u * (slot.ray ? 3 : 1)
                width: Math.max(slot.size * 1.8, implicitWidth)
                horizontalAlignment: Text.AlignHCenter
                kind: "tiny"
                font.bold: slot.sel
                color: look.bone
                style: Text.Outline
                styleColor: look.pit
                text: slot.e ? (slot.e.short || slot.e.label) : ""
            }
            MouseArea {
                width: slot.size
                height: slot.size
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: look.menu.hoverEntry(slot.index)
                onClicked: look.menu.activate(slot.index)
            }
        }
    }

    // the soul, standing up out of the star: only what's above the floor shows
    Item {
        visible: !!look.soul && look.soulUp > 0
        x: look.menu.cx - soulSprite.width / 2
        y: look.menu.cy - look.slotSize * 0.6 - soulSprite.height * look.soulUp
        width: soulSprite.width
        height: soulSprite.height * look.soulUp
        clip: true
        z: 8
        PxIcon {
            id: soulSprite
            bitmap: ["...###...", "..#fff#..", "..#e#e#..", "..#fff#..", "...#f#...", ".##ooo##.", "#.#ooo#.#", "#.#ooo#.#", "f.#ooo#.f", "..#ooo#..", "..#ooo#..", "..#o.o#..", "..#o.o#..", "..##.##.."]
            pixel: Math.max(1, Math.round(Theme.u * look.k * 2))
            ink: Theme.hellEdge
            body: Theme.mix(look.bone, look.soulInk, 0.15)
            fill: look.soulInk
            palette: ({
                    "e": Theme.hex(Theme.hellEdge)
                })
            opacity: 0.9
            SequentialAnimation on y {
                running: !!look.soul && !Motion.still
                loops: Animation.Infinite
                NumberAnimation {
                    to: -Theme.u * 2
                    duration: 900
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0
                    duration: 900
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    CircleBits {
        id: sparks
    }
    CircleBits {
        id: smoke
    }
    CircleHint {
        menu: look.menu
        rule: "pentagram"
        below: look.reach
        status: HellToys.summoned ? HellToys.t(HellToys.part("summon").count, HellToys.summoned) : ""
    }
    CircleTalk {
        id: talk
        menu: look.menu
        onClosed: if (look.soul && sinkAnim.running === false && look.soulUp >= 1)
            look.release()
    }

    FlyColumn {
        menu: look.menu
        hell: true
        radius: look.ring + look.runeSize / 2 + look.labelRoom + Theme.u * 10
        reach: look.reach + Theme.u * 2
        angle: look.angleOf(look.menu.flyIndex)
    }
}
