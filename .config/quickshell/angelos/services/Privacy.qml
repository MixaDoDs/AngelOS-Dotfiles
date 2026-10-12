pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Privacy on stream: while the mode is on, the apps of a list are black in screencasts and
// live on the screens (niri's block-out-from "screencast"). The dotfiles' tool
// ~/.local/bin/niri-cast-privacy owns both files — the list (~/.config/angelos/privacy.json)
// and niri's rule (cfg/privacy-block.kdl) — and works without the shell: Mod+Shift+X switches
// the mode, Mod+Ctrl+Shift+X takes the focused window's app into the list or out of it. This
// only reads the files and asks the tool to change them.
// Settings → Streaming → Stream mode → Privacy on stream; `angelos privacy …`.
Singleton {
    id: root

    readonly property string tool: Config.home + "/.local/bin/niri-cast-privacy"
    readonly property string listPath: Config.dir + "/privacy.json"
    readonly property string rulePath: Config.home + "/.config/niri/cfg/privacy-block.kdl"
    // the tool's list when it has written none yet (its DEFAULT)
    readonly property var defaults: [
        {"id": "org.telegram.desktop", "name": "Telegram", "on": true},
        {"id": "io.github.snowyfluffy.freshgram", "name": "Freshgram", "on": true},
        {"id": "Bitwarden", "name": "Bitwarden", "on": true},
        {"id": "helium", "name": "Helium", "on": true},
        {"id": "discord", "name": "Discord", "on": true}
    ]

    property bool on: false                  // the mode
    property var apps: defaults              // [{id, name, on}]
    property string error: ""
    readonly property var hidden: apps.filter(a => a.on)
    // apps of the windows open now that the list doesn't have: offered in Settings
    readonly property var candidates: {
        const known = new Set(apps.map(a => a.id));
        const out = [];
        for (const w of Niri.windows) {
            const id = w.app_id || "";
            if (!id || id === "org.quickshell" || known.has(id))
                continue;
            known.add(id);
            const e = DesktopEntries.heuristicLookup(id);
            out.push({"id": id, "name": e && e.name ? e.name : id});
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
    }
    // the OSD's word when a notification would not be seen (Do not disturb — a stream)
    signal flag(string icon, string text)

    function has(id) {
        return hidden.some(a => a.id === id);
    }
    // on | off | toggle
    function set(mode) {
        run([mode]);
    }
    // add | remove | toggle | forget; no id: the focused window's app
    function app(action, id) {
        run(id ? ["app", action, id] : ["app", action]);
    }

    property var _queue: []
    function run(args) {
        if (Shell.dev) {
            error = I18n.t("В dev-режиме конфиг niri не изменяется", "Dev mode does not modify niri");
            return;
        }
        _queue = _queue.concat([args]);
        _next();
    }
    function _next() {
        if (tool_.running || _queue.length === 0)
            return;
        const args = _queue[0];
        _queue = _queue.slice(1);
        error = "";
        tool_.command = [root.tool].concat(args);
        tool_.running = true;
    }
    Process {
        id: tool_
        // the tool's own notification says what happened; under Do not disturb the OSD does
        environment: ({"ANGELOS_LANG": I18n.english ? "en" : "ru"})
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.error = text.trim().replace(/^niri-cast-privacy: /, "")
        }
        onExited: root._next()
    }

    FileView {
        path: root.listPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text()).apps;
                root.apps = list.filter(a => a && typeof a.id === "string" && a.id).map(a => ({"id": a.id, "name": a.name || a.id, "on": a.on !== false}));
            } catch (e) {
                root.apps = root.defaults;
            }
        }
        onLoadFailed: root.apps = root.defaults
    }
    property bool _ruleRead: false
    FileView {
        path: root.rulePath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            root._seen(t.startsWith("// privacy block-out on") || t.includes("block-out-from"));
        }
        onLoadFailed: root._seen(false)
    }
    function _seen(now) {
        const changed = _ruleRead && now !== on;
        const first = !_ruleRead;
        on = now;
        _ruleRead = true;
        if (first)
            _sync();
        if (changed && Config.notifications.dnd)
            flag("eye", now ? I18n.t("приватность вкл", "privacy on") : I18n.t("приватность выкл", "privacy off"));
    }

    // with the stream: on when OBS goes live, back to what it was when the stream ends
    // (only if it is still on by us — switched off by hand in between stays off)
    readonly property bool wanted: Config.ready && Config.stream.privacyAuto && StreamMode.obsLive
    onWantedChanged: _sync()
    function _sync() {
        if (!_ruleRead || !Config.ready)
            return;
        if (wanted && !on) {
            Config.stream.privacySet = true;
            set("on");
        } else if (!wanted && Config.stream.privacySet) {
            Config.stream.privacySet = false;
            if (on)
                set("off");
        }
    }
    onOnChanged: if (!on && _ruleRead && Config.ready && Config.stream.privacySet && wanted)
        Config.stream.privacySet = false
}
