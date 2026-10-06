pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Community Plugins: angelOS's one catalog of plugins (Settings → Plugins, the launcher's
// "plugins …"). The approved entries of the official registry next to what is installed —
// bundled, from the community, your own — with install, update, rollback (scripts/
// community-plugins.py). Part of angelOS, not a plugin: always there, nothing to remove.
//
// Updates: checked once a day (Config.plugins.autoCheck), a notification says which ones are
// there and updates them on a click. Before an update the installed copy becomes a snapshot;
// the new files are compiled right away through a fresh load path, and a plugin that does not
// load goes back to the snapshot by itself.
// Lives with the shell, not the Settings page: closing Settings cannot cancel an install
// halfway through replacing a plugin.
Singleton {
    id: root

    property var entries: []
    property string error: ""
    property string message: ""            // the last result, in words
    property string action: ""             // fetch | install | update | rollback
    property string busyId: ""
    property var queue: []                 // entries still to update ("update all")
    property var failed: []                // ids whose last update was rolled back
    readonly property bool busy: fetcher.running || installer.running || reverter.running || queue.length > 0
    readonly property bool live: Config.ready && !Shell.dev && Quickshell.env("ANGELOS_TEST") !== "1"
    readonly property string script: Quickshell.shellDir + "/scripts/community-plugins.py"
    signal finished(string id, bool ok)

    // ---- what the page shows ----
    function entry(id) {
        return entries.find(e => e.id === id) || null;
    }
    // installed, or a bundled one hidden by hand (it can come back, not be installed again)
    function installed(id) {
        return Plugins.byId(id) || Plugins.removed.find(p => p.id === id && p.bundled) || null;
    }
    function newer(oldVersion, newVersion) {
        const a = String(oldVersion || "0").split(".").map(Number);
        const b = String(newVersion || "0").split(".").map(Number);
        for (let i = 0; i < Math.max(a.length, b.length); ++i) {
            const x = Number.isFinite(a[i]) ? a[i] : 0;
            const y = Number.isFinite(b[i]) ? b[i] : 0;
            if (x !== y)
                return y > x;
        }
        return false;
    }
    function canUpdate(id) {
        const p = Plugins.byId(id);
        const e = entry(id);
        return !!p && !!e && newer(p.version, e.version);
    }
    readonly property var updates: entries.filter(e => canUpdate(e.id))
    // where a plugin came from: bundled with angelOS, the community catalog, or yours (Studio, by hand)
    function origin(p) {
        if (!p)
            return "";
        if (p.bundled)
            return "bundled";
        return entry(p.id) ? "community" : "own";
    }

    // ---- the registry ----
    property bool _quiet: false             // the daily check: no error on the page for it
    function refresh(quiet) {
        if (fetcher.running || installer.running)
            return;
        _quiet = !!quiet;
        if (!_quiet) {
            error = "";
            action = "fetch";
        }
        fetcher.running = true;
    }

    // ---- install, update ----
    function install(e) {
        Achievements.note("plugin.install");
        if (!e || busy)
            return;
        _start(e, undefined);
    }
    function update(id) {
        const p = Plugins.byId(id), e = entry(id);
        if (!p || !e || busy)
            return;
        _start(e, String(p.version || "0"));
    }
    function updateAll() {
        if (busy || !updates.length)
            return;
        queue = updates.slice(1);
        _start(updates[0], String(Plugins.byId(updates[0].id).version || "0"));
    }
    function rollback(id) {
        if (busy)
            return;
        error = "";
        action = "rollback";
        busyId = id;
        reverter.command = ["python3", script, "rollback", id];
        reverter.running = true;
    }
    function _start(e, oldVersion) {
        error = "";
        message = "";
        busyId = e.id;
        action = oldVersion === undefined ? "install" : "update";
        installer.command = ["python3", script, oldVersion === undefined ? "install" : "update", e.id, e.version].concat(oldVersion === undefined ? [] : [oldVersion]);
        installer.running = true;
    }
    function _next() {
        if (!queue.length)
            return;
        const e = queue[0];
        queue = queue.slice(1);
        const p = Plugins.byId(e.id);
        if (p && newer(p.version, e.version))
            _start(e, String(p.version || "0"));
        else
            Qt.callLater(_next);
    }

    // ---- does the new version load? ----
    // every QML file the manifest names is compiled from the fresh load path; an error there
    // (a missing import, a typo, a component that is gone) means the update is taken back
    function check(id, dir) {
        const p = Plugins.byId(id);
        if (!p)
            return I18n.t("плагин не нашёлся после установки", "the plugin was not found after installing");
        const files = ["main", "settings", "barWidget", "desktopWidget", "sidebarWidget", "launcher", "menuComponent"].map(k => p[k]).filter(f => typeof f === "string" && f.endsWith(".qml"));
        for (const f of files) {
            const c = Qt.createComponent("file://" + dir + "/" + f, Component.PreferSynchronous);
            if (c.status === Component.Error)
                return f + ": " + c.errorString().trim().split("\n")[0];
            if (c.status === Component.Ready)
                c.destroy();
        }
        return "";
    }
    property var _verify: null              // {id, version, loadDir, update} waiting for the rescan
    Connections {
        target: Plugins
        function onScanningChanged() {
            if (Plugins.scanning || !root._verify)
                return;
            const v = root._verify;
            root._verify = null;
            const why = root.check(v.id, v.loadDir);
            if (!why) {
                Plugins.setLoadDir(v.id, v.loadDir);
                root.failed = root.failed.filter(x => x !== v.id);
                root.message = (v.update ? I18n.t("Обновлён: ", "Updated: ") : I18n.t("Установлен: ", "Installed: ")) + root._name(v.id) + " v" + v.version;
                root.finished(v.id, true);
                Qt.callLater(root._next);
                return;
            }
            console.warn("angelOS community plugins:", v.id, "does not load:", why);
            root.error = root._name(v.id) + " v" + v.version + I18n.t(" не загрузился: ", " does not load: ") + why;
            if (v.update) {
                root.failed = root.failed.concat([v.id]);
                root.rollback(v.id);
            } else {
                // a fresh install that does not load: off, the files stay for a look
                Plugins.setEnabled(v.id, false);
                root.finished(v.id, false);
                Qt.callLater(root._next);
            }
        }
    }
    function _name(id) {
        const p = Plugins.byId(id) || entry(id);
        return p ? I18n.label(p.name) : id;
    }

    Process {
        id: fetcher
        command: ["python3", root.script, "list"]
        stdout: StdioCollector {
            id: fetchOut
        }
        stderr: StdioCollector {
            id: fetchErr
        }
        onExited: code => {
            if (!root._quiet)
                root.action = "";
            if (code !== 0) {
                if (!root._quiet)
                    root.error = fetchErr.text.trim() || I18n.t("Каталог не загрузился", "Could not load the community catalog");
                return;
            }
            try {
                const payload = JSON.parse(fetchOut.text);
                if (!Array.isArray(payload.plugins))
                    throw new Error("Invalid catalog response");
                root.entries = payload.plugins.filter(p => p && p.status === "approved");
                if (!root._quiet)
                    root.error = "";
                Config.plugins.lastCheck = new Date().toISOString();
                root.maybeNotify();
            } catch (e) {
                if (!root._quiet)
                    root.error = String(e);
            }
        }
    }
    Process {
        id: installer
        stdout: StdioCollector {
            id: installOut
        }
        stderr: StdioCollector {
            id: installErr
        }
        onExited: code => {
            root.action = "";
            const id = root.busyId;
            if (code !== 0) {
                root.error = root._name(id) + ": " + (installErr.text.trim() || I18n.t("не установился", "could not be installed"));
                root.finished(id, false);
                Qt.callLater(root._next);
                return;
            }
            try {
                const r = JSON.parse(installOut.text);
                root._verify = {
                    "id": r.id,
                    "version": r.version,
                    "loadDir": r.loadDir,
                    "update": !!r.updated
                };
                Plugins.reload();
            } catch (e) {
                root.error = String(e);
                Qt.callLater(root._next);
            }
        }
    }
    Process {
        id: reverter
        stdout: StdioCollector {
            id: revertOut
        }
        stderr: StdioCollector {
            id: revertErr
        }
        onExited: code => {
            root.action = "";
            const id = root.busyId;
            if (code !== 0) {
                root.error = (root.error ? root.error + "\n" : "") + I18n.t("Откат не удался: ", "Rollback failed: ") + revertErr.text.trim();
                root.finished(id, false);
                return;
            }
            try {
                const r = JSON.parse(revertOut.text);
                Plugins.setLoadDir(r.id, r.loadDir);
                root.message = I18n.t("Вернул прежнюю версию: ", "Back to the earlier version: ") + root._name(r.id) + (r.version ? " v" + r.version : "");
                if (root.failed.includes(r.id))
                    Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-warning", I18n.t("Обновление плагина откатилось", "A plugin update was rolled back"), root.error]);
            } catch (e) {
                root.error = String(e);
            }
            root.finished(id, false);
            Qt.callLater(root._next);
        }
    }

    // ---- once a day: is there anything new? ----
    function maybeNotify() {
        const ids = updates.map(e => e.id + "@" + e.version).sort().join(",");
        if (!ids || ids === Config.plugins.notifiedFor || !live)
            return;
        Config.plugins.notifiedFor = ids;
        const names = updates.map(e => _name(e.id) + " " + e.version).join(", ");
        notifier.command = ["notify-send", "-a", "angelOS", "-i", "system-software-update", "--wait", "-A", "update=" + I18n.t("Обновить", "Update"), "-A", "open=" + I18n.t("Подробнее", "Details"), I18n.t("Обновления плагинов: ", "Plugin updates: ") + updates.length, names];
        notifier.running = true;
    }
    Process {
        id: notifier
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "update")
                    root.updateAll();
                else if (line.trim() === "open")
                    Shell.openSettings("plugins");
            }
        }
    }
    Timer {
        interval: 2 * 60 * 1000
        running: root.live && Config.plugins.autoCheck
        repeat: true
        onTriggered: {
            interval = 3 * 3600 * 1000;
            const last = Date.parse(Config.plugins.lastCheck || "") || 0;
            if (Date.now() - last > 22 * 3600 * 1000)
                root.refresh(true);
        }
    }

    // ---- once: the old stand-alone Community Store plugin steps aside ----
    // its catalog, updates and launcher are angelOS's own now (two lists of the same plugins
    // were one too many). Its folder becomes a snapshot (plugin-backups/community-store), its
    // settings carry over: auto-update on means the daily check stays on.
    Timer {
        running: root.live && !Config.plugins.storeRetired
        interval: 3000
        onTriggered: {
            const old = (Config.plugins.data || {})["community-store"] || {};
            if (old.autoUpdate === true)
                Config.plugins.autoCheck = true;
            retirer.running = true;
        }
    }
    Process {
        id: retirer
        command: ["python3", root.script, "retire"]
        onExited: code => {
            if (code === 0) {
                Config.plugins.storeRetired = true;
                Plugins.reload();
            }
        }
    }
}
