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
    // a Start tile's right-click menu, in every look: pinning first (the middle button's quick
    // action), then `open`, the look's own launch (it closes Start)
    function menuFor(app, open) {
        return [
            {
                "label": isPinned(app) ? I18n.t("Открепить", "Unpin") : I18n.t("Закрепить", "Pin"),
                "icon": "pin",
                "run": () => togglePin(app)
            },
            {
                "label": I18n.t("Открыть", "Open"),
                "icon": "play",
                "run": open
            }
        ];
    }
    // a found file's: its folder first (the middle button's), then the file itself
    function fileMenuFor(reveal, open) {
        return [
            {
                "label": I18n.t("Показать в папке", "Show in folder"),
                "icon": "folder",
                "run": reveal
            },
            {
                "label": I18n.t("Открыть", "Open"),
                "icon": "document",
                "run": open
            }
        ];
    }
    // apps only, best first (the full-screen look's grid)
    function search(text) {
        if (!String(text || "").trim())
            return apps;
        return Search.query(text, 200, {
            "settings": false,
            "files": 0
        }).filter(r => !!r.app).map(r => r.app);
    }
    // Start's search: services/Search, the one the launcher and Spotlight use
    function searchAll(text, limit) {
        return Search.query(text, limit);
    }
    function openFile(f) {
        FileSearch.open(f);
    }
    // open settings at a found page / group / row and flash it
    function openSetting(doc) {
        Search.chosen("set:" + doc.page + "|" + doc.title);
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
        Search.chosen("app:" + app.id);
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
