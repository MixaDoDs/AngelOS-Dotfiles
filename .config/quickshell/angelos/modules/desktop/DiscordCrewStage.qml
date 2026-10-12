pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The people of the Discord call (DiscordCrew's window; the UI test builds it alone): kept by id
// in a ListModel, so a speaking flag changing sends no one back to the start; DiscordCrewGuy
// draws each. Each can be picked up with the pointer, carried and thrown: `hits` is where they
// take it, `flyers` are those in the hand or in the air — the stage is only a strip over the
// bar, so DiscordCrew draws them once more in a window over the whole screen (`room` high).
// The strip itself never changes its size under the pointer: a window that grows while it is
// dragged in gets the pointer's old places for a moment, and the one in the hand jumped up.
// Whoever leaves the call bursts (DiscordCrewBurst). A right click on one asks for their menu
// (`menuAsked`, the entries from itemsFor): the main one, bigger and smaller, muted or quieter
// for you alone, burst, hidden. Settings → Widgets → the Discord people: Config.discord.crew*.
Item {
    id: win

    readonly property int count: crew.count
    // everyone's art pixel: the shell's, one less or one more (Config.discord.crewSize)
    readonly property real u: Math.max(1, Theme.u + ({
            "s": -1,
            "l": 1
        }[Config.discord.crewSize] || 0))
    // the main one (Config.discord.crewMain: you, no one, or one picked from the menu) stands
    // out: half as big again, on whole pixels
    readonly property real bigU: Math.max(u + 1, Math.round(u * 1.5))
    // the height the tallest of them needs (DiscordCrew's window takes it)
    property real topU: u
    readonly property real tall: Math.max(u, topU) * 64
    signal menuAsked(var who, real x, real y)
    // those in the hand or in the air, and whether the pointer is on anyone (the window over
    // the screen is wanted then: it is there before the first one is lifted)
    property var flyers: []
    readonly property bool lifted: flyers.length > 0
    property bool near: false
    readonly property bool airWanted: lifted || near
    // how high they can be carried: the height over the floor that DiscordCrew has for them
    property real room: 0
    readonly property real ceiling: Math.max(height, room)
    readonly property real gravity: u * 1400        // px/s²
    // where they take the pointer, for the window's mask
    property var hits: []
    // those who burst: how many so far, how many still falling
    property int boomed: 0
    property int bursts: 0
    property string lastChannel: ""
    // where they may walk: the angel keeps her corner
    property string screenName: ""
    readonly property bool angelHere: Angel.shown && Angel.screenName === screenName
    readonly property bool angelLeft: Angel.streamer && Config.stream.streamerSide === "left"
    readonly property real minX: width * (angelHere && angelLeft ? 0.25 : 0.04)
    readonly property real maxX: width * (angelHere && !angelLeft ? 0.75 : 0.96) - u * 18

    // the call's people, kept by id: a speaking flag changing must not send anyone back to the start
    ListModel {
        id: crew
    }
    function sync() {
        const call = DiscordVoice.state === "call" ? DiscordVoice.users : [];
        const here = call.map(p => p.id);
        const hidden = Config.discord.crewHidden || [];
        const now = call.filter(p => !hidden.includes(p.id));
        const ids = now.map(p => p.id);
        // one who left the call you are still in bursts; changing the channel (or leaving it
        // yourself) just takes them away, and so does hiding one
        const boom = call.length > 0 && DiscordVoice.channel === lastChannel && !Motion.still && Config.discord.crewBurst;
        lastChannel = DiscordVoice.state === "call" ? DiscordVoice.channel : "";
        for (let i = crew.count - 1; i >= 0; i--)
            if (!ids.includes(crew.get(i).uid)) {
                const gone = rep.itemAt(i);
                if (boom && !here.includes(crew.get(i).uid))
                    burst(gone);
                if (flyers.includes(gone))
                    flyers = flyers.filter(g => g !== gone);
                crew.remove(i);
            }
        for (const p of now) {
            let i = 0;
            while (i < crew.count && crew.get(i).uid !== p.id)
                i++;
            const row = {
                "uid": p.id,
                "name": p.name || "?",
                "avatar": p.avatar || "",
                "speaking": !!p.speaking,
                "muted": !!(p.muted || p.deaf),
                "deaf": !!p.deaf,
                "me": !!p.me,
                "quiet": !!p.quiet,
                "volume": Number.isFinite(p.volume) ? Math.round(p.volume) : 100
            };
            if (i < crew.count)
                crew.set(i, row);
            else
                crew.append(row);
        }
        const out = [];
        for (let i = 0; i < rep.count; i++)
            if (rep.itemAt(i))
                out.push(rep.itemAt(i).hit);
        hits = out;
        recount();
    }
    function recount() {
        const up = [];
        let on = false, top = u;
        for (let i = 0; i < rep.count; i++) {
            const g = rep.itemAt(i);
            if (!g)
                continue;
            if (g.up)
                up.push(g);
            if (g.hovered)
                on = true;
            top = Math.max(top, g.u);
        }
        topU = top;
        if (up.length !== flyers.length || up.some((g, i) => g !== flyers[i]))
            flyers = up;
        near = on;
    }
    function burst(g) {
        if (!g)
            return;
        const b = burstC.createObject(fx, {
            "x": g.x + g.width / 2,
            "u": g.u,
            "alt": g.alt + g.hop,
            "coat": g.coat,
            "avatar": g.avatar,
            "initial": g.name.charAt(0).toUpperCase()
        });
        if (!b)
            return;
        boomed++;
        bursts++;
        b.done.connect(() => {
            win.bursts--;
            b.destroy();
        });
    }
    Component {
        id: burstC
        DiscordCrewBurst {}
    }
    function guyOf(id) {
        for (let i = 0; i < rep.count; i++)
            if (rep.itemAt(i) && rep.itemAt(i).uid === id)
                return rep.itemAt(i);
        return null;
    }
    // burst on the spot (the menu), and a new one of them drops from above
    function pop(id) {
        const g = guyOf(id);
        if (!g)
            return;
        if (!Motion.still)
            burst(g);
        g.dropIn();
    }
    function hide(id) {
        const list = (Config.discord.crewHidden || []).filter(x => x !== id);
        list.push(id);
        Config.discord.crewHidden = list;
    }
    // art pixels more (+) or fewer (−) for one of them
    function growOf(id) {
        return Number((Config.discord.crewSteps || {})[id]) || 0;
    }
    function setGrow(id, n) {
        const m = Object.assign({}, Config.discord.crewSteps || {});
        n = Math.max(1 - u, Math.min(u * 2, Math.round(n)));
        if (n)
            m[id] = n;
        else
            delete m[id];
        Config.discord.crewSteps = m;
    }
    function isMain(id, me) {
        return Config.discord.crewMain === "me" ? me : Config.discord.crewMain === id;
    }
    // one person's menu (right click): entries as DesktopMenu's lists take them. They look the
    // person up each time: the menu may stay open after they left
    function itemsFor(g) {
        const id = g.uid, me = g.me;
        const out = [
            {
                "label": I18n.t("Главный — крупнее всех", "The main one — bigger than the rest"),
                "icon": "star",
                "checkable": true,
                "checked": () => win.isMain(id, me),
                "keepOpen": true,
                "run": () => Config.discord.crewMain = win.isMain(id, me) ? "none" : me ? "me" : id
            },
            {
                "label": I18n.t("Увеличить", "Bigger"),
                "icon": "plus",
                "keepOpen": true,
                "run": () => win.setGrow(id, win.growOf(id) + 1)
            },
            {
                "label": I18n.t("Уменьшить", "Smaller"),
                "icon": "minus",
                "keepOpen": true,
                "run": () => win.setGrow(id, win.growOf(id) - 1)
            },
            {
                "label": I18n.t("Обычный размер", "Usual size"),
                "icon": "refresh",
                "checkable": true,
                "checked": () => win.growOf(id) === 0,
                "keepOpen": true,
                "run": () => win.setGrow(id, 0)
            }
        ];
        if (!me)
            out.push({
                "separator": true
            }, {
                "label": I18n.t("Заглушить для себя", "Mute for me"),
                "icon": "speaker",
                "checkable": true,
                "checked": () => !!(win.guyOf(id) || {}).quiet,
                "keepOpen": true,
                "run": () => DiscordVoice.quiet(id, !(win.guyOf(id) || {}).quiet)
            }, {
                "label": I18n.t("Громкость для себя", "Volume for me"),
                "icon": "speaker",
                "flyout": [25, 50, 100, 150, 200].map(v => ({
                            "label": v + " %",
                            "checkable": true,
                            "checked": () => (win.guyOf(id) || {}).volume === v,
                            "keepOpen": true,
                            "run": () => DiscordVoice.setVolume(id, v)
                        }))
            });
        out.push({
            "separator": true
        }, {
            "label": I18n.t("Взорвать", "Burst"),
            "icon": "skull",
            "run": () => win.pop(id)
        }, {
            "label": I18n.t("Спрятать", "Hide"),
            "icon": "eye",
            "run": () => win.hide(id)
        }, {
            "separator": true
        }, {
            "label": I18n.t("Настройки человечков…", "The little people's settings…"),
            "icon": "gear",
            "run": () => Shell.openSettings("widgets")
        });
        return out;
    }
    // the floor, for what is left of those who burst
    Item {
        id: fx
        y: win.height
        z: 2
    }
    Connections {
        target: DiscordVoice
        function onUsersChanged() {
            win.sync();
        }
        function onStateChanged() {
            win.sync();
        }
    }
    Connections {
        target: Config.discord
        function onCrewHiddenChanged() {
            win.sync();
        }
    }
    Component.onCompleted: sync()

    // a body colour per person, the same every call
    readonly property var coats: ["#e8668b", "#6ec3e8", "#f0b44c", "#8bd17c", "#b48cf0", "#f08a5d", "#5dd6c0", "#e0e070"]
    function coat(id) {
        let h = 0;
        for (const c of String(id))
            h = (h * 31 + c.charCodeAt(0)) >>> 0;
        return coats[h % coats.length];
    }

    Repeater {
        id: rep
        model: crew
        Item {
            id: guy
            required property string uid
            required property string name
            required property string avatar
            required property bool speaking
            required property bool muted
            required property bool deaf
            required property bool me
            required property bool quiet
            required property int volume
            required property int index

            readonly property bool main: win.isMain(uid, me)
            readonly property real u: Math.max(1, Math.min(win.u * 4, (main ? win.bigU : win.u) + win.growOf(uid)))
            onUChanged: win.recount()
            readonly property color coat: win.coat(uid)
            // a wider one stops sooner, to stay out of the angel's corner all the same
            readonly property real reach: Math.max(1, win.maxX - win.minX - (width - win.u * 18))
            width: u * 18
            height: win.height
            // a place of their own, taken once (as soon as the window has its width): someone
            // leaving (the index) must not move the rest
            property bool placed: false
            function place() {
                if (placed || win.width <= 0)
                    return;
                placed = true;
                x = win.minX + reach * ((index * 0.37 + 0.1) % 1);
            }
            Component.onCompleted: place()
            Connections {
                target: win
                function onWidthChanged() {
                    guy.place();
                }
            }
            z: up ? 3 : main ? 1 : 0
            property bool walking: false
            property bool facingLeft: false
            property int step: 0
            property real hop: 0
            property bool waving: false

            // ---- in the hand and in the air ----
            property real alt: 0                    // how high the feet are over the floor
            property bool held: false
            property bool flying: false
            readonly property bool up: held || flying
            readonly property bool kicking: walking || up
            readonly property bool hovered: hand.containsMouse
            onUpChanged: win.recount()
            onHoveredChanged: win.recount()
            property real vx: 0                     // px/s; `va` goes up
            property real va: 0
            property real offX: 0
            property real offAlt: 0
            property real lastX: 0
            property real lastY: 0
            property double lastT: 0
            property bool moved: false
            // where they take the pointer, in the stage's place (the window's mask)
            readonly property Region hit: Region {
                x: guy.x + guy.u * 2
                y: win.height - guy.alt - guy.hop - guy.u * 27
                width: guy.u * 14
                height: guy.u * 27
            }
            // (px, py) — the pointer on the stage
            function grab(px, py) {
                walk.stop();
                rest.stop();
                walking = false;
                waving = false;
                flying = false;
                held = true;
                moved = false;
                offX = px - x;
                offAlt = win.height - py - alt;
                vx = 0;
                va = 0;
                lastX = px;
                lastY = py;
                lastT = Date.now();
            }
            function dragTo(px, py) {
                if (!held)
                    return;
                if (!moved) {
                    if (Math.abs(px - lastX) + Math.abs(py - lastY) < win.u * 3)
                        return;
                    moved = true;
                }
                const now = Date.now();
                if (now > lastT) {
                    const k = 500 / (now - lastT), top = win.u * 1500;
                    vx = Math.max(-top, Math.min(top, vx * 0.5 + (px - lastX) * k));
                    va = Math.max(-top, Math.min(top, va * 0.5 + (lastY - py) * k));
                    if (Math.abs(px - lastX) > win.u)
                        facingLeft = px < lastX;
                    lastX = px;
                    lastY = py;
                    lastT = now;
                }
                x = Math.max(0, Math.min(win.width - width, px - offX));
                alt = Math.max(0, Math.min(Math.max(0, win.ceiling - u * 34), win.height - py - offAlt));
            }
            function drop() {
                if (!held)
                    return;
                held = false;
                // a click: a wave back
                if (!moved)
                    waving = true;
                // held still before letting go: straight down
                if (!moved || Date.now() - lastT > 90) {
                    vx = 0;
                    va = 0;
                }
                if (Motion.still || (alt <= 0 && Math.abs(vx) < win.u * 40 && va <= 0))
                    land();
                else
                    flying = true;
            }
            // from the top of the screen down to the floor
            function dropIn() {
                walk.stop();
                rest.stop();
                walking = false;
                waving = false;
                held = false;
                vx = 0;
                va = 0;
                if (Motion.still) {
                    land();
                    return;
                }
                alt = Math.max(0, win.ceiling - u * 34);
                flying = true;
            }
            function land() {
                flying = false;
                alt = 0;
                vx = 0;
                va = 0;
                rest.interval = 700 + Math.random() * 1800;
                rest.start();
            }
            // thrown: falls, bounces off the walls and once or twice off the floor
            FrameAnimation {
                running: guy.flying
                onTriggered: {
                    const dt = Math.min(0.05, frameTime);
                    const right = win.width - guy.width, top = Math.max(0, win.ceiling - guy.u * 34);
                    guy.va -= win.gravity * dt;
                    let nx = guy.x + guy.vx * dt, na = guy.alt + guy.va * dt;
                    if (nx < 0 || nx > right) {
                        nx = Math.max(0, Math.min(right, nx));
                        guy.vx = -guy.vx * 0.5;
                        guy.facingLeft = guy.vx < 0;
                    }
                    if (na > top) {
                        na = top;
                        guy.va = -Math.abs(guy.va) * 0.4;
                    }
                    guy.x = nx;
                    if (na > 0) {
                        guy.alt = na;
                    } else if (guy.va < -win.u * 220) {
                        guy.alt = 0;
                        guy.va = -guy.va * 0.38;
                        guy.vx *= 0.6;
                    } else {
                        guy.land();
                    }
                }
            }
            MouseArea {
                id: hand
                hoverEnabled: true
                x: guy.u * 2
                y: guy.height - guy.alt - guy.hop - guy.u * 27
                width: guy.u * 14
                height: guy.u * 27
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: guy.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                // the menu opens where the right button went down (as ContextClick does)
                property point down
                onPressed: m => {
                    const p = mapToItem(win, m.x, m.y);
                    if (m.button === Qt.RightButton)
                        down = p;
                    else
                        guy.grab(p.x, p.y);
                }
                onPositionChanged: m => {
                    const p = mapToItem(win, m.x, m.y);
                    guy.dragTo(p.x, p.y);
                }
                onReleased: m => {
                    if (m.button === Qt.RightButton && !guy.held)
                        win.menuAsked(guy, down.x, down.y);
                    else if (m.button !== Qt.RightButton)
                        guy.drop();
                }
                onCanceled: guy.drop()
            }

            // stroll: a new spot now and then, a pause in between
            function wander() {
                const to = win.minX + Math.random() * reach;
                facingLeft = to < x;
                walk.to = to;
                walk.duration = Math.max(400, Math.abs(to - x) / (u * 18) * 1000);
                walking = true;
                walk.start();
            }
            NumberAnimation {
                id: walk
                target: guy
                property: "x"
                easing.type: Easing.Linear
                onFinished: {
                    guy.walking = false;
                    guy.waving = Math.random() < 0.2;
                    rest.interval = 1200 + Math.random() * 4000;
                    rest.start();
                }
            }
            Timer {
                id: rest
                interval: 600 + Math.random() * 2000
                running: !Motion.still
                onTriggered: {
                    guy.waving = false;
                    if (!guy.up)
                        guy.wander();
                }
            }
            Timer {
                interval: 140
                repeat: true
                running: guy.kicking
                onTriggered: guy.step = (guy.step + 1) % 4
            }
            // whoever speaks hops (not in the hand: there they stay under the pointer)
            SequentialAnimation {
                running: guy.speaking && !Motion.still && !guy.up
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    guy.hop = 0
                NumberAnimation {
                    target: guy
                    property: "hop"
                    to: guy.u * 7
                    duration: 170
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: guy
                    property: "hop"
                    to: 0
                    duration: 170
                    easing.type: Easing.InQuad
                }
                PauseAnimation {
                    duration: 120
                }
            }

            DiscordCrewGuy {
                who: guy
                names: Config.discord.crewNames
                y: guy.height - guy.alt - guy.hop - height
            }
        }
    }
}
