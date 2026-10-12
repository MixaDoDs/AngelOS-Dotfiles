pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Installed programs (Settings → Apps → Programs, `angelos programs`): what is there, removing
// one — planned first (what goes along, what refuses), then done with one admin password
// (scripts/programs.py remove --events → pkexec, pacman only) — and the clean-up: packages
// nothing needs any more, pacman's download cache, Flatpak's unused runtimes.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/programs.py"
    property var apps: []           // [{item, names, icon, source, pkg, size, keep, needed, catalog}]
    property bool loaded: false
    property bool loading: false
    property var cleanup: null      // {orphans: [{name, size}], orphansSize, cache, cacheFiles, flatpak}
    // «Лишнее» (data/bloat.json, programs.py bloat-status): [{id, title, hint, ticked, items:
    // [{item, pkg, name, note, size, locked, catalog}]}] and what is ticked now
    property var bloat: null
    property var bloatPicked: []
    property real progress: 0       // the job's 0…1 (its EV item n/of)

    // one job at a time: a removal asked for (planned, waiting for «Удалить»), or running, or done
    property var asked: []          // the rows it is about
    property var plan: null         // {remove: [{name, size}], size, refused}
    property string kind: ""        // "remove" | "cleanup" | "bloat"
    property bool planning: false
    property bool running: false
    property bool done: false
    property var failed: []
    property string refused: ""
    property var skipped: []        // [{id, why}]: left out (something else needs it)
    property string auth: ""        // why it never started (the password was not given…)
    property string status: ""
    property var log: []
    readonly property bool busy: planning || running

    function fmt(bytes) {
        const b = Number(bytes) || 0;
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1).replace(".", I18n.english ? "." : ",") + I18n.t(" ГБ", " GB");
        if (b >= 1048576)
            return Math.round(b / 1048576) + I18n.t(" МБ", " MB");
        if (b > 0)
            return Math.max(1, Math.round(b / 1024)) + I18n.t(" КБ", " KB");
        return "";
    }
    function label(row) {
        return row.names.slice(0, 3).join(", ") + (row.names.length > 3 ? "…" : "");
    }
    // why a row can't be removed ("" = it can)
    function why(row) {
        if (row.keep)
            return row.keep;
        if (row.needed && row.needed.length)
            return I18n.t("нужна для: ", "needed by: ") + row.needed.slice(0, 3).join(", ") + (row.needed.length > 3 ? "…" : "");
        return "";
    }

    function refresh() {
        if (lister.running)
            return;
        loading = true;
        lister.running = true;
    }
    function refreshCleanup() {
        if (!cleaner.running)
            cleaner.running = true;
    }
    function refreshBloat() {
        if (!bloater.running)
            bloater.running = true;
    }
    function bloatTick(item, on) {
        const now = bloatPicked.filter(i => i !== item);
        bloatPicked = on ? now.concat([item]) : now;
    }
    function bloatSize() {
        let s = 0;
        for (const g of bloat ? bloat.groups : [])
            for (const i of g.items)
                if (bloatPicked.includes(i.item))
                    s += i.size;
        return s;
    }
    // «Удалить отмеченное»: one pacman transaction, one password, a bar for how far it is
    function removeBloat() {
        if (busy || !bloatPicked.length)
            return;
        reset();
        kind = "bloat";
        start(["bloat", "--events"].concat(bloatPicked));
    }
    function reset() {
        progress = 0;
        skipped = [];
        asked = [];
        plan = null;
        kind = "";
        done = false;
        failed = [];
        refused = "";
        auth = "";
        status = "";
        log = [];
    }
    // «Удалить» on a row: nothing goes yet — first what would really go
    function ask(row) {
        if (busy)
            return;
        reset();
        kind = "remove";
        asked = [row];
        planning = true;
        planner.command = ["python3", script, "plan", "--repo", Updates.repo || ""].concat([row.item]);
        planner.running = true;
    }
    function cancel() {
        if (!running)
            reset();
    }
    function confirm() {
        if (busy || kind !== "remove" || !plan || plan.refused || !asked.length)
            return;
        start(["remove", "--events", "--repo", Updates.repo || ""].concat(asked.map(r => r.item)));
    }
    function clean(what) {
        if (busy || !what.length)
            return;
        reset();
        kind = "cleanup";
        start(["cleanup", "--events"].concat(what));
    }
    function start(args) {
        running = true;
        done = false;
        status = I18n.t("начинаю…", "starting…");
        runner.command = ["python3", script].concat(args);
        runner.running = true;
    }
    function onEvent(e) {
        if (e.ev === "item" && e.of > 0) {
            progress = Math.max(progress, Math.min(1, (e.n + (e.state === "start" ? 0.5 : 0)) / e.of));
            if (e.state === "start")
                status = I18n.t("удаляю ", "removing ") + String(e.id).replace(/^[^:]*:/, "");
        }
        if (e.ev === "plan" && e.skipped)
            skipped = e.skipped;
        if (e.ev === "auth") {
            status = I18n.t("введи пароль администратора", "enter the admin password");
        } else if (e.ev === "step") {
            status = e.text;
        } else if (e.ev === "done") {
            progress = 1;
            failed = e.failed || [];
            skipped = e.skipped || [];
            auth = e.auth || "";
            refused = e.refused || "";
            finished();
        }
    }
    function finished() {
        running = false;
        done = true;
        status = auth ? auth : refused ? refused : failed.length ? I18n.t("не всё получилось — причина в строчках ниже", "not everything worked: the lines below say why") : I18n.t("готово ♡", "done ♡");
        // what is there now, read again
        if (!Shell.dev) {
            refresh();
            refreshCleanup();
            if (kind === "bloat") {
                bloatPicked = [];
                bloat = null;
                refreshBloat();
            }
        }
    }
    // the UI self-test (tests/ui/Driver.qml): rows and events fed in, no process
    function simulate(rows, planned, evs) {
        reset();
        apps = rows;
        loaded = true;
        if (!planned)
            return;
        kind = "remove";
        asked = [rows[0]];
        plan = planned;
        if (!evs)
            return;
        running = true;
        for (const e of evs)
            onEvent(e);
    }

    Process {
        id: lister
        command: ["python3", root.script, "list", "--repo", Updates.repo || ""]
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apps = JSON.parse(text).apps || [];
                    root.loaded = true;
                } catch (e) {}
                root.loading = false;
            }
        }
    }
    Process {
        id: cleaner
        command: ["python3", root.script, "cleanup-status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.cleanup = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    Process {
        id: bloater
        command: ["python3", root.script, "bloat-status"]
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const st = JSON.parse(text);
                    const first = root.bloat === null;
                    root.bloat = st;
                    // the first look: the groups' preselection (what can go)
                    if (first && !root.bloatPicked.length) {
                        let pick = [];
                        for (const g of st.groups)
                            if (g.ticked)
                                pick = pick.concat(g.items.filter(i => !i.locked).map(i => i.item));
                        root.bloatPicked = pick;
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: planner
        environment: ({
                "ANGELOS_LANG": I18n.english ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                root.planning = false;
                try {
                    root.plan = JSON.parse(text);
                } catch (e) {
                    root.plan = {
                        "remove": [],
                        "size": 0,
                        "refused": I18n.t("не удалось узнать, что удалится", "couldn't work out what would go")
                    };
                }
            }
        }
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
                root.log = root.log.concat([clean]).slice(-80);
                if (root.running && !clean.startsWith("»"))
                    root.status = clean;
            }
        }
        // gone without its last word (killed, a crash)
        onExited: (code, status) => {
            if (root.running) {
                root.failed = root.asked.map(r => r.item);
                root.finished();
            }
        }
    }
}
