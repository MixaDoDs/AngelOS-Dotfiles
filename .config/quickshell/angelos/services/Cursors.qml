pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Cursor theme: one theme everywhere (niri, GTK, Qt, X11/XWayland, Steam, Flatpak).
// scripts/cursors.py downloads/builds the themes and writes every config.
// Hell: while the demon rules the pointer is Config.cursor.hell — "circle" (the default): the
// circle's own (story/circles.json → cursor, angelOS-Circle-<Circle>), changing as she takes you
// from circle to circle, in the variation of the mood (`mood`: "" | "tip" | "alive" — how close
// the player is to this circle's demon, Story.demonStep: close is the accent tip, your own a
// rare animation); or one hell theme always. Built on first use, put on only
// when it changes (a new circle, a new mood step: cursors.py apply rewrites niri, GTK, X11…).
// The angel brings yours back. Your own pick stays in Config.cursor.theme the whole time. If
// you never picked one, the cursor that was there before (niri's) is kept in
// Config.cursor.beforeHell.
Singleton {
    id: root

    readonly property string theme: Config.cursor.theme || Quickshell.env("XCURSOR_THEME") || ""
    readonly property int size: Config.cursor.theme || hellOn ? Config.cursor.size : (parseInt(Quickshell.env("XCURSOR_SIZE")) || 24)
    // the theme on screen right now: the demon's while she rules
    readonly property bool hellOn: Config.ready && Angel.demon && !!Config.cursor.hell
    // the mood's variation of the circle's cursor: "" (as it is) | "tip" | "alive"
    readonly property int demonStep: Story.ready && Story.inHell ? Story.demonStep : 0
    readonly property string mood: demonStep >= 3 ? "alive" : demonStep >= 2 ? "tip" : ""
    readonly property bool byCircle: Config.cursor.hell === "circle"
    // the circle's own theme now (hell before any circle: angelOS Hell)
    readonly property string circleTheme: {
        const c = HellLook.circle;
        if (!c || c === "base" || !catalog.some(e => e.circle === c))
            return "angelOS-Hell";
        const base = "angelOS-Circle-" + c.charAt(0).toUpperCase() + c.slice(1);
        return base + (mood === "tip" ? "-Tip" : mood === "alive" ? "-Alive" : "");
    }
    readonly property string hellTheme: byCircle ? circleTheme : Config.cursor.hell
    // heaven's in the angel's mood (Story.angelStep): cooling, angelOS Glitter loses its
    // sparkle (angelOS Pixel); cold for good, angelOS's own arrow frosts over (angelOS Frost).
    // Someone else's theme stays as it is.
    readonly property int angelStep: Story.ready ? Story.angelStep : 0
    // the Golden Gate skin: macOS's black arrow — "macOS" (ful1e5/apple_cursor, redrawn, GPL-3.0,
    // the catalog's "macos") when it is installed, else capitaine-cursors (drawn after macOS's
    // cursors, LGPL-3.0, from the distribution) — while it is on and the demon doesn't rule; the
    // cursor before it comes back when it goes (Config.cursor.beforeMac)
    readonly property bool macInstalled: catalog.some(e => e.theme === "macOS" && e.installed)
    readonly property string macTheme: macInstalled ? "macOS" : "capitaine-cursors"
    readonly property bool macCursor: GoldenGate.on && !hellOn && (macInstalled || other.includes(macTheme))
    readonly property string heavenTheme: {
        if (macCursor)
            return macTheme;
        const own = theme === "angelOS-Pixel" || theme === "angelOS-Glitter";
        if (angelStep >= 3 && own)
            return "angelOS-Frost";
        if (angelStep >= 1 && theme === "angelOS-Glitter")
            return "angelOS-Pixel";
        return theme;
    }
    readonly property string active: hellOn ? hellTheme : heavenTheme
    // her mood changed in heaven: the cursor follows, then — only when it does
    onHeavenThemeChanged: if (!hellOn && Config.cursor.theme && _listed) {
        _attempt = "";
        Qt.callLater(sync);
    }
    property var catalog: []
    readonly property var heavenly: catalog.filter(c => c.realm !== "hell" && !c.hidden)
    // the hell themes one can pick: the six and the circles' own (not their mood variations)
    readonly property var hellish: catalog.filter(c => c.realm === "hell" && !c.hidden)
    property var other: []              // cursor themes found on the system
    property var status: ({})           // where which theme is set
    property string log: ""
    property string working: ""         // id / theme being installed or applied
    readonly property bool busy: worker.running
    readonly property string script: Quickshell.shellDir + "/scripts/cursors.py"

    function refresh() {
        if (!lister.running)
            lister.running = true;
    }
    function colors() {
        return ["--accent", Theme.hex(Theme.accent), "--edge", Theme.hex(Theme.edge), "--light", "#fff4fb"];
    }
    function entryOf(themeName) {
        return catalog.find(c => c.theme === themeName) || null;
    }
    function install(id, thenApply) {
        if (worker.running)
            return;
        working = id;
        log = "";
        worker.after = thenApply ? id : "";
        worker.command = ["python3", script, "install", id].concat(colors());
        worker.running = true;
    }
    // your pick (Settings → Cursor). In hell it waits for the angel.
    function apply(themeName, sz) {
        if (worker.running)
            return;
        Config.cursor.theme = themeName;
        Config.cursor.size = sz;
        if (Shell.dev) {
            log = I18n.t("В dev-режиме системные настройки курсора не меняются", "Dev mode does not change the system cursor");
            return;
        }
        if (hellOn) {
            _pending = true;
            Qt.callLater(sync);
            log = I18n.t("Запомнила. Пока правит демоница, курсор адский — твой вернётся вместе с ангелом.", "Saved. While the demon rules the cursor is hers — yours comes back with the angel.");
            return;
        }
        put(themeName, sz);
    }
    // the theme the demon puts on (Settings → Cursor → Hell): "circle" = the circle's own,
    // a theme = always that one, "" = she leaves the cursor alone
    function setHell(themeName) {
        Config.cursor.hell = themeName;
        if (themeName && themeName !== "circle")
            Config.cursor.hellPick = themeName;
        _attempt = "";
        const e = entryOf(themeName === "circle" ? circleTheme : themeName);
        // not built yet: now (on at once if she's here, otherwise ready for when she comes)
        if (e && !e.installed && !worker.running)
            install(e.id, hellOn);
        else
            Qt.callLater(sync);
    }
    // the theme on the system, without touching your pick
    function put(themeName, sz) {
        if (worker.running || Shell.dev || !themeName)
            return;
        working = themeName;
        worker.after = "";
        worker.command = ["python3", script, "apply", themeName, String(sz)].concat(Config.cursor.flatpak ? [] : ["--no-flatpak"]);
        worker.running = true;
    }
    // angelOS Pixel follows the accent: rebuild, then make niri reload the files
    function recolor() {
        install("angelos", true);
    }

    // ---- heaven ⇄ hell ----
    // What should be on the system now: the demon's theme while she rules; back
    // from hell yours, or what niri had before her if you never picked one. Runs
    // after every listing, so it only ever acts on fresh status.
    property bool _listed: false
    property bool _pending: false       // picked in hell: put on when the angel is back
    property string _attempt: ""        // what sync last tried: never the same twice in a row
    onHellOnChanged: {
        _attempt = "";
        Qt.callLater(sync);
    }
    onMacCursorChanged: {
        _attempt = "";
        Qt.callLater(sync);
    }
    // a new circle, a new mood step: the circle's cursor changes — only then
    onHellThemeChanged: if (hellOn) {
        _attempt = "";
        Qt.callLater(sync);
    }
    // older settings: "angelOS-Hell" was the default before the circles had their own — it
    // becomes "circle" once (a later pick is the player's own and stays). A beat after Config
    // is ready: the file's values land just after `ready`
    Timer {
        id: migrateSoon
        interval: 400
        onTriggered: {
            if (!Config.ready || Config.cursor.hellByCircle)
                return;
            if (Config.cursor.hell === "angelOS-Hell")
                Config.cursor.hell = "circle";
            Config.cursor.hellByCircle = true;
        }
    }
    Component.onCompleted: if (Config.ready)
        migrateSoon.restart()
    Connections {
        target: Config
        function onReadyChanged() {
            Qt.callLater(root.sync);
            if (Config.ready)
                migrateSoon.restart();
        }
    }
    function isHell(themeName) {
        const e = entryOf(themeName);
        return !!e && e.realm === "hell";
    }
    function wanted() {
        const sz = Config.cursor.size || 24;
        if (hellOn)
            return {
                "theme": hellTheme,
                "size": sz
            };
        const now = status.niri ? status.niri[0] : "";
        // the skin's arrow on; off again, the one before it back
        if (macCursor && now !== macTheme) {
            if (!Config.cursor.beforeMac)
                Config.cursor.beforeMac = now || status.gsettings || "Adwaita";
            return {
                "theme": macTheme,
                "size": sz
            };
        }
        if (!macCursor && now === macTheme && Config.cursor.beforeMac) {
            const back = Config.cursor.theme ? heavenTheme : Config.cursor.beforeMac;
            Config.cursor.beforeMac = "";
            return {
                "theme": back,
                "size": sz
            };
        }
        if (Config.cursor.theme && now !== heavenTheme && (now === Config.cursor.theme || now === "angelOS-Frost" || now === "angelOS-Pixel" || now === "angelOS-Glitter"))
            return {
                "theme": heavenTheme,
                "size": sz
            };
        if (!_pending && !isHell(now))
            return null;
        if (Config.cursor.theme)
            return {
                "theme": heavenTheme,
                "size": sz
            };
        return Config.cursor.beforeHell ? {
            "theme": Config.cursor.beforeHell,
            "size": Config.cursor.beforeHellSize || sz
        } : null;
    }
    function sync() {
        if (!_listed || !Config.ready || Shell.dev || worker.running)
            return;
        const w = wanted();
        if (!w)
            return;
        const now = status.niri || [];
        if (now[0] === w.theme && now[1] === w.size) {
            if (!hellOn) {
                _pending = false;
                Config.cursor.beforeHell = "";
            }
            return;
        }
        const key = w.theme + "@" + w.size;
        if (_attempt === key)
            return;
        _attempt = key;
        // never picked a cursor: remember the one she replaces
        if (hellOn && !Config.cursor.theme && !isHell(now[0])) {
            Config.cursor.beforeHell = now[0] || status.x11 || status.gsettings || Quickshell.env("XCURSOR_THEME") || "Adwaita";
            Config.cursor.beforeHellSize = now[1] || parseInt(Quickshell.env("XCURSOR_SIZE")) || 24;
        }
        const e = entryOf(w.theme);
        if (e && !e.installed)
            install(e.id, true);
        else
            put(w.theme, w.size);
    }

    Process {
        id: lister
        running: true
        command: ["python3", root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (r.error)
                        return;
                    root.catalog = r.catalog;
                    root.other = r.other;
                    root.status = r.status || {};
                    root._listed = true;
                    Qt.callLater(root.sync);
                } catch (e) {}
            }
        }
    }
    Process {
        id: worker
        property string after: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try {
                    r = JSON.parse(text);
                } catch (e) {
                    root.log = text.trim().slice(-300);
                }
                if (r.error)
                    root.log = I18n.t("Ошибка: ", "Error: ") + r.error;
                else if (r.done)
                    root.log = I18n.t("Готово: ", "Applied: ") + r.done.join(", ") + I18n.t(". Steam и открытые X11-программы подхватят курсор после перезапуска.", ". Steam and running X11 apps pick it up after a restart.");
                else if (r.theme && worker.after) {
                    // freshly built: apply it (a size nudge makes niri reload the same theme name)
                    const t = r.theme, sz = Config.cursor.size || 24;
                    // the demon's, or heaven's in the angel's mood (Frost): put on, never made the pick
                    const hell = (root.hellOn && t === root.hellTheme) || (!root.hellOn && t === root.heavenTheme && t !== Config.cursor.theme);
                    Qt.callLater(() => {
                        if (Shell.dev)
                            return;
                        if (hell || (Config.cursor.theme === t && !root.hellOn)) {
                            worker.command = ["python3", root.script, "apply", t, String(sz + 1)];
                            worker.after = "";
                            worker.nudgeBack = sz;
                            worker.nudgeTheme = t;
                            worker.running = true;
                        } else {
                            root.apply(t, sz);
                        }
                    });
                }
            }
        }
        property int nudgeBack: 0
        property string nudgeTheme: ""
        onExited: {
            if (nudgeBack > 0) {
                const sz = nudgeBack, t = nudgeTheme;
                nudgeBack = 0;
                Qt.callLater(() => root.put(t, sz));
                return;
            }
            root.working = "";
            root.refresh();
        }
    }
}
