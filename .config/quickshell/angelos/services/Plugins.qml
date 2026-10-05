pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Plugin registry. A plugin is a folder with manifest.json (see docs/PLUGINS.md):
//   ~/.config/angelos/plugins/<id>/   (user)
//   <shell>/plugins/<id>/              (bundled examples)
// Removing: a user plugin moves to the trash (~/.local/state/angelos/plugin-trash/
// <stamp>-<id>/), a bundled one is only hidden (Config.plugins.removed: the shell's
// files stay, an update would bring them back anyway). Both come back with restore().
Singleton {
    id: root

    readonly property string bundledDir: Quickshell.shellDir + "/plugins"
    readonly property string userDir: Config.pluginsDir
    readonly property string trashDir: Config.home + "/.local/state/angelos/plugin-trash"
    property var plugins: []
    // removed ones: hidden bundled plugins ({…manifest, bundled}) and the trash ({…, trashed, trashDir})
    property var removed: []
    property var _all: []                   // everything scanned, before hiding the removed
    property bool scanning: scanner.running
    // id -> a fresh path to a plugin changed while the shell runs (Plugin Studio, "Reload"):
    // QML caches components by URL, a new path makes the hosts compile the new files
    property var loadDirs: ({})

    // JsonAdapter can emit map changes even when membership is unchanged.
    // Keep service/component models stable across unrelated settings saves.
    readonly property string enabledIds: JSON.stringify(plugins.filter(p => isEnabled(p)).map(p => p.id))
    readonly property var enabledPlugins: JSON.parse(enabledIds).map(id => byId(id)).filter(p => !!p)
    readonly property var menuEntries: {
        const out = [];
        for (const p of enabledPlugins)
            for (const m of (p.menu || []))
                out.push(Object.assign({
                    "plugin": p.id
                }, m));
        return out;
    }
    readonly property var menuComponents: enabledPlugins.filter(p => !!p.menuComponent)
    readonly property var barWidgets: enabledPlugins.filter(p => !!p.barWidget)
    readonly property var desktopWidgets: enabledPlugins.filter(p => !!p.desktopWidget)
    readonly property var services: enabledPlugins.filter(p => !!p.main)
    readonly property var settingsPages: enabledPlugins.filter(p => !!p.settings)
    readonly property var sidebarWidgets: enabledPlugins.filter(p => !!p.sidebarWidget)
    readonly property var launcherProviders: enabledPlugins.filter(p => !!p.launcher)

    function isEnabled(p) {
        const e = (Config.plugins.enabled || {})[p.id];
        return e === undefined ? p.enabledByDefault !== false : !!e;
    }
    function setEnabled(id, on) {
        Config.setIn(Config.plugins, "enabled", id, !!on);
    }
    function byId(id) {
        return plugins.find(p => p.id === id) || null;
    }
    function url(p, rel) {
        return "file://" + (loadDirs[p.id] || p.dir) + "/" + rel;
    }
    function setLoadDir(id, dir) {
        const m = Object.assign({}, loadDirs);
        m[id] = dir;
        loadDirs = m;
        reload();
    }
    function settingsOf(id) {
        return (Config.plugins.data || {})[id] || {};
    }
    function saveSettings(id, obj) {
        Config.setIn(Config.plugins, "data", id, obj);
    }

    // Optional manifest contributions to the same Appearance picker as built-in themes.
    // Settings contributions are scoped to their own plugin; cursor contributions use
    // the native cursor service and must already be installed on the system.
    property string appearanceSelection: ""
    readonly property var appearanceThemes: enabledPlugins.reduce((out, p) => {
        const entries = Array.isArray(p.appearanceThemes) ? p.appearanceThemes : [];
        const ids = {};
        for (const entry of entries) {
            if (!entry || typeof entry.id !== "string" || !/^[a-z0-9-]+$/.test(entry.id) || ids[entry.id]) continue;
            if (!["cursor", "plugin-settings", "settings"].includes(entry.kind)) continue;
            if (entry.kind === "cursor" && typeof entry.theme !== "string" && typeof entry.themeSetting !== "string") continue;
            if (entry.kind === "plugin-settings" && (!entry.settings || typeof entry.settings !== "object" || Array.isArray(entry.settings))) continue;
            ids[entry.id] = true;
            out.push(Object.assign({}, entry, {pluginId: p.id, value: "plugin-theme:" + p.id + ":" + entry.id}));
        }
        return out;
    }, [])
    function applyAppearanceTheme(value) {
        const entry = appearanceThemes.find(t => t.value === value);
        const p = entry && byId(entry.pluginId);
        if (!p || !isEnabled(p)) return false;
        if (entry.kind === "cursor") {
            const ctx = context(p);
            const theme = entry.themeSetting ? ctx.get(entry.themeSetting, "") : entry.theme;
            if (Cursors.busy || !Cursors.other.includes(theme)) return false;
            ctx.set("theme", entry.themeSetting ? "wallpaper" : theme);
            Cursors.apply(theme, Cursors.size);
        } else if (entry.kind === "plugin-settings") {
            const ctx = context(p);
            for (const key of Object.keys(entry.settings)) {
                if (["__proto__", "constructor", "prototype"].includes(key)) continue;
                const v = entry.settings[key];
                if (["string", "boolean", "number"].includes(typeof v)) ctx.set(key, v);
            }
        } else {
            Shell.openSettings("plugin:" + p.id);
        }
        appearanceSelection = value;
        return true;
    }
    Connections {
        target: Config.appearance
        function onFlavorChanged() { root.appearanceSelection = ""; }
    }

    // context object handed to every plugin component as `plugin`
    property var _ctx: ({})
    function context(p) {
        const load = loadDirs[p.id] || "";
        if (_ctx[p.id] && _ctx[p.id].dir === p.dir && _ctx[p.id]._load === load)
            return _ctx[p.id];
        const c = {
            "id": p.id,
            "dir": p.dir,
            "_load": load,
            "manifest": p,
            "url": rel => url(p, rel),
            "settings": () => settingsOf(p.id),
            "get": (key, def) => {
                const s = settingsOf(p.id);
                return s[key] === undefined ? def : s[key];
            },
            "set": (key, value) => {
                const s = Object.assign({}, settingsOf(p.id));
                s[key] = value;
                saveSettings(p.id, s);
            }
        };
        _ctx[p.id] = c;
        return c;
    }

    function run(entry) {
        if (entry.exec)
            Quickshell.execDetached(["sh", "-c", entry.exec]);
        if (entry.settings)
            Shell.openSettings(entry.settings);
        if (entry.url)
            Quickshell.execDetached(["xdg-open", entry.url]);
    }

    function reload() {
        scanner.running = false;
        scanner.running = true;
    }

    function isRemoved(id) {
        return (Config.plugins.removed || []).includes(id);
    }
    // remove: a user plugin goes to the trash, a bundled one is hidden
    function remove(id) {
        const p = byId(id);
        if (!p)
            return;
        if (p.bundled) {
            if (!isRemoved(id))
                Config.plugins.removed = (Config.plugins.removed || []).concat([id]);
            _split();
            return;
        }
        const stamp = new Date().toISOString().replace(/[-:]/g, "").replace("T", "-").slice(0, 15);
        _move(p.dir, trashDir + "/" + stamp + "-" + id);
    }
    // bring back: a hidden bundled plugin shows again, a trashed one moves home
    // (not over a plugin with the same id made since: then it stays in the trash)
    function restore(entry) {
        if (!entry)
            return;
        if (entry.trashed) {
            _move(entry.trashDir, userDir + "/" + entry.id);
            return;
        }
        Config.plugins.removed = (Config.plugins.removed || []).filter(x => x !== entry.id);
        _split();
    }
    // a trashed plugin, for good
    function erase(entry) {
        if (!entry || !entry.trashed || !entry.trashDir.startsWith(trashDir + "/"))
            return;
        mover.command = ["rm", "-rf", "--", entry.trashDir];
        mover.running = true;
    }
    signal moveFailed(string why)
    function _move(from, to) {
        mover.command = ["sh", "-c", '[ -e "$2" ] && { echo "exists: $2"; exit 3; }; mkdir -p "$(dirname "$2")" && mv -- "$1" "$2"', "sh", from, to];
        mover.running = true;
    }
    Process {
        id: mover
        stdout: StdioCollector {
            id: moverOut
        }
        onExited: code => {
            if (code !== 0)
                root.moveFailed(code === 3 ? I18n.t("плагин с таким id уже есть — сначала удали его", "a plugin with this id is already there — remove it first") : I18n.t("не получилось переместить папку", "could not move the folder"));
            root.reload();
        }
    }
    // the scan, split into the shown and the removed
    function _split() {
        const hidden = Config.plugins.removed || [];
        const shown = [], gone = [];
        for (const p of _all) {
            if (p.trashed)
                gone.push(p);
            else if (p.bundled && hidden.includes(p.id))
                gone.push(p);
            else
                shown.push(p);
        }
        // a user plugin overriding a bundled one shadows it in the list either way
        const byIdMap = {};
        for (const p of shown)
            if (!byIdMap[p.id] || !p.bundled)
                byIdMap[p.id] = p;
        plugins = Object.values(byIdMap).sort((a, b) => a.name.localeCompare(b.name));
        removed = gone.sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property string _removedKey: JSON.stringify(Config.plugins.removed || [])
    on_RemovedKeyChanged: _split()

    // scaffold a new plugin from plugins/_template
    function create(id, name) {
        id = id.replace(/[^a-z0-9_-]/gi, "-").toLowerCase();
        if (!id)
            return;
        creator.command = ["python3", Quickshell.shellDir + "/scripts/plugin-create.py", bundledDir, userDir, id, name || id];
        creator.running = true;
    }
    signal created(string id, bool ok)

    Process {
        id: creator
        onExited: code => {
            root.created(creator.command[4], code === 0);
            root.reload();
        }
    }

    Component.onCompleted: reload()
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            root.reload();
        }
    }

    Process {
        id: scanner
        command: ["sh", "-c", 'for f in "$1"/*/manifest.json "$2"/*/manifest.json "$3"/*/manifest.json; do [ -f "$f" ] || continue; case "$f" in */_template/*) continue;; esac; printf "%s\\t" "$(dirname "$f")"; tr -d "\\n\\r" < "$f"; echo; done', "sh", root.bundledDir, root.userDir, root.trashDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const dir = line.slice(0, tab);
                    try {
                        const m = JSON.parse(line.slice(tab + 1));
                        m.dir = dir;
                        m.trashed = dir.startsWith(root.trashDir + "/");
                        m.id = m.id || dir.split("/").pop().replace(m.trashed ? /^\d{8}-\d{6}-/ : /^$/, "");
                        if (m.trashed)
                            m.trashDir = dir;
                        m.bundled = dir.startsWith(root.bundledDir);
                        m.name = m.name || m.id;
                        all.push(m);
                    } catch (e) {
                        console.warn("angelOS plugin: bad manifest in", dir, e);
                    }
                }
                root._all = all;
                root._split();
            }
        }
    }
}
