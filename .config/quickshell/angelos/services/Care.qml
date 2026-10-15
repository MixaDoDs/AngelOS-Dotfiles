pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// «Обслуживание» (Device Care, scripts/care.py): one button that looks the computer over —
// space, memory, failed services, .pacnew, errors, the disks' SMART — and cleans what is safe:
// old caches that fill themselves again, temporary leftovers, angelOS's backups (archived),
// the package cache, orphans; one admin password for all the root parts. First a scan shows
// what would go and how much it frees (nothing changes), then "Start" cleans the ticked ones.
// Settings → System → Maintenance, the Start menu, `angelos care`.
Singleton {
    id: root

    property var report: null               // scan: {items, checks, score, reclaim}
    property bool scanning: scanner.running
    property bool running: cleaner.running
    property var picked: ({})               // id → bool (by default: the item's own default)
    property var progress: ({})             // id → {state, freed}
    property var extraChecks: []            // what the run found (SMART)
    property real freed: 0
    property string authError: ""
    property bool finished: false
    property double lastScan: 0

    readonly property var items: report ? report.items : []
    readonly property var checks: (report ? report.checks : []).concat(extraChecks)
    readonly property int score: report ? report.score : 0
    readonly property real chosenBytes: items.filter(i => isPicked(i.id)).reduce((s, i) => s + i.bytes, 0)
    readonly property bool needsRoot: items.some(i => isPicked(i.id) && i.root)

    function isPicked(id) {
        if (picked[id] !== undefined)
            return picked[id];
        const it = items.find(i => i.id === id);
        return !!it && it.default && (it.bytes > 0 || it.id === "smart" || it.id === "flatpak");
    }
    function pick(id, on) {
        const p = Object.assign({}, picked);
        p[id] = on;
        picked = p;
    }
    function scan() {
        if (scanner.running || cleaner.running)
            return;
        finished = false;
        scanner.running = true;
    }
    function start() {
        const ids = items.filter(i => isPicked(i.id)).map(i => i.id);
        if (!ids.length || cleaner.running)
            return;
        progress = {};
        extraChecks = [];
        freed = 0;
        authError = "";
        finished = false;
        cleaner.command = ["python3", Quickshell.shellPath("scripts/care.py"), "run"].concat(ids);
        cleaner.running = true;
    }
    // the button everywhere else: open the page and look at once
    function open() {
        Shell.openSettings("care");
        if (!report || Date.now() - lastScan > 60000)
            scan();
    }
    function size(n) {
        if (!n || n < 0)
            return "0 " + I18n.t("Б", "B");
        if (n < 1024)
            return Math.round(n) + " " + I18n.t("Б", "B");
        const u = I18n.t(["КБ", "МБ", "ГБ", "ТБ"], ["KB", "MB", "GB", "TB"]);
        let i = -1;
        do {
            n /= 1024;
            i++;
        } while (n >= 1024 && i < 3)
        return (n < 10 ? n.toFixed(1) : Math.round(n)) + " " + u[i];
    }

    Process {
        id: scanner
        command: ["python3", Quickshell.shellPath("scripts/care.py"), "scan"]
        environment: ({
                "ANGELOS_LANG": Config.appearance.language === "en" ? "en" : "ru"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.report = JSON.parse(text);
                    root.lastScan = Date.now();
                } catch (e) {}
            }
        }
    }
    Process {
        id: cleaner
        environment: ({
                "ANGELOS_LANG": Config.appearance.language === "en" ? "en" : "ru"
            })
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("EV "))
                    return;
                let ev;
                try {
                    ev = JSON.parse(line.slice(3));
                } catch (e) {
                    return;
                }
                if (ev.ev === "item") {
                    const p = Object.assign({}, root.progress);
                    p[ev.id] = {
                        "state": ev.state,
                        "freed": ev.freed || 0
                    };
                    root.progress = p;
                } else if (ev.ev === "check") {
                    root.extraChecks = root.extraChecks.concat([ev]);
                } else if (ev.ev === "done") {
                    root.freed = ev.freed || 0;
                    root.authError = ev.auth || "";
                }
            }
        }
        onExited: {
            root.finished = true;
            if (!root.authError)
                Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "applications-utilities", I18n.t("Обслуживание закончено", "Maintenance done"), I18n.t("Освобождено ", "Freed ") + root.size(root.freed)]);
            // the numbers after: a fresh look, the picks back to the defaults
            root.picked = {};
            rescan.restart();
        }
    }
    Timer {
        id: rescan
        interval: 800
        onTriggered: scanner.running = true
    }
}
