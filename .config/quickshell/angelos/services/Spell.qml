pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Spelling in the shell's own text fields (widgets/PxSpell: notes, replies to notifications),
// Settings → Devices → Spelling, `angelos spell`. scripts/spell.py does the work with
// libhunspell: this keeps one of it running while somebody types (it lets go of the
// dictionaries two minutes after the last question), and downloads or deletes the
// dictionaries, one per language, into ~/.local/share/angelos/spell.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/spell.py"
    property bool engine: true         // libhunspell is there
    property var installed: []         // [{code, ru, en, source: user|system, script}]
    property var catalog: []           // [{code, ru, en, installed, top}], what can be downloaded
    property bool loaded: false
    property var working: ({})         // code -> "install" | "remove" while it runs
    property string error: ""
    property int epoch: 0              // bumped when the dictionaries or the user's words change: fields check again
    readonly property var off: Config.spell.off || []
    readonly property var active: installed.filter(d => !off.includes(d.code))
    readonly property bool on: Config.ready && Config.spell.enabled !== false
    // somebody may be underlined: a field asks only then
    readonly property bool ready: on && loaded && engine && active.length > 0

    function title(d) {
        return I18n.english ? d.en : d.ru;
    }
    // a field got the caret: find out what is installed (once)
    function want() {
        if (!loaded && !lister.running)
            lister.running = true;
    }
    function refresh() {
        if (!lister.running)
            lister.running = true;
    }

    // ---- questions to the helper: cb(answer) ----
    property int _id: 0
    property var _waiting: ({})
    property var _unsent: []
    function _ask(req, cb) {
        const id = ++_id;
        req.id = id;
        if (cb)
            _waiting[id] = cb;
        const line = JSON.stringify(req) + "\n";
        if (server.running && server.up)
            server.write(line);
        else {
            _unsent.push(line);
            server.running = true;
        }
        idle.restart();
        return id;
    }
    function check(text, cb) {
        if (!ready) {
            cb([]);
            return;
        }
        _ask({
            "op": "check",
            "text": text,
            "off": off
        }, a => cb(a.errors || []));
    }
    function suggest(word, cb) {
        if (!ready) {
            cb([]);
            return;
        }
        _ask({
            "op": "suggest",
            "word": word,
            "off": off
        }, a => cb(a.suggest || []));
    }
    // the user's own words (~/.config/angelos/spell-words.txt)
    function learn(word) {
        _ask({
            "op": "add",
            "word": word
        }, () => root.epoch++);
    }
    function forget(word) {
        _ask({
            "op": "forget",
            "word": word
        }, () => root.epoch++);
    }

    // ---- the dictionaries ----
    property var _queue: []
    function setOn(code, on) {
        const list = off.filter(c => c !== code);
        Config.spell.off = on ? list : list.concat([code]);
        epoch++;
    }
    function install(code) {
        _run("install", code);
    }
    function remove(code) {
        _run("remove", code);
    }
    function _run(what, code) {
        if (working[code])
            return;
        const w = Object.assign({}, working);
        w[code] = what;
        working = w;
        error = "";
        _queue = _queue.concat([[what, code]]);
        _pump();
    }
    function _pump() {
        if (runner.running || !_queue.length)
            return;
        runner.job = _queue[0];
        _queue = _queue.slice(1);
        runner.command = ["python3", script, runner.job[0], runner.job[1]];
        runner.running = true;
    }

    Process {
        id: lister
        command: ["python3", root.script, "langs"]
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.engine = d.engine !== false;
                    root.installed = d.installed || [];
                    root.catalog = d.catalog || [];
                    root.loaded = true;
                    root.epoch++;
                } catch (e) {}
            }
        }
    }
    Process {
        id: runner
        property var job: null
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                let res = null;
                try {
                    res = JSON.parse(text.trim().split("\n").pop());
                } catch (e) {}
                if (!res || !res.ok)
                    root.error = (res && res.error) || I18n.t("Не получилось", "That didn't work");
            }
        }
        onExited: {
            if (job) {
                const w = Object.assign({}, root.working);
                delete w[job[1]];
                root.working = w;
            }
            job = null;
            // the helper holds the old set open
            if (server.running)
                root._ask({
                    "op": "reload"
                }, null);
            lister.running = true;
            root._pump();
        }
    }
    Process {
        id: server
        property bool up: false
        command: ["python3", root.script, "serve"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let a = null;
                try {
                    a = JSON.parse(line);
                } catch (e) {
                    return;
                }
                const cb = root._waiting[a.id];
                delete root._waiting[a.id];
                if (cb)
                    cb(a);
            }
        }
        onStarted: {
            up = true;
            for (const line of root._unsent)
                write(line);
            root._unsent = [];
        }
        onExited: {
            up = false;
            // whoever still waits gets nothing rather than waiting for ever
            const waiting = root._waiting;
            root._waiting = ({});
            for (const id in waiting)
                waiting[id]({});
            if (root._unsent.length)
                running = true;
        }
    }
    Timer {
        id: idle
        interval: 120000
        onTriggered: server.running = false
    }

    // `angelos spell …`
    function ipc(line) {
        const words = String(line || "").trim().split(/\s+/).filter(w => w);
        const cmd = words[0] || "status";
        switch (cmd) {
        case "status":
            return JSON.stringify({
                "on": on,
                "ready": ready,
                "engine": engine,
                "loaded": loaded,
                "installed": installed.map(d => d.code),
                "off": off,
                "working": working,
                "error": error
            });
        case "refresh":
            refresh();
            return "ok";
        case "on":
        case "off":
            Config.spell.enabled = cmd === "on";
            return "ok";
        case "install":
        case "remove":
            if (!words[1])
                break;
            _run(cmd, words[1]);
            return "ok";
        case "learn":
        case "forget":
            if (!words[1])
                break;
            if (cmd === "learn")
                learn(words[1]);
            else
                forget(words[1]);
            return "ok";
        case "open":
            Shell.openSettings("spell");
            return "ok";
        }
        return "angelos spell [status] | on | off | install CODE | remove CODE | learn WORD | forget WORD | refresh | open — spelling in notes and replies (Settings → Devices → Spelling); languages: ru, en, uk, de, fr…";
    }
}
