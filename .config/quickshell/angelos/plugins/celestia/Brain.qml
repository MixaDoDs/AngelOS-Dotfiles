pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Celestia's one mind: what she feels and where she looks. Every face (the desktop, the bar) only
// shows these values, so they stay in step and nothing runs twice. Springs carry the changes;
// at rest nothing but a slow clock moves. All of it stops when no face can be seen.
Singleton {
    id: root

    // for looking at her in another skin without switching it: "", mac or hell
    property string forceLook: ""
    property var pluginRef: null

    // ---- who can see her ----
    property int viewers: 0
    property var _seen: ({})
    function see(id, on) {
        if (on)
            _seen[id] = true;
        else
            delete _seen[id];
        viewers = Object.keys(_seen).length;
    }
    property bool paused: false
    readonly property bool active: viewers > 0 && !Motion.still && !paused

    // ---- moods: open, wide, happy, brow, squint, blush, mouth open/width/smile, sweat ----
    readonly property var moods: ({
        "calm":      { open: 1,    wide: 1,    happy: 0,    brow: 0,    squint: 0,    blush: 0,   mo: 0,    mw: 0.10, ms: 0.5,  sweat: 0, lookY: 0 },
        "happy":     { open: 1,    wide: 1.04, happy: 0.9,  brow: 0,    squint: 0,    blush: 0.55, mo: 0,   mw: 0.20, ms: 1,    sweat: 0, lookY: 0 },
        "laugh":     { open: 1,    wide: 1.06, happy: 1,    brow: 0,    squint: 0,    blush: 0.7, mo: 0.7,  mw: 0.20, ms: 1,    sweat: 0, lookY: 0.1 },
        "shy":       { open: 0.8,  wide: 0.95, happy: 0.3,  brow: -0.3, squint: 0.1,  blush: 1,   mo: 0,    mw: 0.07, ms: 0.5,  sweat: 0, lookY: -0.75 },
        "proud":     { open: 0.7,  wide: 1,    happy: 0.2,  brow: 0.2,  squint: 0.3,  blush: 0.2, mo: 0,    mw: 0.18, ms: 0.9,  sweat: 0, lookY: 0.25 },
        "smug":      { open: 0.62, wide: 1,    happy: 0,    brow: 0.35, squint: 0.35, blush: 0,   mo: 0,    mw: 0.15, ms: 0.65, sweat: 0, lookY: 0 },
        "thinking":  { open: 0.85, wide: 0.96, happy: 0,    brow: 0.15, squint: 0.2,  blush: 0,   mo: 0,    mw: 0.07, ms: -0.1, sweat: 0, lookY: 0.75 },
        "focus":     { open: 0.65, wide: 0.92, happy: 0,    brow: 0.3,  squint: 0.45, blush: 0,   mo: 0,    mw: 0.08, ms: 0,    sweat: 0, lookY: -0.2 },
        "waiting":   { open: 1,    wide: 1.08, happy: 0,    brow: -0.1, squint: 0,    blush: 0,   mo: 0,    mw: 0.09, ms: 0.25, sweat: 0, lookY: 0 },
        "surprised": { open: 1.15, wide: 1.2,  happy: 0,    brow: -0.2, squint: 0,    blush: 0.2, mo: 0.55, mw: 0.08, ms: 0,    sweat: 0, lookY: 0.1 },
        "concerned": { open: 0.9,  wide: 1,    happy: 0,    brow: -0.75, squint: 0.1, blush: 0,   mo: 0,    mw: 0.12, ms: -0.6, sweat: 0.5, lookY: -0.1 },
        "angry":     { open: 0.78, wide: 0.96, happy: 0,    brow: 0.95, squint: 0.2,  blush: 0.1, mo: 0,    mw: 0.14, ms: -0.8, sweat: 0, lookY: -0.1 },
        "sad":       { open: 0.72, wide: 0.96, happy: 0,    brow: -0.95, squint: 0.1, blush: 0,   mo: 0,    mw: 0.11, ms: -0.9, sweat: 0, lookY: -0.5 },
        "tired":     { open: 0.42, wide: 0.96, happy: 0,    brow: -0.4, squint: 0.2,  blush: 0,   mo: 0.12, mw: 0.08, ms: -0.2, sweat: 0.8, lookY: -0.35 },
        "sleepy":    { open: 0.25, wide: 0.96, happy: 0,    brow: -0.2, squint: 0.1,  blush: 0.1, mo: 0,    mw: 0.07, ms: 0.15, sweat: 0, lookY: -0.3 },
        "hide":      { open: 0.05, wide: 1,    happy: 0,    brow: 0,    squint: 0,    blush: 0.6, mo: 0,    mw: 0.05, ms: 0.2,  sweat: 0, lookY: 0 },
        "sing":      { open: 1,    wide: 1.03, happy: 0.85, brow: 0,    squint: 0,    blush: 0.35, mo: 0,   mw: 0.15, ms: 0.9,  sweat: 0, lookY: 0.1 }
    })
    // what a mood reads like, in Russian
    readonly property var words: ({
        "calm": "тут", "happy": "довольна", "laugh": "смеётся", "shy": "смущена", "proud": "гордится",
        "smug": "ухмыляется", "thinking": "думает", "focus": "работает", "waiting": "ждёт тебя",
        "surprised": "удивлена", "concerned": "беспокоится", "angry": "сердится", "sad": "грустит",
        "tired": "устала", "sleepy": "засыпает", "sing": "поёт", "hide": "не смотрит"
    })

    property string mood: "calm"
    property real strength: 1
    property string line: ""
    readonly property string word: chatting ? (chatState === "think" ? "думает…" : chatState === "hear" ? "слышу тебя…" : chatState === "talk" ? "" : "говори, хозяин") : sleeping ? "спит" : (words[shown] || "")
    readonly property string spoken: privateNow ? "" : line

    // music takes over a quiet face
    readonly property bool listening: Lyrics.playing && viewers > 0 && !Motion.still
    // what she is doing with Claude, under anything said out loud
    readonly property string pulseMood: {
        const st = Pulse.state;
        return st === "tool_start" ? "focus" : st === "turn_start" || st === "text" ? "thinking" : st === "needs_attention" ? "waiting" : st === "error" ? "concerned" : "";
    }
    // the plan's limit running out shows on her face
    readonly property string limitMood: Usage.ok && Usage.fiveLeft >= 0 && Usage.fiveLeft <= 12 ? "tired" : ""
    // privacy mode: she shuts her eyes and keeps quiet, whatever else is going on
    readonly property bool privateNow: Privacy.on
    readonly property string shown: privateNow ? "hide" : mood !== "calm" ? mood : pulseMood || (listening ? "sing" : limitMood || nightMood || "calm")
    property string nightMood: ""
    Timer {
        interval: 60000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            const h = new Date().getHours();
            root.nightMood = h >= 2 && h < 6 ? "sleepy" : "";
        }
    }
    readonly property bool busy: shown === "thinking" || shown === "focus"
    property bool sleeping: false

    function target(k) {
        const m = moods[shown] || moods.calm, c = moods.calm;
        return c[k] + (m[k] - c[k]) * (sleeping ? 0 : strength);
    }

    // ---- the values the faces draw ----
    // One clock moves all of them: 24 steps a second while anything is on its way, none at all
    // when she is still. (Springs on each property ran at the monitor's 165 Hz and made the
    // wallpaper's surface redraw with every frame: half a core under music.)
    property real open: 1
    property real wide: 1
    property real happy: 0
    property real brow: 0
    property real squint: 0
    property real blush: 0
    property real mouthOpen: 0
    property real mouthW: 0.10
    property real smile: 0.5
    property real sweat: 0
    property real think: 0
    property real lookX: 0
    property real lookY: 0
    property real music: 0
    property real tintA: 0
    property real blink: 1
    property real bounce: 0
    property real beat: 0
    property real glitch: 0
    property real clock: 0

    // the mood's colour over the ink: warm when happy, cold when sad, red when angry
    readonly property var tints: ({
        "happy": [1, 0.72, 0.84, 0.55], "laugh": [1, 0.72, 0.84, 0.65], "shy": [1, 0.55, 0.72, 0.6], "sing": [0.9, 0.7, 1, 0.5],
        "proud": [1, 0.86, 0.5, 0.5], "smug": [0.86, 0.72, 1, 0.45], "angry": [1, 0.24, 0.2, 0.8], "concerned": [1, 0.72, 0.4, 0.4],
        "sad": [0.45, 0.6, 1, 0.65], "tired": [0.6, 0.65, 0.8, 0.5], "surprised": [1, 1, 0.7, 0.4]
    })
    readonly property var _tint: tints[shown] || [0, 0, 0, 0]
    readonly property real tintR: _tint[0]
    readonly property real tintG: _tint[1]
    readonly property real tintB: _tint[2]

    property real lookTX: 0
    property real lookTY: 0
    readonly property var springs: ["open", "wide", "happy", "brow", "squint", "mouthW", "smile", "lookX", "lookY", "mouthOpen"]
    readonly property var glides: ["blush", "sweat", "think", "tintA", "music"]
    property var _vel: ({})
    property real _blinkAt: -1
    // something still has to be drawn over time: a drift, a song
    readonly property bool flowing: listening || busy || sleeping || sweat > 0.03 || think > 0.03
    property bool moving: true
    function nudge() {
        moving = true;
    }
    onSleepingChanged: nudge()
    onFlowingChanged: nudge()
    onActiveChanged: nudge()
    function goals() {
        return {
            "open": sleeping ? 0.07 : target("open"),
            "wide": target("wide"),
            "happy": sleeping ? 0 : target("happy"),
            "brow": target("brow"),
            "squint": target("squint"),
            "blush": target("blush"),
            "mouthOpen": shown === "sing" && !sleeping ? 0.15 + Bass.level * 0.2 : target("mo"),
            "mouthW": sleeping ? 0.06 : target("mw"),
            "smile": target("ms"),
            "sweat": target("sweat"),
            "think": shown === "thinking" ? 1 : 0,
            "tintA": sleeping ? 0 : _tint[3],
            "music": listening && !sleeping ? Bass.level / 3 : 0,
            "lookX": lookTX,
            "lookY": lookTY
        };
    }
    function step(dt) {
        const g = goals();
        let still = !flowing;
        for (const k of springs) {
            const x = root[k], v = ((_vel[k] || 0) + (g[k] - x) * 95 * dt) * 0.70;
            _vel[k] = v;
            const n = x + v * dt;
            if (Math.abs(g[k] - n) < 0.003 && Math.abs(v) < 0.02) {
                if (x !== g[k])
                    root[k] = g[k];
                _vel[k] = 0;
            } else {
                root[k] = n;
                still = false;
            }
        }
        for (const k of glides) {
            const x = root[k], n = x + (g[k] - x) * 0.22;
            if (Math.abs(g[k] - n) < 0.004) {
                if (x !== g[k])
                    root[k] = g[k];
            } else {
                root[k] = n;
                still = false;
            }
        }
        for (const k of ["bounce", "beat", "glitch"]) {
            const x = root[k];
            if (x > 0.01) {
                root[k] = x * 0.74;
                still = false;
            } else if (x !== 0)
                root[k] = 0;
        }
        if (_blinkAt >= 0) {
            _blinkAt += dt;
            const ph = _blinkAt / 0.19;
            blink = ph >= 1 ? 1 : 1 - Math.sin(ph * Math.PI) * 0.94;
            if (ph >= 1)
                _blinkAt = -1;
            else
                still = false;
        }
        if (flowing)
            clock = (clock + dt) % 3600;
        if (still)
            moving = false;
    }
    Timer {
        interval: 42
        repeat: true
        running: root.active && root.moving
        onTriggered: root.step(interval / 1000)
    }
    Timer {
        id: blinkTimer
        running: root.active && !root.sleeping
        repeat: true
        interval: 3200
        onTriggered: {
            interval = 2200 + Math.random() * 4300;
            root._blinkAt = 0;
            root.nudge();
        }
    }
    // the eyes wander on their own unless someone is near
    property real gazeUntil: 0
    Timer {
        running: root.active && !root.sleeping
        repeat: true
        interval: 2800
        onTriggered: {
            interval = 1800 + Math.random() * 3600;
            if (Date.now() < root.gazeUntil)
                return;
            const m = root.moods[root.shown] || root.moods.calm;
            root.lookTX = (Math.random() * 2 - 1) * (root.busy ? 0.25 : 0.7);
            root.lookTY = m.lookY + (Math.random() * 2 - 1) * 0.22;
            root.nudge();
        }
    }
    onShownChanged: {
        const m = moods[shown] || moods.calm;
        lookTY = m.lookY;
        nudge();
    }
    // x, y: -1..1 from the middle of a face, the mouse over it
    function lookAt(x, y) {
        gazeUntil = Date.now() + 1400;
        lookTX = Math.max(-1, Math.min(1, x));
        lookTY = Math.max(-1, Math.min(1, y));
        nudge();
        awake();
    }

    // ---- moods and words ----
    Timer {
        id: moodTimer
        onTriggered: root.setMood("calm", 1, "", 0)
    }
    Timer {
        id: lineTimer
        onTriggered: root.line = ""
    }
    function setMood(name, power, text, seconds) {
        mood = moods[name] ? name : "calm";
        strength = power > 0 ? Math.min(1, power) : 1;
        awake();
        moodTimer.stop();
        if (mood !== "calm" && seconds !== 0) {
            moodTimer.interval = Math.max(2, seconds > 0 ? seconds : 25) * 1000;
            moodTimer.start();
        }
        if (text)
            say(text, seconds);
    }
    function pick(list) {
        return list[Math.floor(Math.random() * list.length)];
    }
    // her words appear letter by letter
    property string typed: ""
    Timer {
        interval: 34
        repeat: true
        running: root.typed.length < root.spoken.length
        onTriggered: {
            root.typed = root.spoken.slice(0, root.typed.length + 1);
            root.pip(root.typed.charAt(root.typed.length - 1));
        }
    }
    // in a talk every other letter gets the angel's voice, the demon's in hell
    property int _pips: 0
    function pip(c) {
        if (!chatting || !Sounds.ready || !/\S/.test(c) || (_pips++ % 2))
            return;
        const name = Theme.hell ? "voiceDemon" : "voiceAngel";
        Sounds.playFile(Sounds.dir + "/" + name + ".wav", Sounds.volumeOf(name));
    }
    onSpokenChanged: typed = ""
    function say(text, seconds) {
        line = text;
        lineTimer.interval = Math.max(4, seconds > 0 ? seconds : 7 + text.length / 12) * 1000;
        lineTimer.restart();
        awake();
    }

    // ---- a talk: three clicks open it, three close it ----
    // scripts/chat.py listens, asks Claude, answers. The microphone is open only while it runs.
    property bool chatting: false
    property string chatState: ""      // listen | think | talk
    readonly property string chatScript: Quickshell.env("HOME") + "/.config/angelos/plugins/celestia/scripts/chat.py"
    function startChat(text) {
        if (chatting)
            return;
        if (privateNow)
            return say("не сейчас, хозяин, приватность", 4);
        chatting = true;
        chatState = "listen";
        awake();
        chat.command = text ? ["python3", "-I", chatScript, "--text", text] : ["python3", "-I", chatScript];
        chat.running = true;
    }
    function stopChat(bye) {
        chat.running = false;
        chatting = false;
        chatState = "";
        setMood("happy", 0.8, bye || "хорошо поболтали, хозяин", 6);
    }
    onPrivateNowChanged: if (privateNow && chatting)
        stopChat("приватность, молчу")
    Process {
        id: chat
        stdout: SplitParser {
            onRead: l => {
                let ev;
                try {
                    ev = JSON.parse(l);
                } catch (e) {
                    return;
                }
                root.chatEvent(ev);
            }
        }
        onExited: if (root.chatting)
            root.stopChat("")
    }
    function chatEvent(ev) {
        awake();
        if (ev.e === "listen") {
            chatState = "listen";
            setMood("waiting", 1, "", 0);
        } else if (ev.e === "voice") {
            chatState = "hear";
            line = "";
        } else if (ev.e === "level") {
            // she leans in with the voice
            beat = Math.max(beat, ev.v);
            nudge();
        } else if (ev.e === "think") {
            chatState = "think";
            setMood("thinking", 1, "", 0);
        } else if (ev.e === "say") {
            chatState = "talk";
            setMood(ev.mood, 1, ev.text, 0);
        } else if (ev.e === "error") {
            shock();
            setMood("concerned", 1, "что-то со связью, хозяин", 0);
        } else if (ev.e === "end") {
            stopChat("ты замолчал, пойду работать");
        }
    }
    property var _clicks: []
    // every click on her face: a poke, and three quick ones start or end a talk
    function click() {
        const n = Date.now();
        _clicks = _clicks.filter(t => n - t < 700).concat([n]);
        if (_clicks.length >= 3) {
            _clicks = [];
            sendTimer.stop();
            if (chatting)
                stopChat("");
            else
                startChat("");
            return;
        }
        if (chatting)
            sendTimer.restart();
        else
            poke();
    }
    // one click in a talk: "I am done, answer", unless it turns out to be three
    Timer {
        id: sendTimer
        interval: 420
        onTriggered: if (root.chatting && root.chatState === "hear")
            chat.signal(10)
    }

    // ---- a touch ----
    property int pokes: 0
    readonly property var pokeLines: ["ой", "эй, щекотно", "я работаю, хозяин", "ну хватит", "это что, тест?", "ещё раз, и обижусь", "ладно, смешно"]
    function poke() {
        awake();
        pokes++;
        bounce = 1;
        nudge();
        if (pluginRef)
            pluginRef.progress("poke-100");
        const n = pokes % 7;
        setMood(n === 3 || n === 5 ? "smug" : n === 6 ? "laugh" : "surprised", 1, pokeLines[pokes % pokeLines.length], 4);
    }
    function shock() {
        glitch = 1;
        nudge();
    }

    // ---- music: Bass runs only while someone counts in ----
    property bool _inBass: false
    onListeningChanged: {
        if (listening === _inBass)
            return;
        _inBass = listening;
        Bass.walls += listening ? 1 : -1;
    }
    Connections {
        target: Bass
        enabled: root.listening && !root.sleeping
        function onKicked() {
            root.bounce = 1;
            root.beat = 1;
            root.nudge();
        }
    }

    // ---- her own remarks, on what happens around her ----
    function greet() {
        const h = new Date().getHours();
        const l = h < 5 ? ["ты чего не спишь, хозяин?", "ночь же, хозяин"] : h < 12 ? ["доброе утро, хозяин", "утро, хозяин. Кофе уже?"] : h < 18 ? ["привет, хозяин", "я тут"] : ["добрый вечер, хозяин", "вечер, хозяин. Чилим?"];
        setMood("happy", 0.8, pick(l), 6);
    }
    Timer {
        interval: 2500
        running: true
        onTriggered: root.greet()
    }
    Connections {
        target: Motion
        function onGamingChanged() {
            if (!Motion.gaming)
                root.setMood("proud", 0.8, root.pick(["ну как игра, хозяин?", "с возвращением", "кто победил?"]), 6);
        }
    }
    property real _lastTrackAt: 0
    Connections {
        target: Lyrics
        function onTrackKeyChanged() {
            const n = Date.now();
            if (root.listening && n - root._lastTrackAt > 90000 && Math.random() < 0.25) {
                root._lastTrackAt = n;
                root.say(root.pick(["о, этот трек", "качает", "хороший выбор, хозяин", "ставлю лайк мысленно"]), 5);
            }
        }
    }
    property bool _warnedLimit: false
    onLimitMoodChanged: if (limitMood && !_warnedLimit) {
        _warnedLimit = true;
        setMood("tired", 1, "лимиты кончаются, хозяин", 8);
    } else if (!limitMood)
        _warnedLimit = false

    // ---- a notification: she glances to the corner it comes from ----
    function glance() {
        gazeUntil = Date.now() + 1800;
        lookTX = 0.95;
        lookTY = -0.2;
        nudge();
        awake();
    }
    // ---- Claude: a turn ends well, an error jolts her ----
    Connections {
        target: Pulse
        function onStateChanged() {
            root.awake();
            if (Pulse.state === "turn_end" && root.mood === "calm")
                root.setMood("happy", 0.8, "", 4);
            else if (Pulse.state === "error")
                root.shock();
        }
    }
    Connections {
        target: Usage
        function onFiveChanged() {
            const left = Usage.fiveLeft;
            if (root._lastLeft >= 0 && left - root._lastLeft > 50)
                root.setMood("happy", 1, "лимиты снова полные", 8);
            root._lastLeft = left;
        }
    }
    property real _lastLeft: -1

    // ---- sleep: nothing happening for a while ----
    function awake() {
        if (sleeping) {
            sleeping = false;
            Qt.callLater(() => root.say(root.pick(["м? я не сплю", "с возвращением", "я только прикрыла глаза"]), 5));
        }
        sleepTimer.restart();
    }
    Timer {
        id: sleepTimer
        interval: 300000
        running: root.active && !root.listening && !root.chatting
        onTriggered: root.sleeping = true
    }
}
