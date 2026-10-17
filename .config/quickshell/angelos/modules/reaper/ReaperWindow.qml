pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "ReaperCore.js" as Core
import "ReaperArt.js" as Art
import "ReaperLines.js" as Lines

// «Смерть на смене» (services/Reaper), after Peace, Death!: Death's office (ReaperArt), the souls
// float in from the queue one by one and say something; ← Heaven, ↓ Limbo, → Hell, by the rules
// on the left (ReaperCore.js). Before a day the Boss (the eye on the monitor) or a colleague comes
// to talk (ReaperLines.js) and brings the day's new rule; after a shift the Boss has his say.
// Sort the day's quota before the time runs out, three mistakes end the shift.
FloatingWindow {
    id: root

    title: Shell.appTitle + " · " + I18n.t("Смерть на смене", "Death on shift")
    visible: Reaper.open
    color: "transparent"
    implicitWidth: 1120
    implicitHeight: 790
    minimumSize: Qt.size(820, 600)
    onClosed: Reaper.open = false
    onVisibleChanged: if (!visible) {
        Reaper.open = false;
        phase = "menu";
    }

    property string phase: "menu"        // menu | talk | play | end
    // the day on the memo: the next one to play, or the one being played / just ended
    property int playing: 1
    readonly property int day: phase === "menu" ? Reaper.day : playing
    property var soul: ({})
    property var said: ({
            "ru": "",
            "en": ""
        })
    property int done: 0
    property int wrong: 0
    property real left: 0
    property bool won: false
    property string ending: ""           // won | time | mistakes
    property string why: ""              // the rule a mistake broke
    property int talked: 0               // the day whose talk was already heard
    property var lines: []               // the talk, or the Boss after a shift
    property int lineAt: 0
    readonly property var line: lines[lineAt] || null
    readonly property string visitor: phase === "talk" ? (lines.map(l => l.who).find(w => !!Art.people[w]) || "") : ""
    readonly property int quota: Core.quota(day)
    readonly property int seconds: Core.seconds(day)
    readonly property var rules: Core.active(day)
    readonly property var fresh: Core.newRule(day)

    function place(to) {
        return to === "heaven" ? I18n.t("Рай", "Heaven") : to === "hell" ? I18n.t("Ад", "Hell") : I18n.t("Чистилище", "Limbo");
    }
    function pick(list) {
        return list[Math.floor(Math.random() * list.length)];
    }
    function newSoul() {
        soul = Core.make(day);
        said = Lines.soulLine(soul);
    }

    function start() {
        playing = Reaper.day;
        done = 0;
        wrong = 0;
        left = seconds;
        why = "";
        newSoul();
        phase = "play";
        scene.arrive();
    }
    // Enter / the big button: a day not talked about yet starts with its talk; after a shift
    // handed in, first the next day's memo
    function proceed() {
        if (phase === "talk")
            return next();
        if (phase === "end" && won) {
            phase = "menu";
            return;
        }
        if (phase === "menu" && talked !== Reaper.day) {
            playing = Reaper.day;
            talked = playing;
            lines = Lines.talk(playing);
            lineAt = 0;
            phase = "talk";
            scene.arrive();
            return;
        }
        start();
    }
    function next() {
        if (!talkBox.typed)
            talkBox.shown = talkBox.full.length;
        else if (lineAt + 1 < lines.length)
            lineAt++;
        else if (phase === "talk")
            start();
    }
    function finish(ok, how) {
        scene.open = "";
        won = ok;
        ending = ok ? "won" : how;
        lines = [pick(Lines.after[ending])];
        lineAt = 0;
        phase = "end";
        if (ok)
            Reaper.passed(day);
    }
    function sort(to) {
        if (phase !== "play" || scene.mode === "out")
            return;
        const v = Core.verdict(soul, day);
        const ok = v.to === to;
        if (ok) {
            done++;
            why = "";
        } else {
            wrong++;
            why = "✗ " + (v.rule ? I18n.t(v.rule.ru, v.rule.en) : I18n.t("иначе → Рай", "otherwise → Heaven"));
        }
        scene.send(to, ok);
    }
    // the soul is gone through its door: the shift may be over, or the next one floats in
    function gone() {
        if (done >= quota)
            finish(true);
        else if (wrong >= Core.mistakes)
            finish(false, "mistakes");
        else {
            newSoul();
            scene.arrive();
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.phase === "play" && root.visible
        onTriggered: {
            root.left = Math.max(0, root.left - 0.1);
            if (root.left <= 0)
                root.finish(false, "time");
        }
    }

    component Key: Shortcut {
        context: Qt.WindowShortcut
    }
    Key {
        sequences: ["Left", "A", "Ф", "1"]
        onActivated: root.sort("heaven")
    }
    Key {
        sequences: ["Down", "S", "Ы", "2"]
        enabled: root.day >= 5
        onActivated: root.sort("limbo")
    }
    Key {
        sequences: ["Right", "D", "В", "3"]
        onActivated: root.sort("hell")
    }
    Key {
        sequences: ["Return", "Enter", "Space"]
        enabled: root.phase !== "play"
        onActivated: root.proceed()
    }
    Key {
        sequence: "Escape"
        onActivated: root.phase === "talk" ? root.start() : Reaper.open = false
    }

    PxWindow {
        id: frame
        anchors.fill: parent
        anchors.rightMargin: Theme.u * 2
        anchors.bottomMargin: Theme.u * 2
        translucent: false
        title: "angelOS · " + I18n.t("Смерть на смене", "Death on shift")
        icon: "skull"
        onCloseClicked: Reaper.open = false
        onTitlePressed: root.startSystemMove()

        Item {
            anchors.fill: parent

            // ---- the memo: today's rules, the higher one wins ----
            PxBox {
                id: memo
                width: Theme.u * 96
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                sunken: true

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.pad
                    spacing: Theme.u * 3

                    PxText {
                        kind: "title"
                        text: I18n.t("Памятка · день ", "Memo · day ") + root.day
                    }
                    PxText {
                        width: parent.width
                        dim: true
                        wrapMode: Text.WordWrap
                        text: I18n.t("Сверху — важнее: решает первое, что совпало.", "Higher wins: the first match decides.")
                    }
                    Repeater {
                        model: root.rules
                        PxText {
                            required property var modelData
                            required property int index
                            width: parent.width
                            wrapMode: Text.WordWrap
                            color: root.fresh && modelData.id === root.fresh.id ? Theme.accent : Theme.text
                            text: (index + 1) + ". " + I18n.t(modelData.ru, modelData.en) + (root.fresh && modelData.id === root.fresh.id ? I18n.t("  · новое", "  · new") : "")
                        }
                    }
                    PxText {
                        dim: true
                        text: I18n.t("иначе → Рай", "otherwise → Heaven")
                    }
                }
            }

            Item {
                id: board
                anchors.left: memo.right
                anchors.leftMargin: Theme.pad
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                // ---- the shift: day, souls, mistakes, time ----
                Item {
                    id: head
                    width: parent.width
                    height: Theme.u * 18
                    visible: root.phase === "play"
                    Row {
                        spacing: Theme.pad
                        anchors.verticalCenter: parent.verticalCenter
                        PxText {
                            kind: "title"
                            text: I18n.t("День ", "Day ") + root.day
                        }
                        PxText {
                            kind: "title"
                            text: I18n.t("Души ", "Souls ") + root.done + "/" + root.quota
                        }
                        Row {
                            spacing: Theme.u
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: Core.mistakes
                                PxIcon {
                                    required property int index
                                    name: index < Core.mistakes - root.wrong ? "heart" : "heartBroken"
                                }
                            }
                        }
                    }
                    PxText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.danger
                        text: root.why
                    }
                    PxProgress {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Theme.u * 3
                        showText: false
                        value: root.left / root.seconds
                        fill: root.left < 10 ? Theme.danger : Theme.accent
                    }
                }

                Item {
                    id: stageArea
                    anchors.top: head.bottom
                    anchors.topMargin: Theme.u * 3
                    anchors.bottom: panel.top
                    anchors.bottomMargin: Theme.u * 3
                    width: parent.width

                    PxBox {
                        anchors.centerIn: scene
                        width: scene.width + inset * 2
                        height: scene.height + inset * 2
                        sunken: true
                    }

                    // ---- Death's office ----
                    Item {
                        id: scene
                        readonly property int k: Math.max(1, Math.floor(Math.min((parent.width - Theme.u * 4) / Art.W, (parent.height - Theme.u * 4) / Art.H)))
                        width: Art.W * k
                        height: Art.H * k
                        anchors.centerIn: parent
                        clip: true

                        // the soul (or the visitor): floating in from the queue, standing, gone
                        property string mode: "stay"     // in | stay | out
                        property real t: 1
                        property string dir: "heaven"
                        property string open: ""          // the door that is open
                        property bool angry: false
                        property bool glint: false
                        property string stampText: ""
                        property color stampColor: "white"
                        property real shake: 0
                        // the ambient beat: the candle, Heaven's rays, the bobbing, the fog
                        property int tick: 0
                        property bool blink: false
                        property int shown: 0             // the soul's words typed so far

                        readonly property var stand: Art.at.stand
                        readonly property var target: dir === "heaven" ? [Art.at.heaven[0] + 6, 30] : dir === "hell" ? [Art.at.hell[0] + 6, 30] : [stand[0], stand[1] + 28]
                        readonly property real px: mode === "in" ? stand[0] : mode === "out" ? stand[0] + (target[0] - stand[0]) * t : stand[0]
                        readonly property real py: mode === "in" ? Art.at.queue[1] + (stand[1] - Art.at.queue[1]) * t : mode === "out" ? stand[1] + (target[1] - stand[1]) * t : stand[1] + (Math.floor(tick / 4) % 2)
                        readonly property real fade: mode === "in" ? 0.35 + 0.65 * t : mode === "out" && dir !== "limbo" ? Math.min(1, (1 - t) * 2.5) : 1
                        readonly property bool talking: phase === "talk" && !talkBox.typed

                        function arrive() {
                            leave.stop();
                            mode = "in";
                            t = 0;
                            shown = 0;
                            come.restart();
                        }
                        function send(to, ok) {
                            come.stop();
                            dir = to;
                            open = to;
                            mode = "out";
                            t = 0;
                            stampText = ok ? root.place(to) : "✗";
                            stampColor = !ok ? Art.colors.r : to === "heaven" ? Art.colors.y : to === "hell" ? Art.colors.L : Art.colors.V;
                            glint = true;
                            angry = !ok;
                            if (!ok)
                                shaking.restart();
                            flash.restart();
                            leave.restart();
                        }

                        transform: Translate {
                            x: Math.round(scene.shake) * scene.k
                        }

                        NumberAnimation {
                            id: come
                            target: scene
                            property: "t"
                            from: 0
                            to: 1
                            duration: 240
                            onFinished: {
                                scene.mode = "stay";
                                scene.open = "";
                            }
                        }
                        NumberAnimation {
                            id: leave
                            target: scene
                            property: "t"
                            from: 0
                            to: 1
                            duration: 280
                            onFinished: root.gone()
                        }
                        SequentialAnimation {
                            id: shaking
                            NumberAnimation {
                                target: scene
                                property: "shake"
                                to: 2
                                duration: 40
                            }
                            NumberAnimation {
                                target: scene
                                property: "shake"
                                to: -2
                                duration: 80
                            }
                            NumberAnimation {
                                target: scene
                                property: "shake"
                                to: 1
                                duration: 60
                            }
                            NumberAnimation {
                                target: scene
                                property: "shake"
                                to: 0
                                duration: 40
                            }
                        }
                        Timer {
                            id: flash
                            interval: 420
                            onTriggered: {
                                scene.glint = false;
                                scene.angry = false;
                                scene.stampText = "";
                            }
                        }
                        Timer {
                            interval: 160
                            repeat: true
                            running: root.visible && !Motion.still
                            onTriggered: scene.tick++
                        }
                        Timer {
                            interval: 2600 + Math.random() * 3000
                            repeat: true
                            running: root.visible && !Motion.still
                            onTriggered: {
                                scene.blink = true;
                                unblink.restart();
                            }
                        }
                        Timer {
                            id: unblink
                            interval: 140
                            onTriggered: scene.blink = false
                        }
                        Timer {
                            interval: 28
                            repeat: true
                            running: bubble.visible && scene.shown < bubble.full.length
                            onTriggered: scene.shown++
                        }

                        component Px: PxIcon {
                            property real ax: 0
                            property real ay: 0
                            x: Math.round(ax) * scene.k
                            y: Math.round(ay) * scene.k
                            pixel: scene.k
                            palette: Art.colors
                        }

                        Px {
                            bitmap: Art.room()
                        }
                        // Heaven: its light, the door; open, the light spills on the floor
                        Px {
                            ax: Art.at.heaven[0] + 3
                            ay: Art.at.heaven[1] + 3
                            bitmap: Art.heavenLight(scene.tick % 7)
                        }
                        Px {
                            ax: Art.at.heaven[0] + 3
                            ay: Art.at.heaven[1] + 3
                            visible: scene.open !== "heaven"
                            bitmap: Art.doors().heaven
                        }
                        Px {
                            ax: Art.at.heaven[0] + 3 - 7
                            ay: 65
                            visible: scene.open === "heaven"
                            bitmap: Art.spill("H", Art.at.heaven[2] - 6, 14)
                        }
                        // Hell: flames behind its door
                        Px {
                            ax: Art.at.hell[0] + 3
                            ay: Art.at.hell[1] + 3
                            visible: scene.open === "hell"
                            bitmap: Art.fire(scene.tick % 8)
                        }
                        Px {
                            ax: Art.at.hell[0] + 3
                            ay: Art.at.hell[1] + 3
                            visible: scene.open !== "hell"
                            bitmap: Art.doors().hell
                        }
                        Px {
                            ax: Art.at.hell[0] + 3 - 7
                            ay: 65
                            visible: scene.open === "hell"
                            bitmap: Art.spill("L", Art.at.hell[2] - 6, 14)
                        }
                        // the clock: the shift's time going round
                        Px {
                            ax: Art.at.clock[0]
                            ay: Art.at.clock[1]
                            bitmap: Art.clock(root.phase === "play" ? Math.min(11, Math.floor((1 - root.left / root.seconds) * 12)) : 0)
                        }
                        // the Boss: off in the menu; watching the soul, looking down at Death to talk
                        Px {
                            ax: Art.at.screen[0]
                            ay: Art.at.screen[1]
                            readonly property bool on: root.phase !== "menu"
                            readonly property bool boss: !!root.line && root.line.who === "boss"
                            bitmap: Art.eye(!on ? null : scene.blink ? 0.15 : 1, root.phase === "play" ? Math.max(-1, Math.min(1, Math.round((scene.px + 9 - 100) / 40 * 6) / 6)) : 0, boss || root.phase === "end" ? 1 : 0.4, scene.angry)
                        }
                        // the next soul waiting in the back door
                        Item {
                            x: (Art.at.back[0] + 2) * scene.k
                            y: (Art.at.back[1] + 2) * scene.k
                            width: (Art.at.back[2] - 4) * scene.k
                            height: (Art.at.back[3] - 2) * scene.k
                            clip: true
                            visible: root.phase === "play" && root.quota - root.done > 1
                            Px {
                                ax: Art.at.queue[0] - Art.at.back[0] - 2
                                ay: Art.at.queue[1] - Art.at.back[1] - 2 + (Math.floor(scene.tick / 5) % 2)
                                bitmap: Core.body
                                opacity: 0.3
                            }
                        }
                        // the hatch open: the hole, the fog
                        Px {
                            ax: Art.at.hatch[0]
                            ay: Art.at.hatch[1] - 14
                            visible: scene.open === "limbo"
                            bitmap: Art.hole(scene.tick % 4)
                        }
                        // its shadow on the floor
                        Px {
                            ax: scene.stand[0] + 3
                            ay: 81
                            visible: (root.phase === "play" || root.visitor) && scene.mode !== "out"
                            bitmap: ["..########..", "############", "..########.."]
                            palette: ({
                                    "#": Art.colors.C
                                })
                            opacity: scene.mode === "in" ? scene.t : 1
                        }
                        // the soul, or today's visitor; it sinks into the hatch to Limbo
                        Item {
                            width: scene.width
                            height: scene.mode === "out" && scene.dir === "limbo" ? (Art.at.hatch[1] + 3) * scene.k : scene.height
                            clip: true
                            Px {
                                ax: scene.px
                                ay: scene.py + (root.visitor && scene.talking && root.line.who === root.visitor ? scene.tick % 2 : 0)
                                visible: root.phase === "play" || !!root.visitor
                                opacity: scene.fade
                                bitmap: root.visitor ? Art.people[root.visitor] : Core.sprite(root.soul)
                                palette: Object.assign({}, Art.colors, {
                                    "s": Art.tints[root.soul.look || 0]
                                })
                            }
                        }
                        // Death and her scythe; it glints when she sends a soul off
                        Px {
                            ax: Art.at.scythe[0]
                            ay: Art.at.scythe[1] - (scene.glint ? 2 : 0)
                            bitmap: Art.scythe(scene.glint)
                        }
                        Px {
                            ax: Art.at.death[0]
                            ay: Art.at.death[1] + (scene.talking && root.line.who === "death" ? scene.tick % 2 : Math.floor(scene.tick / 6) % 2)
                            bitmap: Art.death
                        }
                        Px {
                            ax: Art.at.candle[0]
                            ay: Art.at.candle[1] + 1
                            bitmap: Art.flame[Motion.still ? 0 : [0, 1, 0, 2, 1][scene.tick % 5]]
                        }

                        // what the soul says
                        Rectangle {
                            id: bubble
                            readonly property string full: I18n.t(root.said.ru, root.said.en)
                            visible: root.phase === "play" && scene.mode === "stay" && full.length > 0
                            x: Art.at.bubble[0] * scene.k
                            y: (Art.at.bubble[1] + 8) * scene.k - height / 2
                            width: measure.width + scene.k * 6
                            height: measure.height + scene.k * 4
                            color: Art.colors.w
                            border.color: Art.colors["#"]
                            border.width: scene.k
                            Px {
                                ax: -4
                                ay: Math.round(bubble.height / scene.k / 2) - 2
                                bitmap: ["...##", ".##ww", "#wwww", ".##ww", "...##"]
                            }
                            PxText {
                                id: measure
                                visible: false
                                width: Math.min(implicitWidth, scene.k * 74)
                                wrapMode: Text.WordWrap
                                text: bubble.full
                            }
                            PxText {
                                x: scene.k * 3
                                y: scene.k * 2
                                width: measure.width
                                wrapMode: Text.WordWrap
                                color: Art.colors["#"]
                                text: bubble.full.substring(0, scene.shown)
                            }
                        }
                        // where it went, big; a mistake: a red cross
                        PxText {
                            visible: scene.stampText !== ""
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 42 * scene.k
                            kind: "big"
                            color: scene.stampColor
                            style: Text.Outline
                            styleColor: Art.colors["#"]
                            text: scene.stampText
                        }
                        // the talk goes on with a click anywhere on the picture
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.phase === "talk"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.next()
                        }
                    }
                }

                // ---- below the picture: the menu, the talk, the buttons ----
                Item {
                    id: panel
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Theme.u * 46

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.pad
                        visible: root.phase === "play"
                        PxButton {
                            icon: "arrowLeft"
                            text: root.place("heaven")
                            onClicked: root.sort("heaven")
                        }
                        PxButton {
                            visible: root.day >= 5
                            icon: "arrowDown"
                            text: root.place("limbo")
                            onClicked: root.sort("limbo")
                        }
                        PxButton {
                            icon: "arrowRight"
                            text: root.place("hell")
                            onClicked: root.sort("hell")
                        }
                    }

                    // before a shift
                    PxBox {
                        anchors.fill: parent
                        visible: root.phase === "menu"
                        Column {
                            anchors.left: parent.left
                            anchors.right: menuButtons.left
                            anchors.margins: Theme.pad
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u * 2
                            PxText {
                                kind: "big"
                                text: I18n.t("Смерть на смене", "Death on shift")
                            }
                            PxText {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: I18n.t("Души идут по одной. ← Рай, → Ад", "Souls come one by one. ← Heaven, → Hell") + (root.day >= 5 ? I18n.t(", ↓ Чистилище", ", ↓ Limbo") : "") + I18n.t(" — как велит памятка. Норма ", " — as the memo says. Quota ") + root.quota + I18n.t(" душ за ", " souls in ") + root.seconds + I18n.t(" с, три ошибки — провал.", " s, three mistakes and it's over.")
                            }
                            PxText {
                                visible: !!root.fresh
                                color: Theme.accent
                                text: root.fresh ? I18n.t("Новое правило: ", "New rule: ") + I18n.t(root.fresh.ru, root.fresh.en) : ""
                            }
                        }
                        Column {
                            id: menuButtons
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.pad
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u * 2
                            PxButton {
                                anchors.right: parent.right
                                accent: true
                                text: I18n.t("Начать день ", "Start day ") + root.day
                                onClicked: root.proceed()
                            }
                            PxButton {
                                anchors.right: parent.right
                                visible: root.day > 1
                                flat: true
                                compact: true
                                text: I18n.t("С первого дня", "Back to day one")
                                onClicked: Reaper.restart()
                            }
                            PxText {
                                anchors.right: parent.right
                                visible: Reaper.best > 0
                                dim: true
                                kind: "tiny"
                                text: I18n.t("Лучший день: ", "Best day: ") + Reaper.best
                            }
                        }
                    }

                    // the talk, and the Boss after a shift: who speaks, the line typed out
                    PxBox {
                        id: talkBox
                        anchors.fill: parent
                        visible: root.phase === "talk" || root.phase === "end"
                        readonly property var who: root.line ? Lines.cast[root.line.who] : null
                        readonly property string full: root.line ? I18n.t(root.line.ru, root.line.en) : ""
                        property int shown: 0
                        readonly property bool typed: shown >= full.length
                        onFullChanged: shown = 0

                        Timer {
                            interval: 24
                            repeat: true
                            running: talkBox.visible && !talkBox.typed
                            onTriggered: talkBox.shown++
                        }

                        // the speaker's face
                        PxBox {
                            id: face
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.pad
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.u * 36
                            height: Theme.u * 36
                            sunken: true
                            color: Art.colors.a
                            PxIcon {
                                anchors.centerIn: parent
                                readonly property string w: root.line ? root.line.who : ""
                                pixel: w === "boss" ? Theme.u : Theme.u + Theme.u / 2
                                palette: Art.colors
                                bitmap: w === "boss" ? Art.eye(scene.blink ? 0.15 : 1, 0, 0.4, root.phase === "end" && !root.won) : w === "death" ? Art.death.slice(0, 14).map(r => r.slice(4, 26)) : Art.people[w] ? Art.people[w].slice(0, 14) : []
                            }
                        }
                        Column {
                            anchors.left: face.right
                            anchors.leftMargin: Theme.pad
                            anchors.right: endButtons.visible ? endButtons.left : parent.right
                            anchors.rightMargin: Theme.pad
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u * 2
                            PxText {
                                kind: "title"
                                color: talkBox.who ? Art.colors[talkBox.who.c] : Theme.text
                                text: talkBox.who ? I18n.t(talkBox.who.ru, talkBox.who.en) : ""
                            }
                            PxText {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: talkBox.full.substring(0, talkBox.shown)
                            }
                            PxText {
                                visible: root.phase === "talk"
                                dim: true
                                kind: "tiny"
                                text: (talkBox.typed ? "▸ " : "  ") + I18n.t("Enter или клик — дальше · Esc — пропустить", "Enter or click — next · Esc — skip")
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.phase === "talk"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.next()
                        }
                        Column {
                            id: endButtons
                            visible: root.phase === "end"
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.pad
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u * 2
                            PxText {
                                anchors.right: parent.right
                                kind: "title"
                                color: root.won ? Theme.accent : Theme.danger
                                text: (root.won ? I18n.t("Смена сдана · ", "Shift done · ") : root.ending === "time" ? I18n.t("Время вышло · ", "Time's up · ") : I18n.t("Три ошибки · ", "Three mistakes · ")) + root.done + "/" + root.quota
                            }
                            PxButton {
                                anchors.right: parent.right
                                accent: true
                                text: root.won ? I18n.t("Дальше: день ", "Next: day ") + Reaper.day : I18n.t("Ещё раз", "Again")
                                onClicked: root.proceed()
                            }
                        }
                    }
                }
            }
        }
    }
}
