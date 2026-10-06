pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../novel/NovelCore.js" as Core

// The game (Story). angelOS is a story played over the real desktop: the angel in the
// corner, the demon who takes over when the player throws the angel down, hell's nine
// circles. What the player sees depends on what they chose — not on a counter.
//
//   the save    ~/.config/angelos/save.json (services/SaveSchema): who rules, the sins,
//               where in hell, every choice. Moved here once from settings.json (y2k.*) and
//               ~/.local/state/angelos/novel.json; never touched by the installer or updates.
//   sins        one story variable per circle (vars.limbo … vars.treachery). The scenes'
//               answers `set` them, and so do things done outside the scenes
//               (story/game.json → actions: flinging the angel, spinning the wheel…: act()).
//   a fall      the angel thrown down: the player lands in the circle of their heaviest sin
//               among those no fall has begun in yet (fell()). Two players, two hells.
//   the way out Dante's: down, through the bottom. A try (Ask → Seek the way out, or the
//               wheel) is a trial scene in the circle (story/scenes, trigger "trial"): the
//               right answer leads a circle deeper, a wrong one keeps you where you are;
//               Cocytus answered right is the way out to the stars. Too many silences sink
//               the player into limbo; the pact (after a few failed tries, or the portal) is
//               the short way, with a mark left in heaven. Outcomes: stars | pact | limbo.
//   transitions the screen goes dark, a low blow in the dark, the circle's number and name
//               come up (modules/y2k/CircleTransition); hell's look follows HellLook.circle.
//
// Off (`angelos game off`, Mod+Ctrl+Shift+Escape, Settings): no angel, demon, novel or hell —
// plain dotfiles, at once. Calm (Motion.calm — Settings → Appearance → Motion): no flashes,
// shaking or sudden loud sounds; Motion "off": no animations, heaven ⇄ hell at once.
// Nothing here reads the player's files, windows' contents or browser: the story knows only
// what the shell knows anyway (the name, the time, the uptime, the music playing).
Singleton {
    id: root

    readonly property bool enabled: Config.game.enabled !== false
    readonly property bool calm: Motion.calm
    readonly property string file: Config.dir + "/save.json"
    property bool ready: false
    property alias player: save.player
    property alias hell: save.hell
    readonly property var vars: save.vars || ({})
    readonly property var novelState: save.novel

    // ---- the rules and the voices (story/game.json, story/voices.json, story/contract.json) ----
    property var rules: ({})
    property var voices: ({})
    property var angelVoice: ({})          // story/angel.json: her lines as she cools
    readonly property var order: rules.order && rules.order.length ? rules.order : ["limbo", "lust", "gluttony", "greed", "wrath", "heresy", "violence", "fraud", "treachery"]
    readonly property int attemptMinutes: rules.attempt || 10
    readonly property int pactAfter: rules.pactAfter || 3
    readonly property int limboAfter: rules.limboAfter || 3
    readonly property int limboReturnMinutes: rules.limboReturn || 10
    // heaven ⇄ hell: a switch this soon after the last is instant; the same transition
    // sound no oftener than this (story/game.json → pace, C1)
    readonly property int quickSwitchMs: ((rules.pace || {}).quickSwitch || 60) * 1000
    readonly property int soundGapMs: ((rules.pace || {}).soundGap || 2) * 1000

    readonly property bool inHell: player.character === "demon"

    // ---- the angel's warmth (story/game.json → angel) ----
    // 0 warm · 1 reserved · 2 cool · 3 cold (the cold route, for good) · 4 fallen (past cold, for
    // good: angel.fallen). Every throw adds its chill; a day without one gives a step back;
    // nothing on screen says so.
    readonly property var angelRules: rules.angel || ({})
    readonly property var chillSteps: angelRules.steps && angelRules.steps.length === 3 ? angelRules.steps : [1, 2, 3]
    readonly property int chill: player.chill || 0
    readonly property int angelStep: player.fallen ? 4 : player.coldRoute ? 3 : chill >= chillSteps[2] ? 3 : chill >= chillSteps[1] ? 2 : chill >= chillSteps[0] ? 1 : 0
    readonly property string angelStepName: ["warm", "reserved", "cool", "cold", "fallen"][angelStep]
    // past cold: a trip down that begins with her on the cold route, or after more than
    // `moreThan` betrayals, changes her by the time the player is back (fell() marks it, rose()
    // turns her); she then shows as `look` whatever Settings pick
    readonly property var fallenRules: angelRules.fallen || ({})
    readonly property bool angelFallen: !!player.fallen
    readonly property string fallenLook: fallenRules.look || "ophanim"
    readonly property real fallenTalk: fallenRules.talkEvery > 0 ? fallenRules.talkEvery : 1
    function isBetrayal(name) {
        return (fallenRules.betrayal || ["throw.fling", "throw.push"]).includes(name);
    }
    // where she stood before this throw (act() keeps it for the fall it starts)
    property var _beforeThrow: null
    function markDescent() {
        // the throw that starts this fall was a moment ago (a stale one is no part of it)
        const thrown = _beforeThrow && Date.now() - _beforeThrow.at < 15000;
        const was = thrown ? _beforeThrow : {
            "cold": !!player.coldRoute,
            "betrayals": player.betrayals || 0
        };
        _beforeThrow = null;
        if (player.fallen || player.fallenDue)
            return;
        const limit = fallenRules.moreThan === undefined ? 5 : fallenRules.moreThan;
        if ((was.cold && fallenRules.coldRoute !== false) || was.betrayals > limit)
            save.player.fallenDue = true;
    }
    function chillBy(n) {
        if (!n)
            return;
        save.player.chill = Math.max(0, chill + n);
        save.player.lastThrow = Date.now();
        if (!player.coldRoute && player.chill >= chillSteps[2]) {
            save.player.coldRoute = true;
            save.player.coldSince = Date.now();
        }
    }
    // a day without a throw: one step warmer (never out of the cold route)
    function thaw() {
        if (!ready || player.coldRoute || chill <= 0)
            return;
        const day = (angelRules.thawHours || 24) * 3600000;
        const since = Math.max(player.lastThrow || 0, player.thawAt || 0);
        const days = Math.floor((now() - since) / day);
        if (days <= 0 || since <= 0)
            return;
        save.player.chill = Math.max(0, chill - days);
        save.player.thawAt = since + days * day;
    }
    Timer {
        running: root.ready && root.chill > 0 && !root.player.coldRoute
        interval: 3600000
        repeat: true
        onTriggered: root.thaw()
    }
    // ---- each circle's demon and the player (story/game.json → closeness, item 12) ----
    // 0 a stranger · 1 acquainted · 2 close · 3 your own — her own count, kept across falls
    readonly property var closeRules: rules.closeness || ({})
    readonly property var closeSteps: closeRules.steps && closeRules.steps.length === 3 ? closeRules.steps : [3, 8, 15]
    function closePoints(cid) {
        const c = (hell.close || {})[cid || circle];
        return c ? (c.points || 0) : 0;
    }
    function closeStepOf(points) {
        return points >= closeSteps[2] ? 3 : points >= closeSteps[1] ? 2 : points >= closeSteps[0] ? 1 : 0;
    }
    readonly property int demonStep: inHell && circle ? closeStepOf(closePoints(circle)) : 0
    function giftName(cid) {
        const g = (closeRules.gifts || {})[cid || circle];
        return g ? I18n.label(g) : I18n.t("подарок", "a gift");
    }
    // talk | gift | stay with the demon of this circle: {ok, step, stepUp} or {ok: false, wait (min)}
    function demonAct(kind) {
        const a = (rules.actions || {})["demon." + kind];
        if (!enabled || !ready || !inHell || !circle || !a)
            return {
                "ok": false,
                "wait": 0
            };
        const rec = Object.assign({}, (hell.close || {})[circle] || {});
        const left = (a.every || 0) * 60000 - (now() - (rec[kind + "At"] || 0));
        if (left > 0)
            return {
                "ok": false,
                "wait": Math.ceil(left / 60000)
            };
        const before = closeStepOf(rec.points || 0);
        rec.points = (rec.points || 0) + (a.close || 0);
        rec[kind + "At"] = now();
        const all = Object.assign({}, hell.close || {});
        all[circle] = rec;
        save.hell.close = all;
        const look = HellLook.looks[circle] || {};
        if (a.sin && look.sin) {
            const set = {};
            set[look.sin] = "+" + a.sin;
            applySet(set);
        }
        if (a.costsTry)
            save.player.lastPlea = now();
        const after = closeStepOf(rec.points);
        return {
            "ok": true,
            "step": after,
            "stepUp": after > before
        };
    }
    // her line for an action at her step (story/voices.json → demons → circle → kind)
    function demonLine(kind, step) {
        const d = ((voices.demons || {})[circle] || {})[kind];
        if (!d)
            return "";
        const list = Array.isArray(d[0]) && Array.isArray(d[0][0]) ? (d[Math.min(step === undefined ? demonStep : step, d.length - 1)] || []) : d;
        if (!list.length)
            return "";
        const l = list[Math.floor(Math.random() * list.length)];
        // the gift may open the line: "монета? …" → "Монета? …"
        const s = render(Array.isArray(l) ? (I18n.english ? l[1] : l[0]) : l).replace("%1", giftName(circle));
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // her line for the step she is at (story/angel.json → <step> → kind), "" when warm or none;
    // past cold, a situation without her own lines takes the cold ones. Never the same line
    // twice in a row
    property var _lastLine: ({})
    function angelLine(kind) {
        if (inHell || angelStep === 0)
            return "";
        let step = angelStepName, list = (angelVoice[step] || {})[kind];
        if ((!list || !list.length) && step === "fallen") {
            step = "cold";
            list = (angelVoice.cold || {})[kind];
        }
        if (!list || !list.length)
            return "";
        const key = step + "/" + kind;
        let i = Math.floor(Math.random() * list.length);
        if (list.length > 1 && i === _lastLine[key])
            i = (i + 1 + Math.floor(Math.random() * (list.length - 1))) % list.length;
        _lastLine[key] = i;
        const l = list[i];
        return render(Array.isArray(l) ? (I18n.english ? l[1] : l[0]) : l);
    }
    readonly property string circle: hell.circle || ""
    readonly property int depth: (hell.path || []).length
    // the pact's mark: something of hers stays in heaven (the emblem keeps its horns)
    readonly property bool marked: !!hell.pact && !inHell
    // limbo: the demon is gone and the angel hasn't come yet
    readonly property bool limbo: !!hell.limbo && inHell

    // ---- the game's clock ----
    // Date.now(), moved forward by the self-test (scripts/test-ui.sh) instead of waiting
    // ten real minutes; nothing else sets it
    property double clockShift: 0
    function now() {
        return Date.now() + clockShift;
    }
    // a time saved "in the future" (the clock went back: a dual boot with Windows, a sync
    // after the shell started, a hand edit) would make the player wait for it — forever,
    // if it is garbage. Such a time is forgotten: as if nothing happened yet (issue #31)
    function repairClock() {
        const t = now(), slack = 60000;
        let fixed = [];
        if ((player.lastPlea || 0) > t + slack) {
            save.player.lastPlea = 0;
            fixed.push("lastPlea");
        }
        if ((player.wheelAt || 0) > t + slack) {
            save.player.wheelAt = 0;
            fixed.push("wheelAt");
        }
        if ((player.cursedUntil || 0) > t + 3600000 + slack) {
            save.player.cursedUntil = t + 3600000;
            fixed.push("cursedUntil");
        }
        if ((hell.limboSince || 0) > t + slack) {
            save.hell.limboSince = t;
            fixed.push("limboSince");
        }
        if (fixed.length)
            console.warn("save.json: times in the future reset (" + fixed.join(", ") + ")");
        return fixed;
    }

    function circleN(id) {
        return order.indexOf(id) + 1;
    }
    function circleName(id) {
        const c = HellLook.looks[id];
        return c && c.name ? I18n.label(c.name) : id;
    }

    // ---- the save ----
    FileView {
        id: fileView
        path: root.file
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeSoon.restart()
        onLoaded: root.loadedSave()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.migrate();
            root.loadedSave();
        }
        SaveSchema {
            id: save
        }
    }
    Timer {
        id: writeSoon
        interval: 300
        onTriggered: fileView.writeAdapter()
    }
    function loadedSave() {
        if (ready)
            return;
        ready = true;
        repairClock();
        thaw();
        HellLook.circle = inHell && circle ? circle : "base";
        if (inHell && (hell.amnesty || limboOver()))
            freeSoon.restart();
    }
    // the shell has just started: let it settle (her sprite, the wallpaper) before she goes
    Timer {
        id: freeSoon
        interval: 6000
        onTriggered: root.freeIfDue(true)
    }
    // someone who fell under the old rules (three lucky pleas, before the circles) is let
    // out at the first start after the update; limbo ends once the player was away long
    // enough — a start of the shell long after limbo began counts too (a reboot, the night:
    // limboSince is in the save, the away timer in Angel is not)
    function freeIfDue(atStart) {
        if (!enabled || !inHell)
            return false;
        if (Angel.transition) {
            if (atStart)
                freeSoon.restart();
            return false;
        }
        if (hell.amnesty) {
            outcome("amnesty");
            return true;
        }
        if (atStart && limboOver()) {
            Angel.getOut("limbo");
            return true;
        }
        return false;
    }
    // the clock jumps around sleep (and NTP syncs after it): check the saved times again
    Connections {
        target: Shell
        function onResumed() {
            if (root.ready)
                root.repairClock();
        }
    }
    function limboOver() {
        return !!hell.limbo && (hell.limboSince || 0) > 0 && now() - hell.limboSince >= limboReturnMinutes * 60000;
    }
    // the first start with a save: what the player had before it is carried over
    FileView {
        id: oldSettings
        path: Config.dir + "/settings.json"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: oldNovel
        path: Config.stateDir + "/novel.json"
        blockLoading: true
        printErrors: false
    }
    function migrate() {
        let y = {}, n = null;
        try {
            y = (JSON.parse(oldSettings.text() || "{}").y2k) || {};
        } catch (e) {}
        try {
            n = JSON.parse(oldNovel.text() || "null");
        } catch (e) {}
        migrateFrom(y, n);
    }
    // settings.json's old y2k section (and novel.json) → the save; the self-test feeds it
    // a stuck player's broken counter directly
    function migrateFrom(y, n) {
        y = y && typeof y === "object" ? y : {};
        save.createdAt = Date.now();
        // a broken old counter must not break the save: each value only of its own type
        const numbers = ["demonSince", "lastPlea", "wheelAt", "cursedUntil", "nextPrank", "returns"];
        for (const k of ["character", "cursedWas", "pranks", "angelSaved"].concat(numbers)) {
            const v = y[k];
            if (v === undefined || v === null)
                continue;
            if (numbers.includes(k) ? typeof v === "number" && isFinite(v) && v >= 0 : k === "pranks" ? Array.isArray(v) : k === "angelSaved" ? typeof v === "object" : typeof v === "string")
                save.player[k] = v;
        }
        if (n)
            save.novel = n;
        // someone already in hell lands in a circle like any fall — and is let out at once:
        // they fell under the old rules, whatever their plea counter says (issue #31)
        if (save.player.character === "demon") {
            const c = circleForFall();
            save.hell.circle = c;
            save.hell.path = [c];
            save.hell.fallCircles = [c];
            save.hell.falls = 1;
            save.hell.amnesty = true;
        }
        writeSoon.restart();
    }

    // the novel's progress (services/Novel saves it here, debounced)
    function saveNovel(state) {
        save.novel = JSON.parse(JSON.stringify(state));
    }

    // ---- data ----
    FileView {
        path: Quickshell.shellDir + "/story/game.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.rules = JSON.parse(text());
            } catch (e) {
                console.warn("story/game.json: " + e);
            }
        }
    }
    FileView {
        path: Quickshell.shellDir + "/story/voices.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.voices = JSON.parse(text());
            } catch (e) {
                console.warn("story/voices.json: " + e);
            }
        }
    }
    FileView {
        path: Quickshell.shellDir + "/story/angel.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.angelVoice = JSON.parse(text());
            } catch (e) {
                console.warn("story/angel.json: " + e);
            }
        }
    }
    FileView {
        path: Quickshell.shellDir + "/story/contract.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.contractText = JSON.parse(text());
            } catch (e) {
                console.warn("story/contract.json: " + e);
            }
        }
    }
    // how long the computer has been on, for "{uptime} at the screen" (/proc/uptime)
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
    }
    function uptimeText() {
        uptimeFile.reload();
        const sec = parseFloat(String(uptimeFile.text() || "0").split(" ")[0]) || 0;
        const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60);
        if (I18n.english)
            return h ? h + (h === 1 ? " hour" : " hours") : m + " min";
        const word = (v, one, few, many) => v % 10 === 1 && v % 100 !== 11 ? one : v % 10 >= 2 && v % 10 <= 4 && (v % 100 < 12 || v % 100 > 14) ? few : many;
        return h ? h + " " + word(h, "час", "часа", "часов") : m + " " + word(m, "минута", "минуты", "минут");
    }

    // ---- what conditions and texts see ----
    function ctxVars() {
        return Object.assign({}, vars, {
            "gender": (save.novel && save.novel.vars && save.novel.vars.gender) || Config.novel.gender || "",
            "circle": circle,
            "n": circleN(circle),
            "depth": depth,
            "attempts": hell.attempts || 0,
            "silences": hell.silences || 0,
            "falls": hell.falls || 0,
            "returns": player.returns || 0,
            // the angel's warmth: chill (the throws, thawing), warmth 0 warm … 3 cold, coldRoute
            "chill": chill,
            "warmth": angelStep,
            "coldRoute": !!player.coldRoute,
            "fallen": !!player.fallen,
            "betrayals": player.betrayals || 0,
            // this circle's demon and the player: closeness 0 a stranger … 3 your own, points
            "closeness": inHell && circle ? closeStepOf(closePoints(circle)) : 0,
            "closePoints": inHell && circle ? closePoints(circle) : 0,
            "pact": !!hell.pact,
            "pactAfter": pactAfter,
            "limboAfter": limboAfter,
            "realm": inHell ? "hell" : "heaven"
        });
    }
    function render(text) {
        return Core.render(text, {
            "vars": ctxVars(),
            "name": Config.novel.name || StartApps.userName,
            "song": Lyrics.title || "",
            "uptime": uptimeText(),
            "english": I18n.english,
            "now": new Date()
        });
    }

    // ---- sins ----
    function applySet(set) {
        if (set && Object.keys(set).length)
            save.vars = Core.applySet(save.vars || {}, set);
    }
    property var _actedAt: ({})
    // something the player did outside a scene (story/game.json → actions)
    function act(name) {
        if (!enabled || !ready)
            return false;
        const a = (rules.actions || {})[name];
        if (!a)
            return false;
        if (a.realm && a.realm !== (inHell ? "hell" : "heaven"))
            return false;
        const t = Date.now();
        if (a.every && t - (_actedAt[name] || 0) < a.every * 60000)
            return false;
        _actedAt[name] = t;
        // a betrayal (a throw): counted, and where she stood before it is kept for the fall
        if (isBetrayal(name)) {
            _beforeThrow = {
                "cold": !!player.coldRoute,
                "betrayals": player.betrayals || 0,
                "at": Date.now()
            };
            save.player.betrayals = (player.betrayals || 0) + 1;
        }
        applySet(a.set);
        chillBy(a.chill || 0);
        return true;
    }
    // a scene's answer (services/Novel): the log, and silence in hell is counted
    function chose(scene, node, index, tone) {
        save.choices = (save.choices || []).concat([{
                    "scene": scene,
                    "node": node,
                    "choice": index,
                    "tone": tone || "",
                    "at": Date.now()
                }]).slice(-400);
        if (tone === "silent") {
            act("choice.silent");
            if (inHell)
                save.hell.silences = (hell.silences || 0) + 1;
        }
    }
    // a choice made outside the story's scenes, kept in the log (the wizard's first one)
    function record(scene, what, value) {
        save.choices = (save.choices || []).concat([{
                    "scene": scene,
                    "node": what,
                    "choice": value,
                    "at": Date.now()
                }]).slice(-400);
    }

    // ---- circles ----
    function circleForFall() {
        const used = hell.fallCircles || [];
        let pool = order.filter(id => !used.includes(id));
        if (!pool.length)
            pool = order.slice();
        let best = "", weight = 0;
        for (const id of pool) {
            const v = Number(vars[id]) || 0;
            if (v > weight) {
                best = id;
                weight = v;
            }
        }
        return best || (pool.includes("limbo") ? "limbo" : pool[0]);
    }
    function setCircle(id) {
        const changed = (hell.circle || "") !== (id || "");
        save.hell.circle = id || "";
        HellLook.circle = id || "base";
        // the circle's own painting goes up (unseen: this runs while the screen is dark)
        if (changed && id && inHell)
            Angel.newHell();
    }
    // the angel went down (Angel.becomeDemon, halfway through the swap); `target`: a dev jump
    function fell(target) {
        const c = order.includes(target) ? target : circleForFall();
        let used = (hell.fallCircles || []).filter(x => order.includes(x));
        if (used.length >= order.length)
            used = [];
        save.hell.fallCircles = used.concat([c]);
        save.hell.falls = (hell.falls || 0) + 1;
        save.hell.path = [c];
        save.hell.attempts = 0;
        save.hell.silences = 0;
        save.hell.limbo = false;
        markDescent();
        setCircle(c);
        return c;
    }
    // the angel is back (Angel.becomeAngel): hell is over for this time. `counted` false: the
    // game switched off, no comeback — what was to change her waits for a real one
    function rose(counted) {
        // the trip that was to change her is over: she comes back changed
        if (counted !== false && player.fallenDue) {
            save.player.fallenDue = false;
            save.player.fallen = true;
            save.player.fallenSince = now();
        }
        save.hell.path = [];
        save.hell.attempts = 0;
        save.hell.silences = 0;
        save.hell.limbo = false;
        save.hell.amnesty = false;
        setCircle("");
        Novel.stopScene();
    }
    // a circle deeper (a trial answered right), with the transition
    function deeper() {
        const i = order.indexOf(circle);
        const next = order.slice(i + 1).find(id => !(hell.path || []).includes(id));
        if (!next)
            return outcome("stars");
        enter(next);
        return true;
    }
    // into a circle: dark, the blow, its name, then the demon meets you there
    function enter(id) {
        save.hell.path = (hell.path || []).filter(x => x !== id).concat([id]);
        save.hell.attempts = 0;
        CircleFx.run(id, () => root.setCircle(id), () => root.greet());
    }
    // the demon's first words in a circle (story/voices.json → enter)
    function greet() {
        const l = voiceLine("enter");
        if (l)
            Angel.say(l, null, 9000);
    }
    // a try failed (a trial's wrong answer): too many silences sink the player into limbo
    function stay() {
        if ((hell.silences || 0) >= limboAfter && !hell.limbo)
            return Novel.playScene("limbo") || outcome("limbo");
        return true;
    }

    // ---- getting out ----
    readonly property double nextTry: (player.lastPlea || 0) + attemptMinutes * 60000
    // the buttons: "Seek the way out · I · 7 min" — the wait is shown, not guessed (issue #31)
    function tryLabel(base, circleWord) {
        const left = Math.ceil((nextTry - now()) / 60000);
        return base + " · " + (circleWord ? circleWord + " " : "") + Theme.roman(circleN(circle)) + (left > 0 && !hell.limbo ? " · " + I18n.t(left + " мин", left + " min") : "");
    }
    // a try to get out: the circle's trial (`free`: the wheel's plea, no waiting). A try
    // is never swallowed without a word (issue #31): there is always a trial, a reply
    // with the minutes left, or what is in the way
    function attempt(free) {
        if (!enabled || !inHell || Angel.transition)
            return "not in hell";
        repairClock();
        if (freeIfDue(false))
            return "out";
        if (hell.limbo) {
            // nobody in the corner to say it: a notification (a draft line)
            Quickshell.execDetached(["notify-send", "-a", "angelOS", I18n.t("Лимб", "Limbo"), I18n.t("Здесь никого нет. Отойди от компьютера — заблокируй экран минут на " + limboReturnMinutes + ", и ангел тебя найдёт.", "Nobody is here. Step away from the computer — lock the screen for " + limboReturnMinutes + " minutes, and the angel will find you.")]);
            return "limbo";
        }
        if (Novel.sceneBusy) {
            // a scene the update renamed or removed (the drafts change): it can't go on
            if (Novel.sceneStale()) {
                console.warn("save.json: the game's scene " + Novel.sceneStatus() + " is gone; dropped");
                Novel.stopScene();
            } else {
                // a trial (or the pact) already waits for an answer: bring it back up
                if (!Novel.sceneShown())
                    Novel.resumeScene();
                if (!Novel.sceneShown())
                    Angel.say(I18n.t("Сначала ответь на то, что уже спрошено.", "Answer what you've already been asked first."));
                return "busy";
            }
        }
        const t = now();
        if (!free && t < nextTry) {
            act("plea.early");
            const l = voiceLine("wait");
            Angel.say((l || I18n.t("Рано. Ещё %1 мин.", "Too soon. %1 more min.")).replace("%1", Math.max(1, Math.ceil((nextTry - t) / 60000))));
            return "wait";
        }
        save.player.lastPlea = t;
        save.hell.attempts = (hell.attempts || 0) + 1;
        if (Novel.playScene("trial"))
            return "trial";
        // no trial written for this circle: the way is open
        deeper();
        return "deeper";
    }
    // the portal in hell is the pact's door, not a way out by itself
    function portal() {
        act("portal");
        return Novel.playScene("pact");
    }
    // an outcome: stars (the bottom passed, the angel comes) · pact (signed: out now, a mark
    // stays) · limbo (neither here nor there until the angel finds you) · amnesty (fell
    // under the old rules, before the circles: let out once, after the update)
    function outcome(kind) {
        save.hell.outcomes = (hell.outcomes || []).concat([{
                    "kind": kind,
                    "circle": circle,
                    "at": now()
                }]).slice(-50);
        if (kind === "pact")
            save.hell.pact = true;
        else if (kind === "stars")
            save.hell.pact = false;     // the honest way out washes the mark off
        if (kind === "limbo") {
            save.hell.limbo = true;
            save.hell.limboSince = now();
            Angel.hush();
            if (circle !== "limbo")
                CircleFx.run("limbo", () => root.setCircle("limbo"), null);
            return true;
        }
        Angel.getOut(kind);
        return true;
    }
    // back at the computer after a while in limbo: the angel has found you
    function cameBack(awayMs) {
        if (!limbo || awayMs < limboReturnMinutes * 60000)
            return false;
        Angel.getOut("limbo");
        return true;
    }

    // ---- "What did I sign?" (D2): the pact on paper, and the way out as it stands ----
    property var contractText: ({})       // story/contract.json (draft texts)
    // signed: in force · washed: signed once, washed off on the way to the stars · none
    function pactState() {
        if (hell.pact)
            return "signed";
        return (hell.outcomes || []).some(o => o.kind === "pact") ? "washed" : "none";
    }
    function contractPaper() {
        const st = pactState();
        const c = contractText[st] || {};
        const signed = (hell.outcomes || []).filter(o => o.kind === "pact").pop();
        const where = signed && order.includes(signed.circle) ? Theme.roman(circleN(signed.circle)) + " — " + circleName(signed.circle) : I18n.t("портал", "the portal");
        const fill = s => render(s || "").replace(/%circle/g, where).replace(/%date/g, signed ? dateText(signed.at) : "");
        let text = fill(c.text);
        const terms = exitTerms();
        if (terms.length)
            text += "\n\n" + I18n.t("Условия выхода", "The way out") + "\n" + terms.map(l => "· " + l).join("\n");
        return {
            "state": st,
            "title": fill(c.title) || I18n.t("Договор", "The pact"),
            "text": text
        };
    }
    // her words as she hands it over (contract.json → say.angel|demon.<state>)
    function contractLine(who, st) {
        const list = ((contractText.say || {})[who] || {})[st] || [];
        if (!list.length)
            return "";
        const l = list[Math.floor(Math.random() * list.length)];
        return render(Array.isArray(l) ? (I18n.english ? l[1] : l[0]) : l);
    }
    function dateText(ms) {
        const d = new Date(ms);
        const ru = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];
        const en = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        return I18n.english ? d.getDate() + " " + en[d.getMonth()] + " " + d.getFullYear() : d.getDate() + " " + ru[d.getMonth()] + " " + d.getFullYear();
    }
    // the way out in numbers — where, when the next try is, how far the pact and limbo
    // are; never which answers lead down (issue #31: the player saw none of it)
    function exitTerms() {
        if (!enabled || !inHell)
            return [];
        if (hell.limbo)
            return [I18n.t("Лимб. Здесь никого нет. Отойди от компьютера — заблокируй экран минут на " + limboReturnMinutes + ", и ангел тебя найдёт", "Limbo. Nobody is here. Step away from the computer — lock the screen for " + limboReturnMinutes + " minutes, and the angel will find you")];
        const n = circleN(circle), a = hell.attempts || 0;
        const left = Math.ceil((nextTry - now()) / 60000);
        const ahead = order.slice(Math.max(0, order.indexOf(circle)) + 1).filter(id => !(hell.path || []).includes(id)).length;
        const toPact = pactAfter - a, toLimbo = limboAfter - (hell.silences || 0);
        const word = (v, one, few, many) => v % 10 === 1 && v % 100 !== 11 ? one : v % 10 >= 2 && v % 10 <= 4 && (v % 100 < 12 || v % 100 > 14) ? few : many;
        const out = [];
        out.push(I18n.t("Круг " + Theme.roman(n) + " из IX — " + circleName(circle), "Circle " + Theme.roman(n) + " of IX — " + circleName(circle)));
        out.push(I18n.t("Выход — вниз, через дно: впереди " + ahead + " " + word(ahead, "круг", "круга", "кругов"), "The way out is down, through the bottom: " + ahead + " " + (ahead === 1 ? "circle" : "circles") + " ahead"));
        out.push(left > 0 ? I18n.t("Следующая попытка — через " + left + " мин («Искать выход»)", "Next try in " + left + " min (“Seek the way out”)") : I18n.t("Следующая попытка — сейчас («Искать выход»)", "Next try: now (“Seek the way out”)"));
        out.push(I18n.t("Попыток в этом круге: " + a, "Tries in this circle: " + a));
        if (hell.pact)
            out.push(I18n.t("Договор подписан — короткого пути больше нет", "The pact is signed — there's no shorter way left"));
        else if (toPact > 0)
            out.push(toPact === 1 ? I18n.t("Короткий путь (договор) предложат на следующей попытке", "The short way (the pact) comes up at the next try") : I18n.t("Короткий путь (договор) предложат на " + toPact + "-й попытке в этом круге", "The short way (the pact) comes up at try " + toPact + " from now, in this circle"));
        else
            out.push(I18n.t("Короткий путь (договор) предлагают на каждой попытке — можно отказаться", "The short way (the pact) is offered at every try — you can refuse"));
        out.push(toLimbo > 0 ? I18n.t("Лимб — если промолчать ещё " + toLimbo + " " + word(toLimbo, "раз", "раза", "раз"), "Limbo — if you say nothing " + toLimbo + " more " + (toLimbo === 1 ? "time" : "times")) : I18n.t("Ещё одно молчание — и лимб", "One more silence and it's limbo"));
        return out;
    }

    // ---- the demon's voice in this circle (story/voices.json) ----
    function voiceLine(kind) {
        const v = voices[HellLook.voice] || {};
        const list = v[kind];
        if (!inHell || !list || !list.length)
            return "";
        const l = list[Math.floor(Math.random() * list.length)];
        const text = Array.isArray(l) ? (I18n.english ? l[1] : l[0]) : l;
        // Only introductions use %1/%2 for the circle. Wait and music lines
        // leave those placeholders for their caller's minutes / artist / song.
        const line = render(text);
        return kind === "enter" ? line.replace("%1", circleName(circle)).replace("%2", Theme.roman(circleN(circle))) : line;
    }

    // ---- on / off ----
    // off: plain dotfiles at once — hell undone without a show, the corner empty, no novel
    function setEnabled(on) {
        if (!on && player.character === "demon")
            Angel.leaveNow();
        Novel.stopScene();
        Config.game.enabled = !!on;
        return on ? "on" : "off";
    }
    // switched off some other way (settings.json edited, the setup wizard): the same
    onEnabledChanged: if (!enabled && ready) {
        if (player.character === "demon")
            Angel.leaveNow();
        Novel.stopScene();
    }

    // the exit key, Mod+Ctrl+Shift+Escape → `angelos game off` (a niri bind in
    // cfg/angelos-windows.kdl through window-config.py, like the lens' keys): always there
    property bool _quitKey: false
    Process {
        id: keyReader
        running: !Shell.dev
        command: ["python3", Quickshell.shellDir + "/scripts/window-config.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._quitKey = !!JSON.parse(text).quit;
                } catch (e) {
                    return;
                }
                if (!root._quitKey && !keyWriter.running)
                    keyWriter.running = true;
            }
        }
    }
    Process {
        id: keyWriter
        command: ["python3", Quickshell.shellDir + "/scripts/window-config.py", JSON.stringify({
                "quit": true
            })]
    }

    // ---- dev: Settings → System (developer mode), `angelos game …` ----
    function status() {
        const dev = Shell.dev || Config.developer.enabled;
        const sins = {};
        for (const id of order)
            sins[id] = Number(vars[id]) || 0;
        return JSON.stringify({
            "enabled": enabled,
            "calm": calm,
            "realm": inHell ? "hell" : "heaven",
            "circle": circle ? circleN(circle) + " " + circle : "",
            "path": hell.path || [],
            "nextFall": circleForFall(),
            "sins": sins,
            "attempts": hell.attempts || 0,
            "nextTry": inHell ? Math.max(0, Math.ceil((nextTry - now()) / 60000)) + " min" : "",
            "silences": hell.silences || 0,
            "falls": hell.falls || 0,
            "returns": player.returns || 0,
            // past cold is the story's secret: only developer mode sees it (and the betrayals)
            "angel": (angelStep > 3 && !dev ? "cold" : angelStepName) + " (chill " + chill + (player.coldRoute ? ", cold route" : "") + (dev ? ", betrayals " + (player.betrayals || 0) + (player.fallenDue ? ", fallen when back" : "") : "") + ")",
            "close": hell.close || {},
            "pact": !!hell.pact,
            "limbo": !!hell.limbo,
            "outcomes": (hell.outcomes || []).map(o => o.kind + "@" + o.circle),
            "scene": Novel.sceneStatus(),
            "choices": (save.choices || []).length,
            "file": file
        }, null, 1);
    }
    // jump into a circle (by id or number); from heaven the angel falls first
    function jump(target) {
        const id = order.includes(target) ? target : order[(parseInt(target) || 0) - 1];
        if (!id)
            return "circles: 1–9 or " + order.join(" ");
        if (!inHell) {
            _jumpTo = id;
            Angel.toHell();
            return "falling into " + id;
        }
        enter(id);
        return "ok";
    }
    property string _jumpTo: ""
    // Angel asks where the fall lands: a dev jump wins over the sins
    function fallTarget() {
        const j = _jumpTo;
        _jumpTo = "";
        return j;
    }
    function reset() {
        if (inHell)
            Angel.leaveNow();
        Novel.stopScene();
        save.vars = ({});
        save.choices = [];
        save.novel = null;
        for (const k of ["path", "fallCircles", "outcomes"])
            save.hell[k] = [];
        save.hell.close = ({});
        save.hell.circle = "";
        save.hell.falls = 0;
        save.hell.attempts = 0;
        save.hell.silences = 0;
        save.hell.limbo = false;
        save.hell.pact = false;
        save.player.lastPlea = 0;
        save.player.wheelAt = 0;
        save.player.returns = 0;
        save.player.pranks = [];
        save.player.chill = 0;
        save.player.lastThrow = 0;
        save.player.thawAt = 0;
        save.player.coldRoute = false;
        save.player.coldSince = 0;
        save.player.coldSeen = false;
        save.player.betrayals = 0;
        save.player.fallenDue = false;
        save.player.fallen = false;
        save.player.fallenSince = 0;
        save.player.fallenSeen = false;
        _beforeThrow = null;
        setCircle("");
        Novel.reset();
        return "save reset";
    }
}
