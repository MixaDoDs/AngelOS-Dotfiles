pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../novel/NovelCore.js" as Core

// The novel: chapters the angel (or the demon) plays out on the desktop, written in the
// dialogue editor (`angelos novel edit` — the author's tool in owner/novel-editor, fetched by
// `angelos author`) into ~/AngelOs-Nov/story/*.json.
// The rules — node types, templates, conditions — are novel/NovelCore.js, shared with the
// editor's play-test. Shown by modules/novel (the dialogue box next to her, the crumpled
// paper on the desk, the unfolded note) and AngelHelper ("?" over her head).
//
// Two threads run a chapter: the main line (state.main) and a side thread for the pool's
// questions (state.side), each a node it is at and what it waits for: "" (run now), click
// (the user clicks her: the "?"), resume (the computer woke from sleep), at:<ms> (a time),
// show (she can't be shown right now: locked, streaming, fullscreen, hidden, the wrong
// one rules — tried again every few seconds), note (a paper waits to be read), line (the
// box is up, waiting for the user). After a "free" node the side thread now and then
// takes an unasked question from the pool (each once) and she drops notes (pools.drops).
// The game's scenes (story/scenes/*.json in the shell, services/Story) run on a third
// thread, state.game: they are entered by an event (Novel.playScene(trigger): "trial",
// "pact", "limbo"… — the first scene whose event's `cond` holds), see the game's variables
// (the sins, the circle, the tries) instead of the chapter's, and have three nodes more —
// circle, exit, scene (novel/NovelCore.js).
// Progress lives in the player's save (~/.config/angelos/save.json → novel, services/Story;
// it was ~/.local/state/angelos/novel.json); `angelos novel reset` starts over.
Singleton {
    id: root

    readonly property string dir: Config.expand(Config.novel.dir || "~/AngelOs-Nov")
    // the chapters: the novel on and the game on (`angelos game off` stops everything)
    readonly property bool enabled: Config.novel.enabled && Story.enabled
    property var stories: ({})               // "chapter1" → story
    property var scenes: ({})                // "trial-greed" → a game scene (story/scenes)
    property var sprites: ({})               // "angel" → {"happy": "/…/sprites/angel/happy.png"}
    // the picture for a sprite name, "" when there is no such file (the box goes without it)
    function spriteFile(who, name) {
        const m = sprites[who] || {};
        return m[name || "neutral"] || "";
    }
    property bool loaded: false
    property var state: freshState()
    property bool stateLoaded: false

    // ---- what modules/novel shows ----
    // the box: {who, sprite, text, choices: [{text, tone}], thread} or null
    property var line: null
    // a crumpled paper on the desk: {from: desk|angel, title, text, thread} or null; noteOpen: unfolded
    property var paper: null
    property bool noteOpen: false
    readonly property bool wantsClick: !line && ((enabled && canShow && (waitsFor("main") === "click" || waitsFor("side") === "click")) || (waitsFor("game") === "click" && canShowFor("game")))
    signal dropped                            // she let a note fall (the paper falls from her)

    function freshState() {
        return {
            "chapter": "",
            "vars": {},
            "seen": [],
            "asked": [],
            "done": {},
            "begun": {},
            "free": false,
            "nextQ": 0,
            "nextDrop": 0,
            "main": {
                "node": "",
                "wait": ""
            },
            "side": {
                "node": "",
                "wait": ""
            },
            "game": {
                "scene": "",
                "node": "",
                "wait": ""
            },
            "log": []
        };
    }
    function story() {
        return stories[state.chapter] || null;
    }
    // the story a thread plays: the chapter, or the game's scene
    function storyOf(thread) {
        return thread === "game" ? scenes[(state.game || {}).scene] || null : stories[state.chapter] || null;
    }
    function waitsFor(thread) {
        const t = state[thread];
        return t && t.node ? String(t.wait || "") : "";
    }

    // ---- may she show something now? ----
    // the game's scenes may come without her (limbo: nobody in the corner), and while the
    // circle's dark is down they wait
    readonly property bool baseShow: Story.enabled && !Angel.transition && !CircleFx.active && !Shell.locked && !Idle.active && !StreamMode.active && !!Angel.screen && !Shell.hiddenScreen(Angel.screenName) && !Shell.fullscreenOn(Angel.screenName)
    function canShowFor(thread) {
        const st = storyOf(thread);
        const who = st ? st.with || "angel" : "angel";
        if (!baseShow)
            return false;
        if (who === "any")
            return true;
        return Angel.present && (who === "demon") === Angel.demon;
    }
    readonly property bool canShow: baseShow && Angel.present && (function () {
            const st = stories[state.chapter];
            const who = st ? st.with || "angel" : "angel";
            return who === "any" || (who === "demon") === Angel.demon;
        })()

    // ---- text ----
    // {app} is the program's name only — never a window's title (that holds the page you
    // read and who you write to); the story knows only what the shell knows anyway
    function appName(w) {
        const id = String(w && w.app_id || "");
        if (!id)
            return "";
        const e = DesktopEntries.heuristicLookup(id);
        return e && e.name ? e.name : id.replace(/^.*\./, "");
    }
    function ctx() {
        return {
            "vars": state.vars,
            "name": Config.novel.name || StartApps.userName,
            "app": appName(Niri.focusedWindow),
            "song": Lyrics.title || "",
            "uptime": Story.uptimeText(),
            "english": I18n.english,
            "now": new Date()
        };
    }
    function txt(s, thread) {
        return thread === "game" ? Story.render(s) : Core.render(s, ctx());
    }

    // ---- the chapter ----
    function startChapter(id) {
        const st = stories[id];
        if (!st)
            return "no chapter " + id;
        const s = freshState();
        s.chapter = id;
        s.done = state.done || {};
        s.begun = Object.assign({}, state.begun || {});
        s.begun[id] = true;
        s.vars = Object.assign({}, st.vars || {}, {
            "setupGender": Config.novel.gender || "",
            "gender": (state.vars || {}).gender || ""
        });
        line = null;
        paper = null;
        noteOpen = false;
        state = s;
        go("main", st.start);
        return "ok";
    }
    // enter a node: it runs now or waits for its moment
    function go(thread, id) {
        const st = storyOf(thread);
        const s = Object.assign({}, state);
        const n = st && id ? st.nodes[id] : null;
        // (a thread keeps its other fields: the game's knows its scene)
        if (!n) {
            s[thread] = Object.assign({}, s[thread], {
                "node": "",
                "wait": ""
            });
            state = s;
            save();
            return;
        }
        const when = n.when || "now";
        let wait = "";
        if (when === "click")
            wait = "click";
        else if (when === "resume")
            wait = "resume";
        else if (/^minutes:\d+$/.test(when))
            wait = "at:" + (Date.now() + parseInt(when.slice(8)) * 60000);
        s[thread] = Object.assign({}, s[thread], {
            "node": id,
            "wait": wait
        });
        state = s;
        save();
        if (!wait)
            run(thread);
    }
    function setWait(thread, wait) {
        const s = Object.assign({}, state);
        s[thread] = Object.assign({}, s[thread], {
            "wait": wait
        });
        state = s;
        save();
    }
    function remember(id, thread) {
        if (thread === "game")
            id = state.game.scene + "/" + id;
        if (state.seen.indexOf(id) < 0) {
            const s = Object.assign({}, state);
            s.seen = s.seen.concat([id]);
            state = s;
        }
    }
    function setVars(set, thread) {
        if (!set)
            return;
        if (thread === "game")
            return Story.applySet(set);
        const s = Object.assign({}, state);
        s.vars = Core.applySet(s.vars, set);
        state = s;
    }
    // run the node a thread is at (its moment has come)
    function run(thread) {
        const st = storyOf(thread);
        const id = state[thread].node;
        const n = st && id ? st.nodes[id] : null;
        if (!n)
            return go(thread, "");
        if (!canShowFor(thread) && ["say", "choice", "note"].indexOf(n.type) >= 0) {
            setWait(thread, "show");
            return;
        }
        remember(id, thread);
        switch (n.type) {
        case "event":
            return go(thread, n.next);
        case "say":
            setWait(thread, "line");
            Angel.hush();
            line = {
                "who": n.who || "angel",
                "sprite": n.sprite || "neutral",
                "text": txt(n.text, thread),
                "choices": [],
                "thread": thread
            };
            return;
        case "choice":
            {
                setWait(thread, "line");
                Angel.hush();
                // `shuffle`: the answers in another order every time (the silent one stays
                // last), so the right one isn't learnt by its place; `order` maps them back
                const all = n.choices || [];
                let order = all.map((c, i) => i);
                if (n.shuffle) {
                    const loud = order.filter(i => all[i].tone !== "silent");
                    for (let i = loud.length - 1; i > 0; i--) {
                        const j = Math.floor(Math.random() * (i + 1));
                        [loud[i], loud[j]] = [loud[j], loud[i]];
                    }
                    order = loud.concat(order.filter(i => all[i].tone === "silent"));
                }
                line = {
                    "who": n.who || "angel",
                    "sprite": n.sprite || "neutral",
                    "text": txt(n.text, thread),
                    "choices": order.map(i => ({
                                "text": txt(all[i].text, thread),
                                "tone": all[i].tone || "neutral"
                            })),
                    "order": order,
                    "thread": thread
                };
                return;
            }
        case "note":
            setWait(thread, "note");
            paper = {
                "from": n.from || "desk",
                "title": txt(n.title || "", thread),
                "text": txt(n.text || "", thread),
                "thread": thread
            };
            if (paper.from === "angel")
                dropped();
            return;
        case "set":
            setVars(n.set, thread);
            return go(thread, n.next);
        case "if":
            {
                let ok = false;
                try {
                    ok = Core.evalCond(n.cond, thread === "game" ? Story.ctxVars() : state.vars, state.seen);
                } catch (e) {
                    console.warn("novel: if", id, e.message);
                }
                return go(thread, ok ? n.then : n["else"]);
            }
        case "random":
            {
                const list = (Array.isArray(n.next) ? n.next : [n.next]).filter(x => !!x);
                return go(thread, list[Math.floor(Math.random() * list.length)] || "");
            }
        case "free":
            {
                const s = Object.assign({}, state);
                s.free = true;
                s.nextQ = Date.now() + rangeMs((st.ambient || {}).questions, 25, 70);
                s.nextDrop = Date.now() + rangeMs((st.ambient || {}).drops, 30, 90);
                state = s;
                return go(thread, n.next);
            }
        // the game's own: into a circle, out of hell, on in another scene
        case "circle":
            go(thread, n.next || "");
            if (n.to === "deeper")
                Story.deeper();
            else if (n.to === "stay")
                Story.stay();
            else
                Story.enter(n.to);
            return;
        case "exit":
            go(thread, "");
            Story.outcome(n.outcome);
            return;
        case "scene":
            return startScene(n.to);
        case "end":
            if (thread === "game")
                return go(thread, "");
            {
                const s = Object.assign({}, state);
                s.done = Object.assign({}, s.done);
                s.done[s.chapter] = true;
                state = s;
                Achievements.note("novel.chapter", s.chapter);
                go(thread, "");
                // the next chapter starts the way its own event says
                if (n.chapter && stories[n.chapter])
                    pendingChapter = n.chapter;
                return;
            }
        }
        go(thread, n.next);
    }
    property string pendingChapter: ""
    function rangeMs(r, a, b) {
        const lo = Math.max(1, (r && r[0]) || a), hi = Math.max(lo, (r && r[1]) || b);
        return (lo + Math.random() * (hi - lo)) * 60000;
    }

    // ---- the user ----
    // the box was clicked / Enter: the line goes on (a question waits for its answer)
    function advance() {
        if (!line || line.choices.length)
            return;
        const thread = line.thread;
        line = null;
        if (_after !== null) {
            const to = _after;
            _after = null;
            return go(thread, to);
        }
        const st = storyOf(thread);
        const n = st ? st.nodes[state[thread].node] : null;
        go(thread, n ? n.next : "");
    }
    property var _after: null                 // where a reply line leads
    function choose(i) {
        if (!line || i < 0 || i >= line.choices.length)
            return;
        if (line.order)
            i = line.order[i];
        const thread = line.thread;
        const st = storyOf(thread);
        const n = st ? st.nodes[state[thread].node] : null;
        const c = n && n.choices ? n.choices[i] : null;
        if (!c)
            return;
        log(state[thread].node, i);
        Story.chose(thread === "game" ? state.game.scene : state.chapter, state[thread].node, i, c.tone || "neutral");
        setVars(c.set, thread);
        if (c.reply && c.reply.text) {
            _after = c.next || "";
            line = {
                "who": c.reply.who || n.who || "angel",
                "sprite": c.reply.sprite || "neutral",
                "text": txt(c.reply.text, thread),
                "choices": [],
                "thread": thread
            };
            return;
        }
        line = null;
        go(thread, c.next || "");
    }
    function log(node, choice) {
        const s = Object.assign({}, state);
        s.log = (s.log || []).concat([{
                    "at": Date.now(),
                    "node": node,
                    "choice": choice
                }]).slice(-200);
        state = s;
    }
    // a click on her: true when the story took it (AngelHelper then opens no menu)
    function click() {
        if (line)
            return false;
        for (const th of ["game", "main", "side"])
            if ((th === "game" || enabled) && waitsFor(th) === "click" && canShowFor(th)) {
                run(th);
                return true;
            }
        return false;
    }
    // a paper shown unfolded at once, outside any story ("What did I sign?": Story.contractPaper);
    // folding it leads nowhere. Never over a story's own paper — that one waits to be read
    function showPaper(title, text, from) {
        if (paper !== null)
            return false;
        paper = {
            "from": from || "angel",
            "title": title || "",
            "text": text || "",
            "thread": ""
        };
        noteOpen = true;
        return true;
    }
    // the paper was unfolded and folded again
    function noteRead() {
        const p = paper;
        noteOpen = false;
        paper = null;
        if (p && p.thread) {
            const st = storyOf(p.thread);
            const n = st ? st.nodes[state[p.thread].node] : null;
            go(p.thread, n ? n.next : "");
        }
    }
    // the computer woke up: chapters that begin after sleep, nodes that wait for it
    function resumed() {
        if (!enabled)
            return;
        reload();
        resumeSoon.restart();
    }
    Timer {
        id: resumeSoon
        interval: 4000
        onTriggered: {
            for (const th of ["game", "main", "side"])
                if (root.waitsFor(th) === "resume")
                    root.run(th);
            if (!root.state.main.node && !root.line)
                root.maybeStart("resume");
        }
    }
    // a chapter not begun yet whose event fits starts (one at a time); `end` can name the
    // next one (pendingChapter), which then starts on its own event
    function triggerOf(id) {
        const st = stories[id];
        const n = st && st.nodes ? st.nodes[st.start] : null;
        return n && n.type === "event" ? n.trigger || "manual" : "manual";
    }
    function maybeStart(trigger) {
        if (state.main.node || line)
            return false;
        const begun = state.begun || {};
        let want = "";
        if (pendingChapter && stories[pendingChapter])
            want = triggerOf(pendingChapter) === trigger ? pendingChapter : "";
        else
            want = Object.keys(stories).sort().find(id => !begun[id] && triggerOf(id) === trigger) || "";
        if (!want)
            return false;
        pendingChapter = "";
        startChapter(want);
        return true;
    }

    // ---- the clock: timed nodes, retries, the pool ----
    Timer {
        interval: 5000
        running: Story.enabled && root.loaded && root.stateLoaded
        repeat: true
        onTriggered: root.tick()
    }
    property double _lastTick: Date.now()
    function tick() {
        const now = Date.now();
        // a jump of the wall clock: the machine slept (also told by Lock via Shell.resumed)
        if (now - _lastTick > 90000)
            resumed();
        _lastTick = now;
        // the game's scene first: it is what is happening to the player right now
        for (const th of enabled ? ["game", "main", "side"] : ["game"]) {
            if (!storyOf(th))
                continue;
            const w = waitsFor(th);
            if (w.startsWith("at:") && now >= parseInt(w.slice(3)))
                run(th);
            else if (w === "show" && canShowFor(th) && !line && !paper)
                run(th);
        }
        if (!enabled || !story())
            return;
        if (!state.free || !canShow || line || paper)
            return;
        const st = story();
        // a question from the pool, each once; the "?" waits for a click
        if (!state.side.node && now >= state.nextQ && waitsFor("main") !== "click") {
            const left = ((st.pools || {}).questions || []).filter(q => state.asked.indexOf(q) < 0 && st.nodes[q]);
            const s = Object.assign({}, state);
            s.nextQ = now + rangeMs((st.ambient || {}).questions, 25, 70);
            if (left.length) {
                const q = left[Math.floor(Math.random() * left.length)];
                s.asked = s.asked.concat([q]);
                state = s;
                go("side", q);
                if (waitsFor("side") === "click")
                    Angel.say(I18n.t("Эй… можно спросить? Нажми на меня ♡", "Hey… can I ask you something? Click me ♡"), null, 7000);
            } else {
                state = s;
            }
            save();
            return;
        }
        // a note falls from her
        if (now >= state.nextDrop) {
            const drops = ((st.pools || {}).drops || []);
            const s = Object.assign({}, state);
            s.nextDrop = now + rangeMs((st.ambient || {}).drops, 30, 90);
            state = s;
            save();
            if (drops.length) {
                const d = drops[Math.floor(Math.random() * drops.length)];
                paper = {
                    "from": "angel",
                    "title": "",
                    "text": txt(d.text),
                    "thread": ""
                };
                dropped();
            }
        }
    }

    // ---- files: the chapters, and the progress ----
    function reload() {
        loader.running = false;
        loader.running = true;
    }
    Process {
        id: loader
        // the chapters, the game's scenes and the sprite files in one go:
        // {stories: {id: story}, scenes: {id: scene}, sprites: {who: {name: path}}}
        command: ["python3", "-c", "import json,sys,pathlib\nb=pathlib.Path(sys.argv[1])\ndef load(d):\n    out={}\n    for f in sorted(d.glob('*.json')) if d.is_dir() else []:\n        try: out[f.stem]=json.loads(f.read_text())\n        except Exception as e: print('novel: '+f.name+': '+str(e),file=sys.stderr)\n    return out\nsp={}\nfor w in sorted((b/'sprites').iterdir()) if (b/'sprites').is_dir() else []:\n    if w.is_dir():\n        m={}\n        for f in sorted(w.iterdir()):\n            if f.suffix.lower() in ('.png','.webp','.gif','.jpg','.jpeg'): m.setdefault(f.stem,str(f))\n        sp[w.name]=m\nprint(json.dumps({'stories':load(b/'story'),'scenes':load(pathlib.Path(sys.argv[2])),'sprites':sp}))", root.dir, Quickshell.shellDir + "/story/scenes"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text || "{}");
                    root.stories = d.stories || {};
                    root.scenes = d.scenes || {};
                    root.sprites = d.sprites || {};
                } catch (e) {
                    root.stories = {};
                }
                const first = !root.loaded;
                root.loaded = true;
                if (first)
                    root.started();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text)
                console.warn(text.trim())
        }
    }
    // the shell started: a chapter waiting for "start", or one cut off mid-line goes on
    function started() {
        if (!stateLoaded)
            return;
        // the game's scene was renamed or removed by an update: it can't go on
        if (sceneStale())
            stopScene();
        for (const th of ["game", "main", "side"]) {
            const w = waitsFor(th);
            // the box or a paper was up when the shell went down: show it again
            if (w === "line" || w === "note" || w === "show")
                setWait(th, "show");
        }
        if (enabled && !state.main.node)
            maybeStart("start");
    }
    // the progress lives in the player's save (Story: ~/.config/angelos/save.json → novel)
    function loadState() {
        if (stateLoaded || !Story.ready)
            return;
        const st = Story.novelState;
        state = Object.assign(freshState(), st && typeof st === "object" ? st : {});
        stateLoaded = true;
        if (loaded)
            started();
    }
    Connections {
        target: Story
        function onReadyChanged() {
            root.loadState();
        }
    }
    function save() {
        saveSoon.restart();
    }
    Timer {
        id: saveSoon
        interval: 400
        onTriggered: Story.saveNovel(root.state)
    }
    Component.onCompleted: {
        loadState();
        reload();
    }
    onEnabledChanged: if (enabled)
        reload()
    // new chapters and sprites written meanwhile (the editor saves into the folder)
    Timer {
        interval: 180000
        running: root.enabled && root.loaded
        repeat: true
        onTriggered: root.reload()
    }
    // settings arrive after the singleton: the folder may change from the default
    onDirChanged: if (enabled)
        reload()
    // the wizard (or Settings) set the gender: the chapter knows what was said there
    Connections {
        target: Config.novel
        function onGenderChanged() {
            const s = Object.assign({}, root.state);
            s.vars = Object.assign({}, s.vars, {
                "setupGender": Config.novel.gender || ""
            });
            root.state = s;
            root.save();
        }
    }
    Connections {
        target: Shell
        function onResumed() {
            root.resumed();
        }
    }

    // ---- for Settings and IPC ----
    function reset() {
        line = null;
        paper = null;
        noteOpen = false;
        state = freshState();
        save();
        return "ok";
    }
    function status() {
        return JSON.stringify({
            "enabled": enabled,
            "dir": dir,
            "chapters": Object.keys(stories),
            "chapter": state.chapter,
            "main": state.main,
            "side": state.side,
            "free": state.free,
            "vars": state.vars,
            "nextQ": state.nextQ ? Math.round((state.nextQ - Date.now()) / 60000) + " min" : "",
            "nextDrop": state.nextDrop ? Math.round((state.nextDrop - Date.now()) / 60000) + " min" : "",
            "canShow": canShow,
            "line": !!line,
            "tones": line ? line.choices.map(c => c.tone) : [],
            "game": state.game,
            "paper": !!paper
        });
    }
    // dev and the owner: the next question / note right now
    function forceQuestion() {
        const s = Object.assign({}, state);
        s.nextQ = 0;
        s.free = true;
        state = s;
        tick();
    }
    function forceDrop() {
        const s = Object.assign({}, state);
        s.nextDrop = 0;
        s.free = true;
        state = s;
        tick();
    }
    // the dialogue editor is the author's tool (owner/, `angelos author`): there only for them
    readonly property string editorPath: Quickshell.shellDir + "/owner/novel-editor/nov-editor.py"
    property bool editorHere: false
    FileView {
        path: root.editorPath
        printErrors: false
        watchChanges: true
        onLoaded: root.editorHere = true
        onLoadFailed: root.editorHere = false
        onFileChanged: reload()
    }
    function edit() {
        if (editorHere)
            Quickshell.execDetached(["python3", editorPath, "--dir", dir]);
    }

    // ---- the game's scenes (services/Story) ----
    readonly property bool sceneBusy: !!(state.game && state.game.node)
    function eventOf(sc) {
        const n = sc && sc.nodes ? sc.nodes[sc.start] : null;
        return n && n.type === "event" ? n : null;
    }
    // the scene whose event is `trigger` and whose `cond` holds now: the highest event
    // `priority` first (default 0), then by id
    function sceneFor(trigger) {
        const vars = Story.ctxVars();
        const prio = id => {
            const ev = eventOf(scenes[id]);
            return ev && ev.priority ? Number(ev.priority) : 0;
        };
        for (const id of Object.keys(scenes).sort((a, b) => prio(b) - prio(a) || (a < b ? -1 : a > b ? 1 : 0))) {
            const ev = eventOf(scenes[id]);
            if (!ev || ev.trigger !== trigger)
                continue;
            let ok = false;
            try {
                ok = Core.evalCond(ev.cond, vars, state.seen);
            } catch (e) {
                console.warn("scene", id, e.message);
            }
            if (ok)
                return id;
        }
        return "";
    }
    function playScene(trigger) {
        const id = sceneFor(trigger);
        if (!id)
            return false;
        startScene(id);
        return true;
    }
    function startScene(id) {
        const sc = scenes[id];
        if (!sc)
            return false;
        if (line && line.thread === "game")
            line = null;
        const s = Object.assign({}, state);
        s.game = {
            "scene": id,
            "node": "",
            "wait": ""
        };
        state = s;
        go("game", sc.start);
        return true;
    }
    function stopScene() {
        if (line && line.thread === "game")
            line = null;
        if (paper && paper.thread === "game")
            paper = null;
        const s = Object.assign({}, state);
        s.game = {
            "scene": "",
            "node": "",
            "wait": ""
        };
        state = s;
        save();
    }
    // the save points at a scene or node that isn't there any more (scenes are drafts and
    // get renamed): nothing can run it, and it must not block the way out (issue #31)
    function sceneStale() {
        const g = state.game || {};
        if (!g.node || !loaded)
            return false;
        const sc = scenes[g.scene];
        return !sc || !sc.nodes || !sc.nodes[g.node];
    }
    // the game's box (or its paper) is on screen right now
    function sceneShown() {
        return (!!line && line.thread === "game") || (!!paper && paper.thread === "game");
    }
    // the player asked for the way out while a scene waits: show where it stopped
    function resumeScene() {
        const w = waitsFor("game");
        if (!w || sceneShown())
            return;
        if (w === "line" || w === "note" || w === "show" || w === "click")
            run("game");
    }
    function sceneStatus() {
        const g = state.game || {};
        return g.scene ? g.scene + " · " + (g.node || "—") + (g.wait ? " (" + g.wait + ")" : "") : "";
    }
}
