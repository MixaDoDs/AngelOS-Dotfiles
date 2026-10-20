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
    // a second process that only reads the settings (the screenshot overlay's, services/CircleHost):
    // it never writes settings.json, nor repairs or backs it up — the shell does
    readonly property bool readOnly: Quickshell.env("ANGELOS_CONFIG_READONLY") === "1"
    // settings.json is read and it parsed. One that doesn't parse (cut short by a crash or a
    // power cut: it is written in place) is put right first, see JsonRescue — read as it was
    // it meant "every default", and that was written back a moment later
    property bool _parsed: false
    property int _badLoads: 0
    readonly property bool ready: (file.loaded && _parsed) || newConfig
    // such a repair at this start: "restored" (the last good copy) | "lost" (defaults) | ""
    readonly property string repaired: rescue.outcome
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
    property alias phone: adapter.phone
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
    property alias power: adapter.power
    property alias peripherals: adapter.peripherals
    property alias laptop: adapter.laptop
    property alias gestures: adapter.gestures
    property alias stream: adapter.stream
    property alias lens: adapter.lens
    property alias circle: adapter.circle
    property alias quickshare: adapter.quickshare
    property alias quicklook: adapter.quicklook
    property alias island: adapter.island
    property alias halo: adapter.halo
    property alias novel: adapter.novel
    property alias game: adapter.game
    property alias gaming: adapter.gaming
    property alias decor: adapter.decor
    property alias windows: adapter.windows
    property alias mac: adapter.mac
    property alias recovery: adapter.recovery
    property alias wellbeing: adapter.wellbeing
    property alias vault: adapter.vault
    property alias spell: adapter.spell
    property alias keycast: adapter.keycast
    property alias discord: adapter.discord
    property alias menus: adapter.menus
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
    readonly property var sections: ["appearance", "bar", "wallpaper", "workspaces", "alttab", "lyrics", "setup", "notifications", "osd", "launcher", "voxtype", "desktop", "lock", "idle", "sidebar", "phone", "capture", "plugins", "dotfiles", "system", "developer", "settingsUi", "y2k", "cursor", "updates", "network", "power", "peripherals", "laptop", "gestures", "stream", "lens", "circle", "quickshare", "quicklook", "island", "halo", "decor", "windows", "novel", "game", "gaming", "mac", "recovery", "wellbeing", "vault", "spell", "keycast", "discord", "menus"]
    readonly property var notUndoable: ["launcher.usage", "settingsUi.usage", "settingsUi.searchHistory", "settingsUi.expert", "settingsUi.skinChosen", "settingsUi.viewPicked", "settingsUi.win11Once", "updates.lastCheck", "updates.available", "updates.paperSeen", "updates.notifiedFor", "dotfiles.adminWarned", "setup.complete", "setup.gameAsked", "setup.keyboardAsked", "lyrics.sourcesVersion", "desktop.initialized", "plugins.data", "plugins.lastCheck", "plugins.notifiedFor", "plugins.storeRetired", "stream.dndSet", "stream.suppressed", "stream.castHinted", "stream.privacySet", "lock.chestNotified", "y2k.helperGreeted", "y2k.character", "y2k.demonSince", "y2k.pleas", "y2k.lastPlea", "y2k.pranks", "y2k.nextPrank", "y2k.seenTips", "y2k.angelSaved", "y2k.raysSeen", "y2k.returns", "cursor.beforeHell", "cursor.beforeHellSize", "cursor.beforeMac", "mac.wallBefore", "wallpaper.themes", "wallpaper.themeOf", "wallpaper.releaseSeen", "recovery.lastPush", "appearance.customAccentHell", "game.enabled"]
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
        _write();
    }
    // the shell going away (shell.qml's teardown: `angelos restart`/stop go through `qs kill`, so
    // do the unit's ExecStop and Quickshell.reload): a change still in the debounce — or a value
    // changed in place, which never notifies — is written now; the next start read the file from
    // before it. A singleton's own Component.onDestruction never runs. Unchanged text isn't rewritten
    function persist() {
        saveTimer.stop();
        _write();
    }
    // The language of a first start nobody answered for (the installer asks on a terminal
    // only; a clone by hand, a script, a package never do): the system's, not the author's.
    // Like the installer: Russian for a ru_* locale, English for everyone else — the wizard's
    // first step still asks. `saved`: settings.json as parsed, null when there is none
    function _firstLanguage(saved) {
        if (saved && ((saved.appearance && typeof saved.appearance.language === "string") || (saved.setup && saved.setup.complete)))
            return;
        const locale = String(Quickshell.env("ANGELOS_LANG") || Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || Qt.locale().name || "");
        const lang = /^ru/i.test(locale) ? "ru" : "en";
        if (adapter.appearance.language !== lang)
            adapter.appearance.language = lang;
    }
    // old values of keys that are gone, put right on load (before the snapshot: not an Undo step;
    // the change is saved like any other). 2026-10-20: the Start looks Windose and Wii are
    // gone — their users get win11, and those looks' Fine-tune sets go with them
    function _migrate() {
        const bar = adapter.bar;
        if (!bar)
            return;
        if (bar.startStyle === "windose" || bar.startStyle === "wii")
            bar.startStyle = "win11";
        const prefs = bar.startPrefs;
        if (prefs && (prefs.windose !== undefined || prefs.wii !== undefined)) {
            const kept = Object.assign({}, prefs);
            delete kept.windose;
            delete kept.wii;
            bar.startPrefs = kept;
        }
    }
    // never before the file is read: the adapter still holds the defaults then
    function _write() {
        if (!ready || readOnly)
            return;
        _record();
        file.writeAdapter();
        rescue.keepLater();
    }
    function undo() {
        // a change still waiting for its save is the last step: Undo right after a slider
        // moved took back the step before it and the slider's change stayed
        flush();
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
        onTriggered: root._write()
    }

    JsonRescue {
        id: rescue
        path: root.dir + "/settings.json"
        onRescued: restored => {
            file.reload();
            if (Quickshell.env("ANGELOS_TEST") !== "1")
                tellRepaired.start();
        }
    }
    // a half-written file at the very start (another instance saving): read it once more
    Timer {
        id: againSoon
        interval: 500
        onTriggered: file.reload()
    }
    // said once the shell's own notifications are up
    Timer {
        id: tellRepaired
        interval: 5000
        onTriggered: {
            const kept = "~/.config/angelos/settings.json.broken-…";
            if (root.repaired === "restored")
                Quickshell.execDetached(["notify-send", "-a", "angelOS", "-i", "dialog-warning", "-t", "20000", I18n.t("Настройки восстановлены", "Settings restored"), I18n.t("Файл настроек оказался повреждён (запись оборвалась). Вернулась последняя целая копия; повреждённый лежит рядом: ", "The settings file was damaged (a write was cut short). The last good copy is back; the damaged file is kept next to it: ") + kept]);
            else
                Quickshell.execDetached(["notify-send", "-a", "angelOS", "-u", "critical", "-i", "dialog-warning", I18n.t("Настройки начаты заново", "Settings started over"), I18n.t("Файл настроек оказался повреждён, а целой копии не нашлось. Повреждённый лежит рядом: ", "The settings file was damaged and there was no good copy. The damaged file is kept next to it: ") + kept]);
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
        // … but not atomically: an atomic write waits for fdatasync, here on the main
        // thread, and on a busy disk that froze the shell until the guard restarted it (#52)
        atomicWrites: false
        onFileChanged: reload()
        // loaded from disk (start, another instance, an edit by hand): not an undo step
        onLoaded: {
            if (!rescue.valid(file.text())) {
                // the shell is running: someone is in the middle of writing it, the whole
                // file follows; what is in memory stays
                if (root._parsed)
                    return;
                if (rescue.outcome === "") {
                    if (root._badLoads++ === 0 || root.readOnly)
                        againSoon.start();
                    else
                        rescue.rescue();
                    return;
                }
                // no good copy to bring back: the defaults, and they are saved
                root._firstLanguage(null);
                saveTimer.restart();
            } else if (!root._parsed) {
                if (!root.readOnly)
                    rescue.keepNow();
                root._firstLanguage(JSON.parse(file.text()));
            }
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
            root._migrate();
            // a load while a change waits for its save (the echo of our own last write) keeps
            // the snapshot from before it: else that change was never an Undo step
            if (!saveTimer.running)
                root._snap = root.snapshot();
            root._parsed = true;
        }
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root._firstLanguage(null);
                root.newConfig = true;
                saveTimer.restart();
            }
        }

        SettingsSchema {
            id: adapter
        }
    }
}
