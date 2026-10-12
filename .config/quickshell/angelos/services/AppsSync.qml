pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The author's apps after an update: what the author added to the groups this user took in the
// installer or the wizard (data/apps-catalog.json), and new base packages of the dotfiles
// repository (scripts/apps-install.py pending). Told once per login and after each update, with
// «Поставить» (the shell's own window, modules/settings/AppsSyncPrompt.qml: what is new, a tick
// each, then the install right there — one admin password through pkexec, progress per item;
// apps-install.py sync --events) and «Не надо» (ack: not offered again). Nothing is installed
// without the user, nothing is ever removed. `angelos apps` opens the window by hand.
// Not on the author's own machine (owner/), not before the setup wizard ran (it asks itself).
// At login it also puts the author's Spotify look back after a Spotify update (spicetify-apply.sh).
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/apps-install.py"
    property var apps: []          // catalog ids
    property var suggest: []       // a system that never picked: the author's other apps, once
    property var packages: []      // base package names
    property bool fish: false      // the login shell is still bash: the author's fish is offered
    readonly property int count: apps.length + suggest.length + packages.length + (fish ? 1 : 0)
    property string _told: ""
    property var _names: ({})
    property var _cat: ({})

    // ---- the window ----
    property bool open: false
    property var offer: []         // what is new: [{id, ru, en, hintRu, hintEn, icon, plain, on}]
    readonly property var taken: offer.filter(x => x.on).map(x => x.id)
    property bool running: false
    property bool done: false
    property var items: []         // the run: [{id, ru, en, icon, plain, state: wait|run|done|fail}]
    property string status: ""     // what it does right now (the last line of the output)
    property var failed: []
    property string auth: ""       // why it never started (the password was not given…)
    property var log: []
    property real sub: 0           // how far the item now going is (Shell.stepOf over its output)
    readonly property bool allDone: done && !failed.length && !auth

    function check() {
        if (Shell.dev || Owner.hasDir || !Config.ready || !Config.setup.complete || probe.running)
            return;
        probe.command = ["python3", script, "pending", "--repo", Updates.repo || ""];
        probe.running = true;
    }
    // ids: catalog ids, pkg:NAME for a system package, fish — as scripts/apps-install.py takes them
    function buildOffer() {
        const row = (id, ru, en, hintRu, hintEn, icon, plain, on) => ({
                "id": id,
                "ru": ru,
                "en": en,
                "hintRu": hintRu,
                "hintEn": hintEn,
                "icon": icon,
                "plain": plain,
                "on": on
            });
        const app = (i, on) => {
            const a = _cat[i] || {};
            return row(i, a.ru || i, a.en || i, a.hintRu || "", a.hintEn || "", a.icon || "package", false, on);
        };
        let list = apps.map(i => app(i, true));
        if (fish)
            list.push(row("fish", "fish вместо bash", "fish instead of bash", "оболочка терминала как у автора: prompt pure, fastfetch, eza", "the terminal's shell as the author has it: the pure prompt, fastfetch, eza", "terminal", true, true));
        list = list.concat(packages.map(n => row("pkg:" + n, n, n, "системный пакет angelOS", "an angelOS system package", "package", true, true)));
        // a system that never picked: the author's other apps, shown unticked
        offer = list.concat(suggest.map(i => app(i, false)));
    }
    function install() {
        if (!running) {
            buildOffer();
            done = false;
            items = [];
            failed = [];
            auth = "";
            log = [];
        }
        open = true;
    }
    function toggle(id, on) {
        offer = offer.map(x => x.id !== id ? x : Object.assign({}, x, {
                "on": on
            }));
    }
    function start(ids) {
        if (running || !ids.length)
            return;
        running = true;
        done = false;
        failed = [];
        auth = "";
        log = [];
        sub = 0;
        status = I18n.t("начинаю…", "starting…");
        items = offer.filter(x => ids.includes(x.id)).map(x => Object.assign({}, x, {
                "state": "wait"
            }));
        // --take takes the rest of the line: last
        runner.command = ["python3", script, "sync", "--events", "--repo", Updates.repo || "", "--take"].concat(ids);
        runner.running = true;
    }
    // «Ещё раз»: only what didn't make it (everything, when the password was not given)
    function retry() {
        start(auth || !failed.length ? items.map(x => x.id) : failed);
    }
    function onEvent(e) {
        if (e.ev === "plan") {
            // what is there already never shows as waiting
            const there = e.items.filter(x => x.installed).map(x => x.id);
            items = items.map(x => there.includes(x.id) ? Object.assign({}, x, {
                    "state": "done"
                }) : x);
        } else if (e.ev === "auth") {
            status = I18n.t("введи пароль администратора", "enter the admin password");
        } else if (e.ev === "step") {
            status = e.text;
        } else if (e.ev === "item") {
            items = items.map(x => x.id !== e.id ? x : Object.assign({}, x, {
                    "state": e.state === "start" ? "run" : e.state
                }));
            sub = 0;
        } else if (e.ev === "done") {
            failed = (e.failed || []).concat(e.skipped || []);
            auth = e.auth || "";
            finished();
        }
    }
    function finished() {
        done = true;
        running = false;
        if (allDone) {
            // seen (the script acked): nothing left to offer
            apps = [];
            suggest = [];
            packages = [];
            fish = false;
            status = I18n.t("готово ♡", "done ♡");
        } else {
            status = auth ? auth : I18n.t("не всё поставилось", "not everything installed");
        }
        // closed while it ran: say how it ended; a failure comes back to be seen
        if (!open && !Shell.dev) {
            if (allDone)
                Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "system-software-install", I18n.t("Программы поставлены ♡", "Apps installed ♡"), items.map(x => I18n.t(x.ru, x.en)).join(", ")]);
            else
                open = true;
        }
    }
    // the window's ✕ / «Закрыть»: while it runs the install goes on; after a failure what was
    // shown counts as seen (as the terminal did); a password not given — offered again at login
    function close() {
        open = false;
        if (done && failed.length && !auth)
            skip();
    }
    function skip() {
        // a dev shell and the self-test write nothing into this system's state
        if (!Shell.dev)
            Quickshell.execDetached(["python3", script, "ack", "--repo", Updates.repo || ""]);
        apps = [];
        suggest = [];
        packages = [];
        fish = false;
        open = false;
    }
    // the UI self-test (tests/ui/Driver.qml): the window fed with what is new and events, no process
    function simulate(pending, evs) {
        apps = pending.apps || [];
        suggest = pending.suggest || [];
        packages = pending.packages || [];
        fish = !!pending.fish;
        running = false;
        install();
        if (!evs)
            return;
        running = true;
        items = offer.filter(x => x.on).map(x => Object.assign({}, x, {
                "state": "wait"
            }));
        for (const e of evs)
            onEvent(e);
    }
    function ipc(line) {
        const cmd = String(line || "").trim().split(/\s+/)[0] || "open";
        if (cmd === "status")
            return JSON.stringify({
                "apps": apps,
                "suggest": suggest,
                "packages": packages,
                "fish": fish,
                "open": open,
                "running": running,
                "done": done,
                "failed": failed,
                "status": status
            });
        if (cmd === "check") {
            _told = "";
            check();
            return "checking";
        }
        if (cmd === "open") {
            if (!count && !running && !done)
                return "nothing new: everything is as the author has it";
            install();
            return "open";
        }
        if (cmd === "skip") {
            skip();
            return "ok";
        }
        return "angelos apps [open] | status | check | skip — the author's new apps after an update";
    }

    Process {
        id: runner
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("EV ")) {
                    try {
                        root.onEvent(JSON.parse(line.slice(3)));
                    } catch (e) {}
                    return;
                }
                // eslint-disable-next-line no-control-regex
                const clean = line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/\r/g, "").trim();
                if (!clean)
                    return;
                root.log = root.log.concat([clean]).slice(-120);
                if (root.running && !clean.startsWith("»"))
                    root.status = clean;
                const part = Shell.stepOf(clean, root.sub);
                if (part >= 0)
                    root.sub = part;
            }
        }
        // gone without its last word (killed, a crash): what isn't done didn't make it
        onExited: (code, status) => {
            if (root.running) {
                root.failed = root.items.filter(x => x.state !== "done").map(x => x.id);
                root.finished();
            }
        }
    }

    FileView {
        path: Quickshell.shellDir + "/data/apps-catalog.json"
        printErrors: false
        onLoaded: {
            try {
                const names = {}, cat = {};
                for (const a of JSON.parse(text()).apps) {
                    names[a.id] = I18n.t(a.ru, a.en);
                    cat[a.id] = a;
                }
                root._names = names;
                root._cat = cat;
            } catch (e) {}
        }
    }
    Process {
        id: probe
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    root.apps = p.apps || [];
                    root.suggest = p.suggest || [];
                    root.packages = p.packages || [];
                    root.fish = !!p.fish;
                } catch (e) {
                    return;
                }
                root.tell();
            }
        }
    }
    function tell() {
        const key = apps.concat(suggest, packages).join(",") + (fish ? ",fish" : "");
        if (count === 0 || key === _told)
            return;
        _told = key;
        const list = (fish ? [I18n.t("fish вместо bash", "fish instead of bash")] : []).concat(apps.concat(suggest).map(i => _names[i] || i), packages);
        const shown = list.slice(0, 6).join(", ") + (list.length > 6 ? I18n.t(" и ещё ", " and ") + (list.length - 6) : "");
        notifier.command = ["notify-send", "-a", "angelOS", "-i", "system-software-install", "--wait", "-A", "install=" + I18n.t("Поставить", "Install"), "-A", "skip=" + I18n.t("Не надо", "No, thanks"), I18n.t("Как у автора angelOS", "As angelOS's author has it"), shown + I18n.t(" — как у автора. Поставить? (всё отмечено — сними лишнее; пароль спросят один раз)", " — as the author has them. Install? (all ticked: untick what you don't want; the password is asked once)")];
        notifier.running = true;
    }
    Process {
        id: notifier
        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.trim();
                if (a === "install")
                    root.install();
                else if (a === "skip")
                    root.skip();
            }
        }
    }
    // Spotify in the author's look (spicetify): again after each Spotify update, quietly
    Process {
        id: spicetify
        command: ["bash", Quickshell.shellDir + "/scripts/spicetify-apply.sh"]
    }
    // once per login, after the desktop has settled (and the intro is over)
    Timer {
        interval: 4 * 60 * 1000
        running: Config.ready
        onTriggered: {
            root.check();
            if (!Shell.dev && !Owner.hasDir)
                spicetify.running = true;
        }
    }
}
