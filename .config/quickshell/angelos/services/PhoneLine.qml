pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "PhoneScripts.js" as S
import "PhoneLore.js" as L

// The flip phone's line (modules/sidebar/Phone): who calls, who texts, what the numbers you
// dial answer, and its beeps. The texts are PhoneScripts.js.
//   calls     the angel (the demon while she rules) rings a couple of times a day and when
//             there is a reason: past midnight, a morning, back at the computer after half an
//             hour, not petted for days; the very first call once. Never more than two by
//             chance a day, never two within two hours, never over a full-screen window on the
//             phone's screen, nor while locked or idle; the cold angel (Story.angelStep ≥ 2)
//             doesn't call. A timer's end rings as the system (Config.phone.timerCalls).
//             Ringing: the phone comes out shut and shakes; opening its lid answers, the red
//             key declines (she says so from her corner), 25 s unanswered is a missed call
//             and a message from her. Talking: her lines type out on the screen with her voice,
//             you answer with 1 / 2 / 3; her last line said, she hangs up.
//   messages  she texts now and then (one a day at most); yours get her answer in a few seconds
//   numbers   777 the angel, 666 the demon (the other one answers while she rules), the codes
//             and the contacts of PhoneScripts.js; anything else is a wrong number
//   sounds    scripts/phone-sounds.py into ~/.local/share/angelos/sounds/phone (made once):
//             the keys' DTMF, the lid, the motor, the beeper's notes, tunes rendered per spec
//   saved     save.json → phone (Story.phone): messages, the call log, Snake, the call quotas
//   fun       prank calls (someone else on the line, in jest), chain letters, the tunes she sends
//             (the melody collection), a riddle a day whose answer dialled as *answer# gives a
//             piece of the tuning, the magic ball, the dropped phone's cracks (mended in an
//             hour, or at once by petting her), her selfies' captions
//   tuning    what the phone wears (Config.phone.look) and what opens each piece (looks, unlocked);
//             its first part is the model: the flip, the 3310 brick, the taco gamer (Phone)
//   battery   it runs down (the flip in a day, the taco in 16 hours, the brick in five days; four
//             times faster in a game, the camera or the torch) and charges from the extension lead
//             (Phone: the plug pulled into its port); empty, it is off: her calls go to the
//             voicemail, her messages wait for it to come on; dial 1 to hear the voicemail, the
//             bad line eating some of her words (what she said whole, a sister may tell you later)
//   the story the angel's hints (PhoneLore.js) come only here, a few a day at most, by the canon's
//             clock: a day since the first start is a second of her night, ten days a volume, and
//             only the volumes already come; while the demon rules it is the sister of the circle
//             who texts — as herself, remembering what you wrote and what you did (the stats)
//   replies   her message answered with one of three lines (warm, teasing her for 2002, a question,
//             care, dry — PhoneLore.options) or your own words; her answer goes by the tag
// Calls and texts are the game's (Story.enabled) and the phone look's (Config.sidebar.look).
Singleton {
    id: root

    readonly property bool on: Config.ready && Story.enabled && Story.ready && Sidebar.enabled && Sidebar.phone
    readonly property bool en: I18n.english
    function tr(pair) {
        return pair ? (en ? pair[1] : pair[0]) : "";
    }
    readonly property string who: Angel.demon ? "demon" : "angel"
    readonly property var tunes: S.tunes
    readonly property var looks: S.looks
    readonly property var stats: save && save.stats ? save.stats : ({})
    function bump(key, n) {
        if (!save)
            return;
        const st = Object.assign({}, stats);
        st[key] = n === undefined ? (st[key] || 0) + 1 : Math.max(st[key] || 0, n);
        save.stats = st;
    }
    readonly property var contacts: S.contacts.map(c => ({
                "name": tr(c.name),
                "number": c.number,
                "who": c.who
            }))
    function nameOf(w) {
        if (w === "demon" && sister)
            return tr(L.sisters[sister].name);
        const c = S.contacts.find(c => c.who === w);
        return c ? tr(c.name) : w;
    }
    // a message's sender as it was then (the sister who wrote it, not the one in the circle now)
    function nameOfMsg(m) {
        if (m.sister && L.sisters[m.sister])
            return tr(L.sisters[m.sister].name);
        return nameOf(m.from || m.to);
    }

    // ---- the sister: the demon of the circle you are in, as herself ----
    readonly property string sister: devSister || (Angel.demon && L.sisters[Story.circle] ? Story.circle : "")
    property string devSister: ""          // a test stand's sister (Shell.dev)
    // her own way of writing (Ira: only capitals)
    function voiced(text, sis) {
        return sis && L.sisters[sis] && L.sisters[sis].caps ? String(text).toUpperCase() : text;
    }

    // ---- the model ----
    readonly property string model: wearing("model")
    readonly property bool bar: model !== "flip"
    // a new model drains at its own rate from now on (the battery keeps the old one's until then).
    // Later, not now: Qt evaluates bindings lazily, and the first read of the model can come in
    // the middle of the battery's own binding — a write then is a binding loop
    onModelChanged: Qt.callLater(_rebase)

    // ---- the battery ----
    readonly property var batt: save && save.batt ? save.batt : null
    property bool hungry: false          // a game, the camera or the torch on (Phone)
    onHungryChanged: Qt.callLater(_rebase)
    function _rebase() {
        if (batt && (batt.hours !== hoursFull || !!batt.hungry !== hungry))
            _battSet({
                "hungry": hungry
            });
    }
    readonly property real hoursFull: ({
            "flip": 24,
            "3310": 120,
            "ngage": 16
        })[model] || 24
    // the level at a time, from the saved point: plugged it fills in 45 minutes; it drains at the
    // rate saved with the point (b.hours: the model's then; older saves, the model's now)
    function _battAt(b, t) {
        if (!b)
            return 1;
        const h = Math.max(0, t - b.at) / 3600000;
        return b.plug ? Math.min(1, b.lvl + h / 0.75) : Math.max(0, b.lvl - h / (b.hours || hoursFull) * (b.hungry ? 4 : 1));
    }
    readonly property real battery: _battAt(batt, now)
    readonly property bool plugged: !!batt && !!batt.plug
    readonly property bool dead: on && !!batt && !!batt.off
    function _battSet(patch) {
        if (!save)
            return;
        const t = Date.now();
        save.batt = Object.assign({
            "plug": false,
            "hungry": false,
            "off": false
        }, batt || {}, {
            "lvl": _battAt(batt, t),
            "at": t,
            "hours": hoursFull
        }, patch || {});
        now = t;
    }
    function plug(on) {
        if (!save || on === plugged)
            return;
        _battSet({
            "plug": on,
            "plugAt": on ? Date.now() : 0,
            "smoked": false
        });
        play(on ? "plug" : "click", 0.7);
        if (on)
            bump("charges");
        _battCheck();
    }
    signal powered(bool on)                    // it died, or came on (Phone: the screen)
    onPowered: on => {
        if (!on && call)
            hangUp();
    }
    function _battCheck() {
        if (!save)
            return;
        if (!batt) {
            save.batt = {
                "lvl": 1,
                "at": Date.now(),
                "hours": hoursFull,
                "plug": false,
                "hungry": false,
                "off": false
            };
            return;
        }
        const lvl = battery;
        if (!batt.off && lvl <= 0) {
            _battSet({
                "off": true,
                "warned": false
            });
            powered(false);
        } else if (batt.off && batt.plug && lvl >= 0.03) {
            _battSet({
                "off": false
            });
            play("boot", 0.8);
            powered(true);
            _wake();
        } else if (!batt.off && !batt.plug && lvl < 0.1 && !batt.warned) {
            _battSet({
                "warned": true
            });
            play("low", 0.8);
            info(tr(L.battery.low));
        } else if (batt.warned && lvl > 0.2) {
            _battSet({
                "warned": false
            });
        }
        if (batt.plug && lvl >= 1 && !batt.full) {
            _battSet({
                "full": true
            });
            info(tr(L.battery.full));
        } else if (batt.full && (!batt.plug || lvl < 0.95)) {
            _battSet({
                "full": false
            });
        }
    }
    // the phone's own short words (the battery), on its screen a moment (PhoneScreen)
    property string notice: ""
    property double noticeAt: 0
    function info(text) {
        notice = text;
        noticeAt = Date.now();
    }
    // on again: what waited comes in, the voicemail says how many
    function _wake() {
        const wait = save.pending || [];
        save.pending = [];
        for (const m of wait.slice().reverse())
            _store(m);
        if (wait.length)
            texted(wait[0].from);
        const n = (save.voice || []).filter(v => !v.heard).length;
        if (n)
            receive("voicemail", tr(L.voicemail.waiting).replace("%n", n));
    }

    // ---- the voicemail: her calls while it was off ----
    readonly property int voiceNew: save ? (save.voice || []).filter(v => !v.heard).length : 0
    function _toVoicemail(w, steps, lore, sis) {
        // what she said: her first line, and on along her first answer's way (two lines at most)
        const lines = [];
        let st = steps[0], n = 0;
        while (st && n < 2) {
            lines.push(st.s);
            st = st.a && st.a.length ? steps[st.a[0][2]] : null;
            n++;
        }
        save.voice = [{
                "who": w,
                "sister": sis || "",
                "at": Date.now(),
                "lines": lines,
                "lore": lore || "",
                "heard": false
            }].concat(save.voice || []).slice(0, 12);
        _log({
            "who": w,
            "name": nameOf(w),
            "kind": "missed"
        });
        bump("turned");
    }
    // the bad line: some words go under the hiss (the same ones every time it is played)
    function garble(text, seed) {
        let x = seed % 2147483647 || 7;
        const rnd = () => (x = (x * 16807) % 2147483647) / 2147483647;
        const out = [];
        for (const w of String(text).split(/\s+/)) {
            const hiss = rnd() < 0.36;
            if (hiss && out.length && out[out.length - 1] === "~")
                continue;
            out.push(hiss ? "~" : w);
        }
        return out.join(" ").replace(/~/g, tr(L.voicemail.hiss));
    }
    function playVoicemail() {
        const all = save ? save.voice || [] : [];
        const list = all.filter(v => !v.heard);
        const queue = list.length ? list : all.slice(0, 1);
        const steps = [];
        for (const v of queue.slice().reverse()) {
            const head = tr(L.voicemail.head).replace("%s", v.sister && L.sisters[v.sister] ? tr(L.sisters[v.sister].name) : nameOf(v.who)).replace("%t", I18n.time(new Date(v.at), false));
            steps.push({
                "s": [head, head],
                "next": steps.length + 1
            });
            for (const l of v.lines) {
                const t = garble(voiced(tr(l), v.sister), v.at + steps.length);
                steps.push({
                    "s": [t, t],
                    "voice": v.who
                });
            }
        }
        if (!steps.length)
            steps.push({
                "s": L.voicemail.none
            });
        // heard: a hint under the hiss is lost (a sister may tell it whole later)
        if (save) {
            const lost = list.filter(v => v.lore).map(v => v.lore);
            if (lost.length)
                _loreSave({
                    "lost": Array.from(new Set(((save.lore || {}).lost || []).concat(lost)))
                });
            save.voice = all.map(v => Object.assign({}, v, {
                    "heard": true
                }));
        }
        call = {
            "who": "voicemail",
            "name": nameOf("voicemail"),
            "kind": "voice",
            "outgoing": true,
            "steps": steps,
            "step": 0,
            "text": "",
            "answers": [],
            "state": "ring",
            "since": Date.now()
        };
        pickUp.restart();
    }

    // ---- sounds ----
    readonly property string dir: Sounds.base + "/phone"
    property bool ready: false
    Process {
        id: pack
        command: ["python3", Quickshell.shellDir + "/scripts/phone-sounds.py", "pack", root.dir]
        onExited: code => root.ready = code === 0
    }
    function ensure() {
        if (!ready && !pack.running)
            pack.running = true;
    }
    onOnChanged: if (on)
        ensure()
    readonly property bool loud: Config.y2k.sounds && !StreamMode.quiet && !Sounds.quietNow()
    function vol(k) {
        return Math.min(1, Sounds.volumeOf("notify") * k * (StreamMode.active ? 0.5 : 1));
    }
    function play(name, k) {
        if (ready && loud)
            Sounds.playFile(dir + "/" + name + ".wav", vol(k || 1));
    }
    function tone(key) {
        if (!Config.phone.keyTones)
            return;
        const n = key === "*" ? "Star" : key === "#" ? "Hash" : /^[0-9]$/.test(key) ? key : "";
        if (n)
            play("key" + n, 0.3);
    }
    function note(midi) {
        play("note" + Math.max(48, Math.min(95, midi)), 0.45);
    }

    // a tune (the composer's words) rendered once into its own file, then played
    property var rendered: ({})
    property var _renderQueue: []
    function tunePath(spec) {
        let h = 5381;
        for (let i = 0; i < spec.length; i++)
            h = ((h << 5) + h + spec.charCodeAt(i)) >>> 0;
        return dir + "/tune-" + h.toString(16) + ".wav";
    }
    // how long it plays (ms): a whole note is four beats at 160 a minute
    function tuneMs(spec) {
        let beats = 0;
        for (const tok of String(spec).trim().split(/\s+/)) {
            const m = /^(\d*)/.exec(tok);
            const d = Math.max(1, Number(m[1]) || 4);
            if (tok.replace(/^\d*/, "").length)
                beats += 4 / d * (tok.endsWith(".") ? 1.5 : 1);
        }
        return Math.round(beats * 375);
    }
    function render(spec, then) {
        if (!spec)
            return;
        if (rendered[spec]) {
            if (then)
                then(tunePath(spec));
            return;
        }
        _renderQueue = _renderQueue.concat([[spec, then]]);
        _renderNext();
    }
    function _renderNext() {
        if (renderer.running || !_renderQueue.length)
            return;
        const job = _renderQueue[0];
        renderer.job = job;
        renderer.command = ["python3", Quickshell.shellDir + "/scripts/phone-sounds.py", "melody", job[0], tunePath(job[0])];
        renderer.running = true;
    }
    Process {
        id: renderer
        property var job: null
        onExited: code => {
            const job = renderer.job;
            root._renderQueue = root._renderQueue.slice(1);
            if (code === 0 && job) {
                const r = Object.assign({}, root.rendered);
                r[job[0]] = true;
                root.rendered = r;
                if (job[1])
                    job[1](root.tunePath(job[0]));
            }
            root._renderNext();
        }
    }
    function playTune(spec, k) {
        if (ready && loud)
            render(spec, p => Sounds.playFile(p, vol(k || 0.8)));
    }

    // ---- the save ----
    readonly property var save: Story.phone
    readonly property var sms: save && save.sms ? save.sms : []
    readonly property int unread: sms.filter(m => m.from && !m.read).length
    readonly property var log: save && save.log ? save.log : []
    readonly property int missedCount: log.filter(l => l.kind === "missed" && !l.seen).length
    function _log(entry) {
        if (!save)
            return;
        save.log = [Object.assign({
                "at": Date.now()
            }, entry)].concat(log).slice(0, 40);
    }
    function seenLog() {
        if (save && missedCount)
            save.log = log.map(l => Object.assign({}, l, {
                    "seen": true
                }));
    }
    function readAll(from) {
        if (save)
            save.sms = sms.map(m => !from || m.from === from || m.to === from ? Object.assign({}, m, {
                    "read": true
                }) : m);
    }
    readonly property var quotas: save && save.calls ? save.calls : ({})
    function _quota(patch) {
        if (save)
            save.calls = Object.assign({}, quotas, patch);
    }
    readonly property string today: Qt.formatDate(new Date(now), "yyyy-MM-dd")
    property double now: Date.now()
    Timer {
        interval: 60000
        running: root.on
        repeat: true
        onTriggered: {
            root.now = Date.now();
            root._battCheck();
        }
    }
    // later, not in the binding that first read the save (a write there is a binding loop)
    onSaveChanged: if (save)
        Qt.callLater(_battCheck)

    // ---- messages ----
    signal texted(string from)                 // a message came (the phone beeps and shakes a moment)
    // extra: {sister, lore} — who of the sisters wrote it, which of the angel's hints it is
    function receive(from, text, extra) {
        if (!save || !text)
            return;
        const m = Object.assign({
            "from": from,
            "text": from === "demon" ? voiced(text, sister) : text,
            "at": Date.now(),
            "read": false
        }, from === "demon" && sister ? {
            "sister": sister
        } : {}, extra || {});
        // off: it waits for the phone to come on
        if (dead) {
            save.pending = (save.pending || []).concat([m]).slice(-20);
            return;
        }
        _store(m);
        play("sms", 0.7);
        texted(from);
    }
    function _store(m) {
        save.sms = [m].concat(sms).slice(0, 60);
    }
    // tag: how it sounds (PhoneLore.options' tags; your own words are read by PhoneLore.words);
    // re: the message it answers (her hint's question gets her own answer)
    function send(to, text, tag, re) {
        text = String(text || "").trim();
        if (!save || !text)
            return;
        if (dead)
            return;
        tag = tag || tagOf(text);
        const sis = to === "demon" ? sister : "";
        save.sms = [Object.assign({
                "to": to,
                "text": text,
                "at": Date.now(),
                "read": true
            }, sis ? {
                "sister": sis
            } : {})].concat(sms).slice(0, 60);
        Achievements.note("phone.sms", to);
        bump("sms");
        remember(sis || to, text, tag);
        if (/люблю|love/i.test(text))
            bump("love");
        if (tag === "tease" && to === "angel")
            bump("tease");
        if (tag === "dry" && to === "angel")
            bump("dry");
        // she answers if she is the one in the corner; the other one, sometimes
        if (to === "angel" || to === "demon") {
            replyTimer.to = to;
            replyTimer.text = text;
            replyTimer.tag = tag;
            replyTimer.lore = re && re.lore && tag === "ask" ? re.lore : "";
            replyTimer.interval = 2500 + Math.random() * 5000;
            replyTimer.restart();
        }
    }
    function tagOf(text) {
        const hit = L.words.find(r => r.re.test(String(text).trim()));
        return hit ? hit.tag : "";
    }
    // her answer: to her hint's question her own words; else by the tag; else the old rules
    function answerTo(w, text, tag, lore) {
        if (lore) {
            const item = L.lore.find(l => l.id === lore);
            if (item && item.ask)
                return tr(item.ask[1]);
        }
        if (w === "demon" && sister) {
            const r = L.sisters[sister].react;
            return tr(pick(r[tag] || r[["warm", "tease", "care", "dry", "ask"][Math.floor(Math.random() * 5)]], "react" + sister + tag));
        }
        if (w === "angel" && tag && L.react.angel[tag])
            return tr(pick(L.react.angel[tag], "react" + tag));
        const rules = S.replies[w] || [];
        const hit = rules.find(r => r.re.test(text));
        return tr(pick(hit ? hit.r : S.replyElse[w], "reply" + w));
    }
    Timer {
        id: replyTimer
        property string to: ""
        property string text: ""
        property string tag: ""
        property string lore: ""
        onTriggered: {
            const w = to === root.who ? to : root.who;
            const line = to === root.who ? root.answerTo(w, text, tag, lore) : root.tr(root.pick(S.otherAnswers[to], "other" + to));
            root.receive(w, line);
        }
    }

    // ---- three ways to answer her message (PhoneScreen: «Reply») ----
    // [{text, tag}]: something warm, a tease from 2026, then her hint's own question (or care,
    // a question, or a dry one)
    function replyOptions(m) {
        if (!m || !m.from || (m.from !== "angel" && m.from !== "demon"))
            return [];
        const set = m.from === "angel" ? L.options.angel : L.options.sister;
        const key = "opt" + m.from;
        const out = [{
                "text": tr(pick(set.warm, key + "warm")),
                "tag": "warm"
            }, {
                "text": tr(pick(set.tease, key + "tease")),
                "tag": "tease"
            }];
        const item = m.lore ? L.lore.find(l => l.id === m.lore) : null;
        if (item && item.ask)
            out.push({
                "text": tr(item.ask[0]),
                "tag": "ask"
            });
        else {
            const t = ["care", "ask", "dry"][Math.floor(Math.random() * 3)];
            out.push({
                "text": tr(pick(set[t], key + t)),
                "tag": t
            });
        }
        return out;
    }

    // ---- what they remember of you: per who (the angel, each sister) your last words and tags ----
    function remember(w, text, tag) {
        if (!save || !w)
            return;
        const mem = Object.assign({}, save.mem || {});
        const me = Object.assign({
            "said": [],
            "tags": {}
        }, mem[w] || {});
        me.said = [text].concat(me.said).slice(0, 8);
        me.tags = Object.assign({}, me.tags);
        if (tag)
            me.tags[tag] = (me.tags[tag] || 0) + 1;
        me.at = Date.now();
        mem[w] = me;
        save.mem = mem;
    }
    function saidTo(w) {
        return save && save.mem && save.mem[w] ? save.mem[w].said || [] : [];
    }
    // the deed a sister counts (PhoneLore.sisters.sin)
    function sinCount(kind) {
        if (kind === "unread")
            return unread;
        return stats[kind] || 0;
    }

    // ---- calls ----
    // {who, name, kind: her | system | info, outgoing, steps, step, text, answers, state:
    //  ring | talk, since}
    property var call: null
    readonly property bool ringing: !!call && call.state === "ring"
    readonly property bool talking: !!call && call.state === "talk"
    readonly property bool herCall: !!call && call.kind === "her"
    property int typed: 0
    readonly property string line: call && call.text ? call.text : ""
    readonly property bool speaking: talking && typed < line.length
    signal ended()

    property var _recent: ({})
    function pick(list, key) {
        if (!list || !list.length)
            return null;
        const seen = (_recent[key] || []).filter(i => i < list.length);
        let i = Math.floor(Math.random() * list.length);
        for (let n = 0; n < 12 && seen.includes(i); n++)
            i = Math.floor(Math.random() * list.length);
        const r = Object.assign({}, _recent);
        r[key] = seen.concat([i]).slice(-Math.max(1, Math.floor(list.length / 2)));
        _recent = r;
        return list[i];
    }
    // a prank call: someone else, in jest
    function prank() {
        const p = pick(S.pranks, "prank");
        if (!p || call || !on)
            return false;
        return ring(p.voice === "demon" || p.voice === "angel" ? p.voice : root.who, "", {
            "kind": "prank",
            "name": tr(p.name),
            "voice": p.voice,
            "steps": p.steps
        });
    }
    function script(w, when) {
        const list = (S.calls[w] || []).filter(c => c.when === when);
        return pick(list.length ? list : (S.calls[w] || []).filter(c => c.when === "random"), "call" + w + when);
    }

    // she (or the system) calls: the phone comes out shut and rings
    function ring(w, when, extra) {
        if (call || !on)
            return false;
        const sc = w === "system" ? null : script(w, when);
        // off: her call lands in the voicemail (a timer's ring is lost)
        if (dead) {
            if (w === "system")
                return false;
            const steps = extra && extra.steps ? extra.steps : sc ? sc.steps : [];
            if (steps.length)
                _toVoicemail(w, steps, extra && extra.lore, w === "demon" ? sister : "");
            _quota({
                "last": Date.now()
            });
            return true;
        }
        call = Object.assign({
            "who": w,
            "name": w === "system" ? (extra && extra.name || "") : nameOf(w),
            "kind": w === "system" ? "system" : "her",
            "outgoing": false,
            "steps": sc ? sc.steps : [],
            "step": 0,
            "text": "",
            "answers": [],
            "state": "ring",
            "since": Date.now(),
            "sister": w === "demon" ? sister : ""
        }, extra || {});
        if (!Sidebar.shown)
            Sidebar.show(false);
        ringTune.restart();
        missTimer.restart();
        if (w !== "system")
            _quota({
                "last": Date.now()
            });
        return true;
    }
    // the tune rings while it rings, a pause between; a timer's call rings shorter
    readonly property string ringtone: call && call.who === "system" ? S.tunes.system : (Config.phone.ringtone || S.tunes[call && call.who === "demon" ? "demon" : "angel"])
    Timer {
        id: ringTune
        interval: 10
        repeat: true
        running: false
        onTriggered: {
            if (!root.ringing)
                return stop();
            // under Do not disturb it only shakes
            if (!Config.notifications.dnd)
                root.playTune(root.ringtone, 0.9);
            interval = root.tuneMs(root.ringtone) + 900;
        }
        onRunningChanged: if (!running)
            interval = 10
    }
    Timer {
        id: missTimer
        interval: 25000
        onTriggered: if (root.ringing)
            root.missed()
    }
    function missed() {
        const c = call;
        call = null;
        ringTune.stop();
        if (!c)
            return;
        if (c.kind === "her") {
            _log({
                "who": c.who,
                "name": c.name,
                "kind": "missed"
            });
            bump("turned");
            receive(c.who, tr(pick(S.missed[c.who], "missed" + c.who)));
        }
        ended();
    }
    function answer() {
        if (!ringing)
            return;
        ringTune.stop();
        missTimer.stop();
        const c = Object.assign({}, call, {
            "state": "talk",
            "since": Date.now()
        });
        if (c.kind === "her" || c.kind === "prank") {
            _log({
                "who": c.who,
                "name": c.name,
                "kind": c.outgoing ? "out" : "in"
            });
            bump("calls");
            if (c.kind === "her") {
                Achievements.note("phone.call", c.who);
                if (c.who === "demon")
                    bump("demon");
            }
        }
        call = c;
        if (c.lore)
            _loreSave({
                "seen": loreSeen.concat([c.lore])
            });
        _say(0);
    }
    // her line of step i; the system's call says what rang
    function _say(i) {
        if (!call)
            return;
        let text = "", answers = [];
        let voice = call.voice || "";
        if (call.kind === "her" || call.kind === "prank" || call.kind === "voice") {
            const st = call.steps[i];
            if (!st)
                return hangUp();
            text = tr(st.s);
            if (call.kind === "her" && call.who === "demon")
                text = voiced(text, call.sister || sister);
            if (call.kind === "voice")
                voice = st.voice || "none";
            answers = (st.a || []).map(a => ({
                        "label": en ? a[1] : a[0],
                        "next": a[2]
                    }));
        } else {
            text = call.body || call.name;
        }
        call = Object.assign({}, call, {
            "step": i,
            "text": text,
            "answers": answers,
            "voice": voice
        });
        typed = 0;
        typer.restart();
    }
    function choose(i) {
        if (!talking || speaking || !call.answers[i])
            return;
        _say(call.answers[i].next);
    }
    Timer {
        id: typer
        interval: 34
        repeat: true
        onTriggered: {
            if (!root.talking || root.typed >= root.line.length) {
                stop();
                // the voicemail's next message; her last line (no answers) or the system's: a
                // moment to read, then the line goes dead
                if (root.talking && root.call.kind === "voice" && root.call.step < root.call.steps.length - 1)
                    nextVoice.restart();
                else if (root.talking && !root.call.answers.length)
                    hangLater.restart();
                return;
            }
            root.typed++;
            const c = root.line.charAt(root.typed - 1);
            // the bad line hisses through the words it ate
            const hiss = root.tr(L.voicemail.hiss);
            if (root.call.kind === "voice" && root.loud && root.typed % 4 === 1 && root.line.lastIndexOf(hiss, root.typed - 1) >= 0 && root.line.lastIndexOf(hiss, root.typed - 1) + hiss.length >= root.typed) {
                root.play("hiss", 0.5);
                return;
            }
            if (!/[0-9A-Za-zÀ-ɏЀ-ӿ]/.test(c) || !root.loud)
                return;
            const v = root.call.voice || (root.call.kind === "her" ? root.call.who : "none");
            if ((v === "angel" || v === "demon") && Sounds.enabled("voice") && Sounds.ready)
                Sounds.playFile(Sounds.dir + "/" + (v === "demon" ? "voiceDemon" : "voiceAngel") + ".wav", Sounds.volumeOf("voiceAngel") * 0.8);
            else if (v === "bark" && root.typed % 7 === 1)
                Sounds.playFile(Sounds.dir + "/bark.ogg", Sounds.volumeOf("bark") * 0.7);
            else if (v === "robot" && root.typed % 2)
                root.note(60 + (root.typed * 7) % 12);
        }
    }
    Timer {
        id: hangLater
        interval: 2600
        onTriggered: root.hangUp()
    }
    Timer {
        id: nextVoice
        interval: 1400
        onTriggered: if (root.talking)
            root._say(root.call.step + 1)
    }
    function hangUp() {
        ringTune.stop();
        missTimer.stop();
        hangLater.stop();
        nextVoice.stop();
        typer.stop();
        call = null;
        ended();
    }
    // the red key while it rings: she has something to say about it, from her corner
    function decline() {
        if (!ringing)
            return hangUp();
        const c = call;
        hangUp();
        if (c.kind === "her" && !c.outgoing) {
            _log({
                "who": c.who,
                "name": c.name,
                "kind": "missed",
                "seen": true
            });
            bump("turned");
            if (c.who === root.who && Angel.present)
                Angel.say(tr(pick(S.declined[c.who], "declined" + c.who)), null, 0, true);
        }
    }

    // ---- dialling ----
    // what a number does: {kind: call | info | wrong, text}; a call to her is made from here
    function dial(number) {
        number = String(number || "").trim();
        if (!number)
            return null;
        const contact = S.contacts.find(c => c.number === number);
        if (contact && contact.who === "voicemail") {
            if (call)
                return null;
            playVoicemail();
            return {
                "kind": "call"
            };
        }
        if (contact && contact.who) {
            if (call)
                return null;
            _log({
                "who": contact.who,
                "name": nameOf(contact.who),
                "kind": "out"
            });
            if (!Angel.present)
                return {
                    "kind": "info",
                    "text": tr(S.unavailable),
                    "sound": "busy"
                };
            // the other one rules the corner: she picks up instead
            if (contact.who !== root.who) {
                call = {
                    "who": root.who,
                    "name": nameOf(root.who),
                    "kind": "her",
                    "outgoing": true,
                    "steps": [{
                            "s": pick(S.otherAnswers[contact.who], "other" + contact.who)
                        }],
                    "step": 0,
                    "text": "",
                    "answers": [],
                    "state": "ring",
                    "since": Date.now()
                };
            } else {
                const sc = script(root.who, "dialed");
                call = {
                    "who": root.who,
                    "name": nameOf(root.who),
                    "kind": "her",
                    "outgoing": true,
                    "steps": sc ? sc.steps : [],
                    "step": 0,
                    "text": "",
                    "answers": [],
                    "state": "ring",
                    "since": Date.now()
                };
            }
            // a couple of rings at the other end, then she picks up
            pickUp.restart();
            return {
                "kind": "call"
            };
        }
        // the code of the day: *answer#
        const dl = save && save.daily ? save.daily : {};
        if (dl.day === today && /^\*\d+#$/.test(number) && S.riddles[dl.idx] && number === "*" + S.riddles[dl.idx][1] + "#") {
            if (dl.solved)
                return {
                    "kind": "info",
                    "text": tr(S.riddleDone),
                    "sound": "sms"
                };
            save.daily = Object.assign({}, dl, {
                "solved": true
            });
            bump("riddles");
            const piece = giftPiece();
            Achievements.note("phone.code", "riddle");
            return {
                "kind": "info",
                "text": tr(pick(S.riddleWin[root.who], "win")).replace("%n", piece ? piece.name : "♡"),
                "sound": "sms"
            };
        }
        const code = S.codes[number];
        if (code) {
            if (number.startsWith("*"))
                Achievements.note("phone.code", number);
            const text = tr(code).replace("%v", Updates.release && Updates.release.number ? String(Updates.release.number) : "").replace("%l", String(Angel.petLove)).replace("%t", I18n.time(new Date(), true));
            return {
                "kind": "info",
                "text": text,
                "sound": "sms"
            };
        }
        return {
            "kind": "wrong",
            "text": tr(S.wrongNumber),
            "sound": "busy"
        };
    }
    Timer {
        id: pickUp
        interval: 2600
        onTriggered: if (root.ringing && root.call.outgoing)
            root.answer()
    }

    // ---- the tuning ----
    function locked(item) {
        const r = item.req || ["free"], n = r[1] || 0;
        switch (r[0]) {
        case "free":
            return false;
        case "pet":
            return Angel.petLevel < n;
        case "snake":
            return (save ? save.snake || 0 : 0) < n;
        case "raid":
        case "calls":
        case "sms":
        case "riddles":
            return (stats[r[0]] || 0) < n;
        case "demon":
            return !stats.demon;
        case "gift":
            return !(save && (save.gifts || []).includes(item.key));
        }
        return true;
    }
    function lockText(item) {
        const r = item.req || ["free"];
        return tr(S.reqText[r[0]]).replace("%n", r[1] || "");
    }
    // the tuning as a flat list with keys and names
    readonly property var pieces: {
        const out = [];
        for (const cat of S.looks)
            for (const it of cat.items)
                out.push({
                    "cat": cat.id,
                    "id": it.id,
                    "key": cat.id + ":" + it.id,
                    "name": tr(it.name),
                    "req": it.req
                });
        return out;
    }
    function wearing(cat) {
        const v = (Config.phone.look || {})[cat];
        const it = S.looks.find(c => c.id === cat).items.find(i => i.id === v);
        return it && !locked(Object.assign({
            "key": cat + ":" + it.id
        }, it)) ? it.id : S.looks.find(c => c.id === cat).items[0].id;
    }
    function wear(cat, id) {
        const l = Object.assign({}, Config.phone.look || {});
        l[cat] = id;
        Config.phone.look = l;
    }
    // a code of the day's prize: a piece only a code gives, else any still locked
    function giftPiece() {
        const all = pieces.filter(p => locked(p));
        const only = all.filter(p => p.req[0] === "gift");
        const p = (only.length ? only : all)[Math.floor(Math.random() * Math.max(1, (only.length ? only : all).length))];
        if (!p || !save)
            return null;
        save.gifts = (save.gifts || []).concat([p.key]);
        return p;
    }

    // ---- the melody collection: hers and yours ----
    readonly property var giftTunes: S.gifts.map(g => ({
                "id": g[0],
                "name": en ? g[2] : g[1],
                "spec": g[3],
                "who": g[4]
            }))
    readonly property var myTunes: giftTunes.filter(g => save && (save.tunes || []).includes(g.id))
    function sendTune() {
        const mine = save ? save.tunes || [] : [];
        const left = giftTunes.filter(g => g.who === root.who && !mine.includes(g.id));
        if (!left.length || !save)
            return false;
        const g = left[Math.floor(Math.random() * left.length)];
        save.tunes = mine.concat([g.id]);
        receive(root.who, tr(pick(S.giftText[root.who], "gift")).replace("%n", g.name));
        return true;
    }

    // ---- the code of the day ----
    function riddleToday() {
        if (!save)
            return;
        const dl = save.daily || {};
        if (dl.day === today)
            return;
        // the same riddle for the whole day, a different one the next
        const d = new Date();
        const idx = (d.getFullYear() * 372 + d.getMonth() * 31 + d.getDate()) % S.riddles.length;
        save.daily = {
            "day": today,
            "idx": idx,
            "solved": false
        };
        receive(root.who, I18n.t("Код дня: ", "Code of the day: ") + tr(S.riddles[idx][0]));
    }

    // ---- the magic ball, the cracks, the selfie ----
    function ballAnswer() {
        play("sms", 0.5);
        Achievements.note("phone.ball");
        bump("ball");
        return tr(pick(S.ball, "ball"));
    }
    readonly property bool cracked: !!save && save.cracked > 0 && now - save.cracked < 3600000
    function drop() {
        if (!save)
            return;
        save.cracked = Date.now();
        now = Date.now();
        bump("drops");
        Achievements.note("phone.drop");
        if (Angel.present)
            Angel.say(tr(pick(S.dropped[root.who], "drop" + root.who)), null, 0, true);
    }
    function mend(quiet) {
        if (!cracked)
            return;
        save.cracked = 0;
        if (!quiet && Angel.present)
            Angel.say(tr(pick(S.fixed[root.who], "fix" + root.who)), null, 0, true);
    }
    // petting her mends it
    Connections {
        target: Angel
        function onPettingChanged() {
            if (Angel.petting && root.cracked)
                root.mend(false);
        }
    }
    function selfieLine(w) {
        return tr(pick(S.selfie[w], "selfie" + w));
    }
    readonly property string photobomb: tr(S.photobomb)
    readonly property string albumDir: Config.home + "/.local/share/angelos/phone/album"
    function keepPhoto(path, w) {
        if (!save)
            return;
        save.album = [{
                "path": path,
                "at": Date.now(),
                "who": w
            }].concat(save.album || []).slice(0, 60);
        Achievements.note("phone.selfie", w);
    }
    function dropPhoto(path) {
        if (!save)
            return;
        save.album = (save.album || []).filter(p => p.path !== path);
        Quickshell.execDetached(["rm", "-f", path]);
    }

    // ---- the story: the canon's clock and her hints ----
    // a day since the first start is a second of her night; ten days, a volume (the last one runs
    // to midnight, day 90)
    readonly property int day: Story.createdAt > 0 ? Math.max(1, Math.floor((now - Story.createdAt) / 86400000) + 1) : 1
    readonly property int volume: Math.max(1, Math.min(9, Math.ceil(Math.min(day, 90) / 10)))
    readonly property var loreState: save && save.lore ? save.lore : ({})
    readonly property var loreSeen: loreState.seen || []
    function _loreSave(patch) {
        if (save)
            save.lore = Object.assign({}, loreState, patch);
    }
    // the next hint: the earliest volume first (the night in its order), only volumes already come
    function loreNext() {
        const left = L.lore.filter(l => l.vol <= volume && !loreSeen.includes(l.id));
        if (!left.length)
            return null;
        const v = Math.min(...left.map(l => l.vol));
        const now = left.filter(l => l.vol === v);
        return now[Math.floor(Math.random() * now.length)];
    }
    // she lets one out: a message (delivered: seen) or a call (seen once answered or in the voicemail)
    function loreOut() {
        const item = loreNext();
        if (!item)
            return false;
        if (item.s) {
            _loreSave({
                "seen": loreSeen.concat([item.id])
            });
            receive("angel", tr(item.s), {
                "lore": item.id
            });
            return true;
        }
        if (!free())
            return false;
        if (ring("angel", "lore", {
            "steps": item.steps,
            "lore": item.id
        })) {
            if (dead)
                _loreSave({
                    "seen": loreSeen.concat([item.id])
                });
            return true;
        }
        return false;
    }
    // a sister writes: a recollection (your deeds, your words), the angel's lost voicemail told
    // whole, or one of her own
    function sisterText() {
        const x = L.sisters[sister];
        if (!x)
            return "";
        const lost = (loreState.lost || []).filter(id => !(loreState.told || []).includes(id));
        if (lost.length && Math.random() < 0.6) {
            const item = L.lore.find(l => l.id === lost[0]);
            const words = item ? (item.s ? tr(item.s) : tr(item.steps[0].s)) : "";
            if (words) {
                _loreSave({
                    "told": (loreState.told || []).concat([lost[0]])
                });
                return tr(pick(x.fill, "fill" + sister)).replace("%q", words);
            }
        }
        if (Math.random() < 0.45) {
            const said = saidTo("angel"), mine = saidTo(sister), n = sinCount(x.sin);
            const can = x.recall.filter(r => r.needs === "sin" ? n > 0 : r.needs === "said" ? said.length > 0 : mine.length > 0);
            const r = pick(can, "recall" + sister);
            if (r) {
                const q = r.needs === "mine" ? mine[Math.floor(Math.random() * mine.length)] : said[Math.floor(Math.random() * said.length)];
                return tr(r.t).replace("%n", n).replace("%q", String(q || "").slice(0, 80));
            }
        }
        return tr(pick(x.texts, "stext" + sister));
    }
    // the charger left in for two hours: the smell of smoke (once a charge)
    function smokeCheck() {
        if (!plugged || batt.smoked || Angel.demon || Date.now() - (batt.plugAt || Date.now()) < 2 * 3600000)
            return false;
        _battSet({
            "smoked": true
        });
        receive("angel", tr(pick(L.smoke, "smoke")));
        return true;
    }

    // ---- when she calls on her own ----
    property double _awaySince: 0
    property bool _away: false
    Connections {
        target: Shell
        function onLockedChanged() {
            if (Shell.locked)
                root._awaySince = root._awaySince || Date.now();
            else
                backLater.restart();
        }
    }
    Connections {
        target: Idle
        function onActiveChanged() {
            if (Idle.active)
                root._awaySince = root._awaySince || Date.now();
            else
                backLater.restart();
        }
    }
    Timer {
        id: backLater
        interval: 6000
        onTriggered: {
            const away = root._awaySince ? Date.now() - root._awaySince : 0;
            root._awaySince = 0;
            if (away > 30 * 60000 && Math.random() < 0.4)
                root.maybe("back");
        }
    }
    Connections {
        target: Timers
        function onRang(head, body) {
            if (root.on && Config.phone.timerCalls && !root.call)
                root.ring("system", "", {
                    "name": head,
                    "body": body || head
                });
        }
    }
    // may she call now (and why)?
    function free() {
        return on && Config.phone.calls && !call && Angel.present && !Angel.transition && !Shell.locked && !Idle.active && !Shell.fullscreenOn(Sidebar.screenName) && !Sidebar.open && !(!Angel.demon && Story.angelStep >= 2);
    }
    function maybe(when) {
        if (!free())
            return false;
        const q = quotas, t = Date.now();
        if (q.last && t - q.last < 2 * 3600000)
            return false;
        const day = today;
        const count = q.day === day ? (q.count || 0) : 0;
        if (when === "random" && count >= 2)
            return false;
        if (ring(root.who, when)) {
            const patch = {
                "day": day,
                "count": when === "random" ? count + 1 : count
            };
            patch[when] = day;
            _quota(patch);
            return true;
        }
        return false;
    }
    Timer {
        interval: 120000
        running: root.on && Config.phone.calls
        repeat: true
        onTriggered: root.tick()
    }
    readonly property double startedAt: Date.now()
    function tick() {
        if (!free())
            return;
        const q = quotas, h = new Date().getHours(), day = today;
        // the first call: once ever, a while after the phone came to be
        if (!q.first && Date.now() - startedAt > 8 * 60000) {
            if (ring(root.who, "first"))
                _quota({
                    "first": Date.now(),
                    "last": Date.now()
                });
            return;
        }
        if (h < 4 && q.late !== day && Math.random() < 0.25)
            return maybe("late");
        if (h >= 7 && h < 11 && q.morning !== day && Math.random() < 0.08)
            return maybe("morning");
        const pet = Angel.petSave && Angel.petSave.day ? Date.parse(Angel.petSave.day) : 0;
        if (pet && Date.now() - pet > 2.5 * 86400000 && q.miss !== day && Math.random() < 0.2)
            return maybe("miss");
        if (h >= 10 && Math.random() < 0.008)
            return maybe("random");
        // the code of the day comes in the morning (or whenever the day starts at the computer)
        if (h >= 9 && (!save.daily || save.daily.day !== day)) {
            riddleToday();
            return;
        }
        // a prank call, a tune, a chain letter: each once a day at most
        if (q.prank !== day && h >= 11 && Math.random() < 0.004) {
            if (prank())
                _quota({
                    "prank": day,
                    "last": Date.now()
                });
            return;
        }
        if (q.gift !== day && h >= 10 && Math.random() < 0.004) {
            _quota({
                "gift": day
            });
            sendTune();
            return;
        }
        if (q.chain !== day && h >= 12 && Math.random() < 0.002) {
            _quota({
                "chain": day
            });
            receive(root.who, tr(pick(S.chainLetters[root.who], "chain" + root.who)));
            return;
        }
        // the charger in too long: she smells smoke
        if (smokeCheck())
            return;
        // the story: her hint (two a day at most, a while apart); while the demon rules, the sister
        if (!Angel.demon && h >= 9 && (q.loreDay !== day || (q.lore || 0) < 2) && Date.now() - (q.loreAt || 0) > 3 * 3600000 && Math.random() < 0.02) {
            if (loreOut())
                _quota({
                    "loreDay": day,
                    "lore": q.loreDay === day ? (q.lore || 0) + 1 : 1,
                    "loreAt": Date.now()
                });
            return;
        }
        if (Angel.demon && sister && q.sister !== day && h >= 10 && Math.random() < 0.012) {
            _quota({
                "sister": day
            });
            receive("demon", sisterText());
            return;
        }
        // 2002 slipping out of her: one a day at most
        if (!Angel.demon && q.slip !== day && h >= 11 && Math.random() < 0.004) {
            _quota({
                "slip": day
            });
            receive("angel", tr(pick(L.slips, "slip")));
            return;
        }
        // a message out of the blue: one a day at most
        if (q.text !== day && h >= 9 && Math.random() < 0.005) {
            _quota({
                "text": day
            });
            receive(root.who, root.who === "demon" && sister ? sisterText() : tr(pick(S.texts[root.who], "text" + root.who)));
        }
    }
}
