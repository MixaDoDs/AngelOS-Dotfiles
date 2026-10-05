pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, persisted to ~/.config/angelos/settings.json.
// Every property change is written back after a short debounce.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/.config/angelos"
    readonly property string pluginsDir: dir + "/plugins"
    readonly property string templatesDir: dir + "/templates"
    readonly property string stateDir: home + "/.local/state/angelos"
    readonly property string cacheDir: home + "/.cache/angelos"

    property bool newConfig: false
    readonly property bool ready: file.loaded || newConfig
    property alias appearance: adapter.appearance
    property alias bar: adapter.bar
    property alias wallpaper: adapter.wallpaper
    property alias workspaces: adapter.workspaces
    property alias alttab: adapter.alttab
    property alias lyrics: adapter.lyrics
    property alias setup: adapter.setup
    property alias notifications: adapter.notifications
    property alias osd: adapter.osd
    property alias launcher: adapter.launcher
    property alias voxtype: adapter.voxtype
    property alias desktop: adapter.desktop
    property alias lock: adapter.lock
    property alias idle: adapter.idle
    property alias sidebar: adapter.sidebar
    property alias capture: adapter.capture
    property alias plugins: adapter.plugins
    property alias dotfiles: adapter.dotfiles
    property alias system: adapter.system
    property alias developer: adapter.developer
    property alias settingsUi: adapter.settingsUi
    property alias y2k: adapter.y2k
    property alias cursor: adapter.cursor
    property alias updates: adapter.updates
    property alias network: adapter.network
    property alias stream: adapter.stream
    property alias lens: adapter.lens
    property alias novel: adapter.novel
    property alias game: adapter.game
    property alias decor: adapter.decor
    property alias windows: adapter.windows
    property alias mac: adapter.mac
    // the same schema, never loaded: every setting's default value
    readonly property SettingsSchema defaults: SettingsSchema {}

    // default value of "section.key" (a copy: arrays and maps are shared otherwise)
    function defaultOf(path) {
        const [section, key] = String(path).split(".");
        const d = defaults[section];
        if (!d || !(key in d))
            return undefined;
        const v = d[key];
        return v !== null && typeof v === "object" ? JSON.parse(JSON.stringify(v)) : v;
    }
    // put settings back to their defaults: ["y2k.helper", "bar.style", …]
    function resetKeys(paths) {
        let n = 0;
        for (const path of paths || []) {
            const [section, key] = String(path).split(".");
            const obj = adapter[section];
            const v = defaultOf(path);
            if (!obj || v === undefined || JSON.stringify(obj[key]) === JSON.stringify(v))
                continue;
            obj[key] = v;
            n++;
        }
        return n;
    }

    function expand(path) {
        if (!path)
            return "";
        return path.startsWith("~/") ? home + path.slice(1) : path;
    }

    // JSON maps have to be reassigned to notify the adapter.
    function setIn(obj, prop, key, value) {
        const copy = Object.assign({}, obj[prop] || {});
        if (value === undefined || value === null || value === "")
            delete copy[key];
        else
            copy[key] = value;
        obj[prop] = copy;
    }

    // ---- Undo (Settings → "Undo"): every save remembers what the user changed ----
    // Each step is [{path, old, new}]; bookkeeping the shell does by itself
    // (counters, the angel's state, update checks) is never a step.
    readonly property var sections: ["appearance", "bar", "wallpaper", "workspaces", "alttab", "lyrics", "setup", "notifications", "osd", "launcher", "voxtype", "desktop", "lock", "idle", "sidebar", "capture", "plugins", "dotfiles", "system", "developer", "settingsUi", "y2k", "cursor", "updates", "network", "stream", "lens", "decor", "windows", "novel", "game", "mac"]
    readonly property var notUndoable: ["launcher.usage", "settingsUi.usage", "settingsUi.expert", "settingsUi.skinChosen", "settingsUi.viewPicked", "settingsUi.win11Once", "updates.lastCheck", "updates.available", "setup.complete", "setup.gameAsked", "setup.keyboardAsked", "lyrics.sourcesVersion", "desktop.initialized", "plugins.data", "stream.dndSet", "stream.suppressed", "y2k.helperGreeted", "y2k.character", "y2k.demonSince", "y2k.pleas", "y2k.lastPlea", "y2k.pranks", "y2k.nextPrank", "y2k.seenTips", "y2k.angelSaved", "y2k.raysSeen", "y2k.returns", "cursor.beforeHell", "cursor.beforeHellSize", "cursor.beforeMac", "mac.wallBefore", "appearance.customAccentHell", "game.enabled"]
    property var undoStack: []
    readonly property bool canUndo: undoStack.length > 0
    readonly property var lastStep: undoStack.length ? undoStack[undoStack.length - 1] : null
    property var _snap: null
    property bool _undoing: false
    function snapshot() {
        const s = {};
        for (const sec of sections) {
            const d = defaults[sec], o = adapter[sec];
            if (!d || !o)
                continue;
            for (const k in d) {
                if (k === "objectName" || typeof d[k] === "function")
                    continue;
                s[sec + "." + k] = JSON.stringify(o[k] === undefined ? null : o[k]);
            }
        }
        return s;
    }
    function _record() {
        const now = snapshot();
        if (_snap && !_undoing) {
            const changes = [];
            for (const p in now)
                if (p in _snap && now[p] !== _snap[p] && !notUndoable.includes(p))
                    changes.push({
                        "path": p,
                        "old": JSON.parse(_snap[p]),
                        "new": JSON.parse(now[p])
                    });
            if (changes.length)
                undoStack = undoStack.concat([{
                        "changes": changes,
                        "at": Date.now()
                    }]).slice(-40);
        }
        _snap = now;
        _undoing = false;
    }
    // a change still waiting for the debounced save becomes a step (and is written) now
    function flush() {
        if (!saveTimer.running)
            return;
        saveTimer.stop();
        _record();
        file.writeAdapter();
    }
    function undo() {
        const step = lastStep;
        if (!step)
            return false;
        undoStack = undoStack.slice(0, -1);
        _undoing = true;
        for (const c of step.changes) {
            const [sec, key] = c.path.split(".");
            adapter[sec][key] = c.old !== null && typeof c.old === "object" ? JSON.parse(JSON.stringify(c.old)) : c.old;
        }
        saveTimer.restart();
        return true;
    }

    Timer {
        id: saveTimer
        interval: 350
        onTriggered: {
            root._record();
            file.writeAdapter();
        }
    }

    Process {
        id: mkdirs
        running: true
        command: ["sh", "-c", 'mkdir -p "$@" && chmod 700 "$4"', "sh", root.dir, root.pluginsDir, root.templatesDir, root.stateDir, root.cacheDir + "/lyrics"]
    }

    FileView {
        id: file
        path: root.dir + "/settings.json"
        watchChanges: true
        // an async write re-reads what it wrote into the adapter when it finishes,
        // undoing any change made meanwhile (an Undo right after a save): write in place
        blockWrites: true
        onFileChanged: reload()
        // loaded from disk (start, another instance, an edit by hand): not an undo step
        onLoaded: {
            // a new section declared in SettingsSchema but missing from the user's
            // settings.json stays undefined on the adapter; seed it from defaults so
            // Config.<section>.<key> works without optional-chaining in every consumer
            for (const sec of root.sections) {
                const d = root.defaults[sec];
                if (!d || adapter[sec])
                    continue;
                const copy = JSON.parse(JSON.stringify(d));
                adapter[sec] = copy;
            }
            root._snap = root.snapshot();
        }
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.newConfig = true;
                saveTimer.restart();
            }
        }

        SettingsSchema {
            id: adapter
        }
    }
}
