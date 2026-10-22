pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Privacy on stream: while the mode is on, the apps of a list are black in screencasts and
// live on the screens (niri's block-out-from "screencast"). The dotfiles' tool
// ~/.local/bin/niri-cast-privacy owns both files — the list (~/.config/angelos/privacy.json)
// and niri's rule (cfg/privacy-block.kdl) — and works without the shell: Mod+Shift+X switches
// the mode, Mod+Ctrl+Shift+X takes the focused window's app into the list or out of it,
// Mod+Ctrl+X shows the focused app on stream for as long as the owner wants (`show`, not saved).
// Nothing is said on the screen when it switches (the owner's wish). This only reads the files
// and asks the tool to change them; the plates viewers see over hidden windows: PrivacyCast.
// Settings → Streaming → Stream mode → Privacy on stream; `angelos privacy …`.
Singleton {
    id: root

    readonly property string tool: Config.home + "/.local/bin/niri-cast-privacy"
    readonly property string listPath: Config.dir + "/privacy.json"
    readonly property string rulePath: Config.home + "/.config/niri/cfg/privacy-block.kdl"
    readonly property string shownPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/privacy-shown.json"
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
    property var shown: []                   // app-ids shown on stream for now (`show`)
    // what viewers see black now
    readonly property var hiddenNow: on ? hidden.filter(a => !shown.includes(a.id)) : []
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
    // toggle | on | off | clear: a hidden app on stream for now; no id: the focused window's
    function show(action, id) {
        run(id ? ["show", action, id] : ["show", action]);
    }
    function isShown(id) {
        return shown.includes(id);
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
    FileView {
        path: root.shownPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const ids = JSON.parse(text()).shown;
                root.shown = Array.isArray(ids) ? ids.filter(i => typeof i === "string") : [];
            } catch (e) {
                root.shown = [];
            }
        }
        onLoadFailed: root.shown = []
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
        const first = !_ruleRead;
        on = now;
        _ruleRead = true;
        if (first)
            _sync();
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

    // ---- what the viewers see over a hidden window: angel-niri draws it (set-privacy-look) ----
    // Config.stream.privacyLook for every app, Config.stream.privacyApps {appId: {look, image}}
    // for the ones with their own: plate | cat | angel (scripts/privacy-look.py draws them in the
    // theme's colours, niri centres them on Theme.desk) | mosaic | image (the owner's picture,
    // filling the window) | black. Stock niri and older angel-niri: black, and the OBS plates
    // (PrivacyCast) instead.
    readonly property var looks: ["plate", "mosaic", "cat", "angel", "image", "black"]
    function lookName(look) {
        return {
            "plate": I18n.t("Плашка", "Plate"),
            "mosaic": I18n.t("Мозаика", "Mosaic"),
            "cat": I18n.t("Котик", "Cat"),
            "angel": I18n.t("Ангел", "Angel"),
            "image": I18n.t("Картинка", "Picture"),
            "black": I18n.t("Чёрное", "Black")
        }[look] || look;
    }
    property bool nativeLook: false          // the running niri knows set-privacy-look
    readonly property string lookDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos/privacy-look"
    readonly property var appLooks: {
        const a = Config.stream.privacyApps;
        return a && typeof a === "object" ? a : {};
    }
    function appLook(id) {
        const e = appLooks[id];
        return e && looks.includes(e.look) ? e : null;
    }
    // look "" — back to the common one
    function setAppLook(id, look, image) {
        const all = Object.assign({}, appLooks);
        if (!look)
            delete all[id];
        else
            all[id] = {
                "look": look,
                "image": image !== undefined ? image : (all[id] && all[id].image) || ""
            };
        Config.stream.privacyApps = all;
    }

    // the owner's picture (scripts/pick-file.py: the portal, else zenity or kdialog); app "" — the common one
    property string pickingFor: ""
    property bool picking: false
    function pickImage(appId) {
        if (picker.running)
            return;
        pickingFor = appId || "";
        picking = true;
        picker.running = true;
    }
    Process {
        id: picker
        command: ["python3", Quickshell.shellDir + "/scripts/pick-file.py", I18n.t("angelOS — заглушка для эфира", "angelOS — what the stream shows"), I18n.t("Картинки", "Pictures"), "*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (!f)
                    return;
                if (root.pickingFor)
                    root.setAppLook(root.pickingFor, "image", f);
                else {
                    Config.stream.privacyImage = f;
                    Config.stream.privacyLook = "image";
                }
            }
        }
        onExited: root.picking = false
    }

    Connections {
        target: Niri
        function onMinimizeProbedChanged() {
            if (Niri.nativeMinimize)
                root._probeLook();
        }
    }
    Component.onCompleted: if (Niri.minimizeProbed && Niri.nativeMinimize)
        _probeLook()
    function _probeLook() {
        // an app nobody has: angel-niri forgets its look, stock niri doesn't know the action
        Niri.request({
            "Action": {
                "SetPrivacyLook": {
                    "look": "default",
                    "app_id": "angelos.probe"
                }
            }
        }, (ok, err) => {
            nativeLook = !err;
            if (nativeLook)
                lookLater.restart();
            // a pause left on by the shell before this one (restarted mid-pause)
            if (nativeLook)
                Niri.action("SetCastPause", {
                    "on": false
                });
        }, true);
    }

    // ---- the pause for viewers (angel-niri's set-cast-pause): every screencast shows a card
    // (scripts/privacy-look.py pause: the cat asleep, «СКОРО ВЕРНУСЬ») on the desk's colour, no
    // pointer; the screens go on as they are, sound too (it goes to OBS past niri). Mod+Alt+P,
    // `angelos castPause on|off|toggle`. The Halo keeps a capsule while it's on — on the
    // streamed screen too: the viewers see the card, not it. Not kept over a shell restart:
    // niri keeps it, so a restart sends off first
    property bool paused: false
    // on | off | toggle
    function pause(mode) {
        if (!nativeLook)
            return;
        const on = mode === "toggle" ? !paused : mode === "on";
        paused = on;
        if (!on) {
            Niri.action("SetCastPause", {
                "on": false
            });
            return;
        }
        pauseGen.command = ["python3", "-I", Quickshell.shellDir + "/scripts/privacy-look.py", "pause", lookDir + "/pause.png", _hex(Theme.text), _hex(Theme.accent), I18n.t("СКОРО ВЕРНУСЬ", "BE RIGHT BACK")];
        pauseGen.running = true;
    }
    Process {
        id: pauseGen
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.paused)
                    return;
                const png = text.trim();
                const args = {
                    "on": true,
                    "background": root._hex(Theme.desk)
                };
                if (png)
                    args.image = png;
                Niri.action("SetCastPause", args);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("Privacy pause:", text.trim())
        }
    }

    function _hex(c) {
        return "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
    }
    readonly property string _lookKey: JSON.stringify([Config.stream.privacyLook, Config.stream.privacyImage, appLooks, _hex(Theme.text), _hex(Theme.accent), _hex(Theme.desk)])
    on_LookKeyChanged: if (nativeLook)
        lookLater.restart()
    Timer {
        id: lookLater
        interval: 300
        onTriggered: root._drawLooks()
    }
    property var _pending: []                // [{app, look, png}]
    property var _sentApps: []               // app-ids niri has a look of their own for
    function _drawLooks() {
        if (lookGen.running) {
            lookLater.restart();
            return;
        }
        const entries = [{
                "app": "",
                "look": looks.includes(Config.stream.privacyLook) ? Config.stream.privacyLook : "plate",
                "image": Config.stream.privacyImage
            }];
        for (const id of Object.keys(appLooks)) {
            const e = appLook(id);
            if (e)
                entries.push({
                    "app": id,
                    "look": e.look,
                    "image": e.image || ""
                });
        }
        const jobs = [];
        entries.forEach((e, i) => {
            if (e.look === "image" && !e.image)
                e.look = "plate";
            if (e.look === "image") {
                e.png = lookDir + "/picture-" + i + ".png";
                jobs.push(["picture", e.png, e.image]);
            } else if (["plate", "cat", "angel"].includes(e.look)) {
                e.png = lookDir + "/" + e.look + ".png";
                if (!jobs.some(j => j[1] === e.png))
                    jobs.push([e.look, e.png, _hex(Theme.text), _hex(Theme.accent)]);
            }
        });
        _pending = entries;
        lookGen.command = ["python3", "-I", Quickshell.shellDir + "/scripts/privacy-look.py", "--batch", JSON.stringify(jobs)];
        lookGen.running = true;
    }
    Process {
        id: lookGen
        stdout: StdioCollector {
            onStreamFinished: root._sendLooks(text.split("\n").map(l => l.trim()).filter(l => l))
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("Privacy:", text.trim())
        }
    }
    function _sendLooks(drawn) {
        const apps = [];
        for (const e of _pending) {
            let look = e.look;
            // a picture that could not be drawn (the file is gone): the plate, or black without it
            if (e.png && !drawn.includes(e.png))
                look = drawn.includes(lookDir + "/plate.png") ? "plate" : "black";
            const png = look === e.look ? e.png : lookDir + "/plate.png";
            const args = {
                "look": ["plate", "cat", "angel", "image"].includes(look) ? "image" : look,
                "cell": 16,
                "cover": look === "image",
                "background": _hex(Theme.desk)
            };
            if (args.look === "image")
                args.image = png;
            if (e.app) {
                args.app_id = e.app;
                apps.push(e.app);
            }
            Niri.action("SetPrivacyLook", args);
        }
        for (const id of _sentApps)
            if (!apps.includes(id))
                Niri.action("SetPrivacyLook", {
                    "look": "default",
                    "app_id": id
                });
        _sentApps = apps;
    }
}
