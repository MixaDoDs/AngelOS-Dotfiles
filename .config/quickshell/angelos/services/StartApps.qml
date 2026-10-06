pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Apps for the Start menu styles: search, pinned, frequent, launching.
Singleton {
    id: root

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => String(a.name).localeCompare(String(b.name)))
    readonly property var usage: Config.launcher.usage || {}
    readonly property var frequent: apps.filter(a => (usage[a.id] || 0) > 0).sort((a, b) => (usage[b.id] || 0) - (usage[a.id] || 0))
    // pinned by hand first, topped up with the most used apps
    readonly property var pinned: {
        const ids = Config.bar.startPinned || [];
        const list = ids.map(id => apps.find(a => a.id === id)).filter(a => !!a);
        for (const a of frequent) {
            if (list.length >= 18)
                break;
            if (!list.includes(a))
                list.push(a);
        }
        for (const a of apps) {
            if (list.length >= 12)
                break;
            if (!list.includes(a))
                list.push(a);
        }
        return list;
    }

    function isPinned(app) {
        return (Config.bar.startPinned || []).includes(app.id);
    }
    function togglePin(app) {
        const ids = (Config.bar.startPinned || []).slice();
        const i = ids.indexOf(app.id);
        if (i >= 0)
            ids.splice(i, 1);
        else
            ids.push(app.id);
        Config.bar.startPinned = ids;
    }
    function score(app, q) {
        const name = (app.name || "").toLowerCase();
        if (!q)
            return 1;
        if (name.startsWith(q))
            return 100 - name.length / 10;
        if (name.includes(q))
            return 70 - name.indexOf(q);
        const extra = ((app.genericName || "") + " " + String(app.keywords || "") + " " + (app.id || "")).toLowerCase();
        if (extra.includes(q))
            return 40;
        let i = 0;
        for (const ch of name)
            if (ch === q[i])
                i++;
        return i === q.length ? 20 - name.length / 20 : -1;
    }
    function search(text) {
        const q = String(text || "").trim().toLowerCase();
        if (!q)
            return apps;
        return apps.map(a => ({
                    "a": a,
                    "s": score(a, q) + Math.min(30, (usage[a.id] || 0) * 2)
                })).filter(r => r.s > 0).sort((x, y) => y.s - x.s).map(r => r.a);
    }
    // Start's search (and the launcher): the calculator first, then apps and settings
    // mixed by relevance. Scores are brought to 0…1: an app whose name starts with the
    // text ≈ 1, a setting named exactly so ≈ 0.95, a word in a description ≈ 0.2.
    // Rows: {kind: "calc", calc} · {kind: "app", app} · {kind: "setting", doc} · {kind: "file",
    // file} (FileSearch: arrives a moment later, the binding re-reads), each with s.
    function searchAll(text, limit) {
        const q = String(text || "").trim();
        if (!q)
            return [];
        const rows = [];
        const calc = Calc.evaluate(q);
        if (calc)
            rows.push({
                "kind": "calc",
                "calc": calc,
                "s": 2
            });
        const ql = q.toLowerCase();
        for (const a of apps) {
            const sc = score(a, ql);
            if (sc <= 0)
                continue;
            const norm = sc >= 90 ? 1 - Math.min(0.04, String(a.name || "").length / 1000) : sc >= 50 ? 0.8 : sc >= 40 ? 0.55 : 0.3;
            rows.push({
                "kind": "app",
                "app": a,
                "s": norm + Math.min(0.08, (usage[a.id] || 0) * 0.005)
            });
        }
        // a sum is not a question about settings ("2*3" would match "Size")
        if (Config.launcher.settings !== false && !calc) {
            SettingsSearch.load();
            for (const r of SettingsSearch.search(q, 8))
                rows.push({
                    "kind": "setting",
                    "doc": r,
                    "s": Math.min(0.95, r.score / 6.3)
                });
        }
        // files by name or type (FileSearch): a few among the rest, all of them for ".jpeg"
        if (!calc)
            for (const f of FileSearch.rows(q, /^(\.\S+\s*)+$/.test(q) ? 30 : 8))
                rows.push({
                    "kind": "file",
                    "file": f,
                    "s": f.s
                });
        rows.sort((x, y) => y.s - x.s);
        return rows.slice(0, limit || 40);
    }
    function openFile(f) {
        FileSearch.open(f);
    }
    // open settings at a found page / group / row and flash it
    function openSetting(doc) {
        Shell.openSettings(doc.kind === "page" ? doc.page : "");
        if (doc.kind !== "page")
            Qt.callLater(() => {
                if (Shell.settingsView)
                    Shell.settingsView.openResult(doc);
            });
    }

    function launch(app) {
        if (!app)
            return;
        const u = Object.assign({}, Config.launcher.usage || {});
        u[app.id] = (u[app.id] || 0) + 1;
        Config.launcher.usage = u;
        if (app.runInTerminal)
            Shell.exec(Shell.terminalArgv(app.command), app.workingDirectory, app.id);
        else if (app.command && app.command.length)
            Shell.exec(app.command, app.workingDirectory, app.id);
        else
            app.execute();      // no command line to run with the apps' environment
    }
    readonly property string userName: Quickshell.env("USER") || "angel"
}
