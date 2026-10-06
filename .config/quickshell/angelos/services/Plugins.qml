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

    // a core plugin is a part of angelOS (manifest "core": true, bundled only): always on,
    // never removed (plugins/community — the catalog's launcher search)
    function isCore(p) {
        return !!p && p.core === true && !!p.bundled;
    }
    // plugins whose job angelOS does itself now (the old stand-alone Community Store): skipped
    readonly property var retired: ["community-store"]
    function isEnabled(p) {
        if (isCore(p))
            return true;
        const e = (Config.plugins.enabled || {})[p.id];
        return e === undefined ? p.enabledByDefault !== false : !!e;
    }
    function setEnabled(id, on) {
        if (isCore(byId(id)))
            return;
        Config.setIn(Config.plugins, "enabled", id, !!on);
    }
    // ---- the looks a plugin draws (manifest "themes", docs/PLUGINS.md → Theme API) ----
    // "pixel" — angelOS's original pixel look, "mac" — Golden Gate. A plugin that declares
    // nothing was made before the Mac look: pixel only. The same rule reads a registry entry.
    readonly property var themeNames: ["pixel", "mac"]
    function themesOf(p) {
        // (a manifest kept in a `var` property comes back as a sequence, not an Array: Array.from)
        const raw = p && p.themes && typeof p.themes !== "string" && p.themes.length !== undefined ? Array.from(p.themes) : [];
        const t = raw.filter(x => themeNames.includes(String(x))).map(String);
        return t.length ? t : ["pixel"];
    }
    // "both" | "mac" | "pixel"
    function themeKind(p) {
        const t = themesOf(p);
        return t.includes("mac") && t.includes("pixel") ? "both" : t[0];
    }
    function themeLabel(p) {
        const k = themeKind(p);
        return k === "both" ? I18n.t("обе темы", "both themes") : k === "mac" ? "macOS" : "Pixel";
    }
    // the look on now: Golden Gate or pixel (services/Skin)
    readonly property string currentTheme: Skin.mac ? "mac" : "pixel"
    function supportsCurrent(p) {
        return themesOf(p).includes(currentTheme);
    }
    // a line for the Plugins page / the catalog when the plugin does not draw the look in use
    function themeWarning(p) {
        if (!p || supportsCurrent(p))
            return "";
        return currentTheme === "mac" ? I18n.t("Не поддерживает тему macOS: в Golden Gate будет выглядеть пиксельным.", "Doesn't support the macOS theme: it will look pixelated in Golden Gate.") : I18n.t("Сделан только для темы macOS: в пиксельной теме может выглядеть чужим.", "Made for the macOS theme only: it may look out of place in the pixel theme.");
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
        // in the apps' environment (Shell.childEnv), never the shell's own
        if (entry.exec)
            Shell.exec(["sh", "-c", entry.exec]);
        if (entry.settings)
            Shell.openSettings(entry.settings);
        if (entry.url)
            Shell.exec(["xdg-open", entry.url]);
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
        if (!p || isCore(p))
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
        plugins = Object.values(byIdMap).sort((a, b) => String(I18n.label(a.name)).localeCompare(String(I18n.label(b.name))));
        removed = gone.sort((a, b) => String(I18n.label(a.name)).localeCompare(String(I18n.label(b.name))));
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
                        if (root.retired.includes(m.id) && !m.bundled)
                            continue;
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
