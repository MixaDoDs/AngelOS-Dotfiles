pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.settings

// The settings search against a table of queries (tests/search/table.json, started by
// tests/search/run.sh). A row: {"q": query, "want": [what must be found], "top": N (how far down,
// default 2), "owner": true|false (only for / only not for the author), "not": [what must not be]}.
// What is found reads "page", "page/Title" or "page/Group/Row" — a result matches when its page
// is the page and its title (and a row's group) contain the rest, case aside.
// ANGELOS_SEARCH_DUMP=file: print the first results of every line of the file instead.
Scope {
    id: root

    readonly property string dump: Quickshell.env("ANGELOS_SEARCH_DUMP") || ""
    readonly property string table: Quickshell.env("ANGELOS_SEARCH_TABLE") || ""
    property double started: Date.now()

    FloatingWindow {
        id: win
        implicitWidth: 1000
        implicitHeight: 700
        title: "angelOS search test"
        SettingsView {
            anchors.fill: parent
            hostWindow: win
        }
    }
    FileView {
        id: input
        path: root.dump || root.table
        blockLoading: true
    }
    function label(r) {
        return r.page + "/" + (r.kind === "row" && r.crumb.includes(" › ") ? r.crumb.split(" › ").slice(-1)[0] + "/" : "") + r.title + (r.kind === "page" ? " [page]" : "");
    }
    // the page a row of the table names, as the tree has it now: an old id leads where Settings
    // send it (SettingsTree.resolve: tree.json "legacy", a page file's groups on another page), so
    // a page renamed or merged doesn't break the table (21.10: lab → developer, lens → a11y)
    function pageOf(id) {
        const r = SettingsTree.resolve(id);
        return r && r.page ? r.page : id;
    }
    function matches(r, want) {
        const parts = want.toLowerCase().split("/");
        if (r.page !== parts[0] && r.page !== pageOf(parts[0]))
            return false;
        const hay = (r.crumb + " › " + r.title).toLowerCase().replace(/ё/g, "е");
        return parts.slice(1).every(p => hay.includes(p.replace(/ё/g, "е")));
    }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            // the owner's debug core (if any) loads a moment after the start
            if (!SettingsSearch.loaded || SettingsSearch.settling || !SettingsSearch.docs.length || Date.now() - root.started < 3000) {
                SettingsSearch.load();
                if (Date.now() - root.started < 60000)
                    return;
            }
            stop();
            if (root.dump) {
                // "@docs": every entry the search knows, with its description
                if (String(input.text()).trim() === "@docs")
                    for (const d of SettingsSearch.docs)
                        console.log("DUMP " + d.kind + "\t" + root.label(d) + "\t" + d.hint);
                for (const q of String(input.text()).split("\n").filter(s => s.trim() && s.trim() !== "@docs"))
                    console.log("DUMP " + q + "  ⇒  " + SettingsSearch.search(q, 12).map(r => root.label(r)).join("  |  "));
                console.log("TEST DONE 0");
                Qt.quit();
                return;
            }
            let rows = [];
            try {
                rows = JSON.parse(input.text()).rows;
            } catch (e) {
                console.log("TEST table FAIL " + e);
            }
            let fails = 0, worst = 0, total = 0;
            // the author: his debug panel is in the index and open to him (owner/debug, task 04)
            const author = GameDebug.allowed && SettingsSearch.entries.some(e => e.owner);
            for (const row of rows) {
                if (row.owner === true && !author || row.owner === false && author)
                    continue;
                // the time: the best of three fresh keys (a busy machine's one slice is no slow search)
                let ms = Infinity, res = [];
                for (const pad of [" ", "  ", "   "]) {
                    const t0 = Date.now();
                    res = SettingsSearch.search(row.q + pad, 30);
                    ms = Math.min(ms, Date.now() - t0);
                }
                worst = Math.max(worst, ms);
                total += ms;
                const top = row.top || 2;
                const missing = (row.want || []).filter(w => !res.slice(0, top).some(r => root.matches(r, w)));
                const extra = (row.not || []).filter(w => res.some(r => root.matches(r, w)));
                const ok = missing.length === 0 && extra.length === 0;
                if (!ok)
                    fails++;
                console.log("TEST q:" + row.q.replace(/ /g, "_") + " " + (ok ? "PASS" : "FAIL") + (ok ? "" : (missing.length ? " not in the first " + top + ": " + missing.join(", ") : "") + (extra.length ? " must not be there: " + extra.join(", ") : "") + " — got " + res.slice(0, Math.max(top, 4)).map(r => root.label(r)).join(" | ")));
            }
            console.log("TEST search-time " + (worst <= 60 ? "PASS" : "FAIL") + " " + rows.length + " queries, avg " + (total / Math.max(1, rows.length)).toFixed(1) + " ms, worst " + worst + " ms");
            root.fails = fails;
            switches.start();
        }
    }
    // A language and a skin switch rebuild the index once each, a beat later — not once per
    // step of the switch, right inside it: 4–9 rebuilds in a row froze the shell for seconds,
    // on a laptop past the guard's 15 s, which aborted it and the switch was lost (#57, #64)
    property int fails: 0
    property int rebuilds: 0
    property var switchReport: []
    Connections {
        target: SettingsSearch
        function onIndexChanged() {
            root.rebuilds++;
        }
    }
    Timer {
        id: switches
        interval: 1500
        repeat: true
        property int step: 0
        readonly property var plan: [["language", () => Config.appearance.language = "en"], ["skin", () => Config.settingsUi.skin = "goldengate"], ["language back", () => Config.appearance.language = "ru"], ["skin back", () => Config.settingsUi.skin = "classic"]]
        onTriggered: {
            if (step > 0) {
                const [name, , ms] = plan[step - 1].concat([root.switchReport[step - 1]]);
                const ok = root.rebuilds <= 1 && SettingsSearch.docs.length > 0;
                if (!ok)
                    root.fails++;
                console.log("TEST switch:" + name.replace(/ /g, "_") + " " + (ok ? "PASS" : "FAIL") + " " + root.rebuilds + " index rebuilds, the switch itself " + ms + " ms");
            }
            if (step >= plan.length) {
                stop();
                console.log("TEST DONE " + root.fails);
                Qt.quit();
                return;
            }
            root.rebuilds = 0;
            const t0 = Date.now();
            plan[step][1]();
            root.switchReport.push(Date.now() - t0);
            step++;
        }
    }
}
