pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// angelOS Alt+Tab (Settings → Windows → Alt+Tab): its own switcher in the
// angelOS, NEEDY GIRL OVERDOSE or Y2K style, or niri's native one with live
// previews ("niri").
//
// niri binds Alt+Tab / Alt+Shift+Tab to `angelos alttab next|prev` (the block
// in cfg/angelos-windows.kdl, scripts/window-config.py, with `recent-windows
// { off }`), which reaches the control socket in a few ms. niri keeps those
// binds while the switcher is up, so every Tab steps here; Alt being let go is
// read from the keyboards by scripts/alt-watch.py (niri has no release binds),
// Qt's own key release is the fallback. A quick Alt+Tab tap never shows the
// switcher: it only appears after `delayMs` while Alt is still held.
// Windows are in most-recently-used order: niri's focus timestamps, then every
// focus change moves a window to the front.
// ⌘Tab of the Golden Gate skin's Mac keys (`angelos alttab apps|appsback`) is the same switcher
// in `mode` "apps": one item per app, every desktop, held by ⌘ (the Windows key) instead of Alt;
// ⌘` (`angelos alttab appwin|appwinback`) steps through the front app's windows at once.
// With the Mac keys in front (KeyProfile "macos") Alt+Tab is not bound at all — the block keeps
// niri's own switcher off but leaves Alt(Option)+Tab to the apps, as on a Mac.
Singleton {
    id: root

    readonly property var styles: [
        {
            "id": "angelos",
            "label": "angelOS",
            "hint": I18n.t("пиксельное окошко " + I18n.exe("alt+tab") + " в цветах темы, выбранное — в розовой рамке с сердечком", "a pixel " + I18n.exe("alt+tab") + " window in the theme colours, the pick framed in pink with a heart")
        },
        {
            "id": "ngo",
            "label": "NEEDY GIRL OVERDOSE",
            "hint": I18n.t("окно Windose: пастельные полоски, клетчатый фон, скачущее сердце над выбранным и реплики Ame", "a Windose window: pastel stripes, a checkered back, a heart bouncing over the pick and Ame's lines")
        },
        {
            "id": "y2k",
            "label": "Y2K ✧",
            "hint": I18n.t("глянцевая хромированная панель-пузырь, радужные карточки и мерцающие звёздочки", "a glossy chrome bubble panel, iridescent cards and twinkling sparkles")
        },
        {
            "id": "niri",
            "label": I18n.t("Как в niri", "niri's own"),
            "hint": I18n.t("встроенный переключатель niri с живыми превью окон", "niri's built-in switcher with live window previews")
        }
    ]
    readonly property string style: styles.some(s => s.id === Config.alttab.style) ? Config.alttab.style : "angelos"
    readonly property bool ours: style !== "niri"

    // ---- most recently used ----
    property var mru: []                     // window ids, the focused one first
    function _seed() {
        const ts = w => w.focus_timestamp ? w.focus_timestamp.secs * 1e3 + w.focus_timestamp.nanos / 1e6 : 0;
        const sorted = Niri.windows.slice().sort((a, b) => (b.is_focused - a.is_focused) || ts(b) - ts(a) || b.id - a.id);
        mru = sorted.map(w => w.id);
    }
    Connections {
        target: Niri
        function onFocusedWindowIdChanged() {
            // cycling does not focus anything; only the pick does, at the end
            if (Niri.focusedWindowId >= 0)
                root.mru = [Niri.focusedWindowId].concat(root.mru.filter(id => id !== Niri.focusedWindowId));
        }
        function onWindowsChanged() {
            const ids = Niri.windows.map(w => w.id);
            if (!root.mru.length) {
                root._seed();
                return;
            }
            const known = root.mru.filter(id => ids.includes(id));
            const fresh = ids.filter(id => !known.includes(id));
            if (fresh.length || known.length !== root.mru.length)
                root.mru = known.concat(fresh);
        }
    }
    Component.onCompleted: _seed()

    // the windows to cycle through, in MRU order
    function candidates() {
        const byId = {};
        for (const w of Niri.windows)
            byId[w.id] = w;
        let list = mru.map(id => byId[id]).filter(w => !!w);
        for (const w of Niri.windows)
            if (!list.includes(w))
                list.push(w);
        if (Config.alttab.scope === "workspace") {
            const ws = Niri.activeWorkspace(Niri.focusedOutput);
            list = list.filter(w => ws && w.workspace_id === ws.id);
        } else if (Config.alttab.scope === "output") {
            list = list.filter(w => {
                const ws = Niri.workspaceById(w.workspace_id);
                return ws && ws.output === Niri.focusedOutput;
            });
        }
        return list;
    }

    // ---- the switcher ----
    property string mode: "windows"          // windows (Alt+Tab) | apps (⌘Tab)
    property bool active: false              // cycling (Alt held)
    property bool shown: false               // the switcher is on screen
    property bool demo: false                // settings "Try it": plays by itself, focuses nothing
    property var items: []
    property int index: 0
    property string screenName: ""
    readonly property var current: items[index] || null
    property int serial: 0                   // bumps per open (the window restarts its intro)

    function step(dir) {
        if (!ours || Shell.locked || Shell.setupLocked)
            return;
        if (!active) {
            const list = candidates();
            if (list.length === 0)
                return;
            mode = "windows";
            items = list;
            index = list.length === 1 ? 0 : (dir < 0 ? list.length - 1 : 1);
            screenName = Niri.focusedOutput;
            demo = false;
            active = true;
            serial++;
            watcher.running = false;
            watcher.running = true;
            showTimer.restart();
            guard.restart();
            return;
        }
        if (items.length)
            index = (index + (dir < 0 ? -1 : 1) + items.length) % items.length;
        guard.restart();
        if (!shown && !demo && watcherSaid === "down")
            reveal();
    }
    // ---- ⌘Tab: the apps ----
    // {id, appId, name, icon, entry, windows (most recent first)} per app id, the app used last first
    function appCandidates() {
        const byId = {};
        for (const w of Niri.windows)
            byId[w.id] = w;
        const wins = mru.map(id => byId[id]).filter(w => !!w);
        for (const w of Niri.windows)
            if (!wins.includes(w))
                wins.push(w);
        const out = [];
        const at = {};
        for (const w of wins) {
            const key = String(w.app_id || "");
            if (!key)
                continue;
            if (at[key] === undefined) {
                const e = DesktopEntries.byId(key) || DesktopEntries.heuristicLookup(key);
                at[key] = out.length;
                out.push({
                    "kind": "app",
                    "id": e ? e.id : key,
                    "appId": key,
                    "entry": e,
                    "name": e && e.name ? e.name : AppMenu.prettyName(key),
                    "icon": e ? e.icon : key,
                    "windows": []
                });
            }
            out[at[key]].windows.push(w);
        }
        return out;
    }
    function stepApps(dir) {
        if (Shell.locked || Shell.setupLocked)
            return;
        if (!active) {
            const list = appCandidates();
            if (list.length === 0)
                return;
            mode = "apps";
            items = list;
            index = list.length === 1 ? 0 : (dir < 0 ? list.length - 1 : 1);
            screenName = Niri.focusedOutput;
            demo = false;
            active = true;
            serial++;
            watcher.running = false;
            watcher.running = true;
            showTimer.restart();
            guard.restart();
            return;
        }
        if (items.length)
            index = (index + (dir < 0 ? -1 : 1) + items.length) % items.length;
        guard.restart();
        if (!shown && !demo && watcherSaid === "down")
            reveal();
    }
    // the app to the front: back from ⌘H if hidden, its last used window, else its last
    // minimized one out of the Dock
    function activateApp(app, output) {
        if (!app || !app.windows)
            return;
        const ids = app.windows.map(w => w.id);
        const live = Niri.windows.filter(w => ids.includes(w.id));
        if (!live.length)
            return;
        if (live.some(w => Minimize.isAppHidden(w))) {
            Minimize.unhide(app.appId, -1, output || "");
            return;
        }
        const ts = w => w.focus_timestamp ? w.focus_timestamp.secs * 1e9 + w.focus_timestamp.nanos : 0;
        const shown = live.filter(w => !Minimize.isMinimized(w)).sort((a, b) => ts(b) - ts(a));
        if (shown.length) {
            if (shown[0].id !== Niri.focusedWindowId)
                Niri.focusWindow(shown[0].id);
            return;
        }
        const m = Minimize.windows.filter(w => ids.includes(w.id));
        Minimize.restore((m[m.length - 1] || live[0]).id, false, output || "");
    }
    // ⌘Q / ⌘H while ⌘Tab is up act on the app picked there (macOS does so)
    readonly property var pickedApp: active && mode === "apps" ? current : null
    // ⌘`: the next window of the app in front, at once (minimized and hidden ones are skipped)
    function cycleAppWindows(dir) {
        if (Shell.locked || Shell.setupLocked)
            return;
        const f = Niri.focusedWindow;
        if (!f)
            return;
        const mine = Niri.windows.filter(w => w.app_id === f.app_id && !Minimize.isMinimized(w)).sort((a, b) => a.id - b.id);
        if (mine.length < 2)
            return;
        const i = mine.findIndex(w => w.id === f.id);
        Niri.focusWindow(mine[(i + (dir < 0 ? -1 : 1) + mine.length) % mine.length].id);
    }
    function select(i) {
        if (active && i >= 0 && i < items.length)
            index = i;
    }
    // Alt went up (or Enter, or a click): focus the pick
    function commit() {
        if (!active)
            return;
        const w = current, wasDemo = demo, apps = mode === "apps", out = screenName;
        close();
        if (!w || wasDemo)
            return;
        if (apps)
            activateApp(w, out);
        else if (w.id !== Niri.focusedWindowId)
            Niri.focusWindow(w.id);
    }
    function cancel() {
        close();
    }
    function close() {
        active = false;
        shown = false;
        demo = false;
        showTimer.stop();
        guard.stop();
        demoTimer.stop();
        watcher.running = false;
        watcherSaid = "";
        mode = "windows";
    }
    function reveal() {
        if (active && !shown)
            shown = true;
    }
    // Settings → "Try it": the switcher cycles by itself for a few seconds
    function tryIt(styleId) {
        if (styleId)
            Config.alttab.style = styleId;
        if (!ours)
            return;
        const list = candidates();
        items = list.length ? list : [];
        if (!items.length)
            return;
        close();
        index = items.length > 1 ? 1 : 0;
        screenName = Niri.focusedOutput;
        demo = true;
        active = true;
        shown = true;
        serial++;
        demoTimer.steps = 0;
        demoTimer.restart();
    }
    Timer {
        id: demoTimer
        property int steps: 0
        interval: 520
        repeat: true
        onTriggered: {
            if (++steps > 6) {
                root.close();
                return;
            }
            root.index = (root.index + 1) % Math.max(1, root.items.length);
        }
    }
    // shows up only while Alt is still held after a moment: a quick tap just switches
    Timer {
        id: showTimer
        interval: Math.max(0, Config.alttab.delayMs)
        onTriggered: {
            // without the keyboard watcher there is no way to tell: show it
            if (root.watcherSaid === "down" || root.watcherSaid === "" && !watcher.running || root.watcherSaid === "noperm")
                root.reveal();
            else if (watcher.running && root.watcherSaid === "")
                restart();       // the watcher has not answered yet: check again shortly
        }
    }
    // a lost release (a crash of the watcher, focus stolen) never leaves it hanging
    Timer {
        id: guard
        interval: 30000
        onTriggered: root.cancel()
    }

    property string watcherSaid: ""          // down | up | noperm
    property string watcherStatus: ""        // last non-empty answer, for the settings page
    Process {
        id: watcher
        // ⌘Tab waits for ⌘ (the Windows key), Alt+Tab for Alt
        command: ["python3", Quickshell.shellDir + "/scripts/alt-watch.py", "--timeout", "30"].concat(root.mode === "apps" ? ["--mod", "meta"] : [])
        stdout: SplitParser {
            onRead: line => {
                const l = line.trim();
                root.watcherSaid = l;
                if (l !== "down")
                    root.watcherStatus = l;
                if (l === "up" && root.active && !root.demo)
                    root.commit();
                else if (l === "down" && root.active && !showTimer.running)
                    root.reveal();
                else if (l === "noperm")
                    root.reveal();
            }
        }
        onExited: code => {
            if (code !== 0 && root.watcherSaid === "" && root.active)
                root.reveal();
        }
    }

    // ---- the niri side: binds + recent-windows off, or back to niri's own ----
    // true (Alt+Tab → the shell) | false (niri's own) | "mac" (no Alt+Tab, ⌘Tab is the switcher)
    readonly property var niriWant: KeyProfile.want === "macos" ? "mac" : ours
    property var niriRouted: false           // what cfg/angelos-windows.kdl holds now
    property var writing: false              // what the writer is putting there
    property bool niriRead: false
    property string log: ""
    function apply() {
        if (Shell.dev || writer.running)
            return;
        writing = niriWant;
        writer.command = ["python3", Quickshell.shellDir + "/scripts/window-config.py", JSON.stringify({
                "alttab": writing
            })];
        writer.running = true;
    }
    function sync() {
        if (Config.ready && niriRead && niriRouted !== niriWant)
            apply();
    }
    onNiriWantChanged: sync()
    Connections {
        target: Config
        function onReadyChanged() {
            root.sync();
        }
    }
    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/window-config.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const a = JSON.parse(text).alttab;
                    root.niriRouted = a === "mac" ? "mac" : !!a;
                    root.niriRead = true;
                    root.sync();
                } catch (e) {}
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: root.log = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.log = text.trim().split("\n").slice(-1)[0]
        }
        onExited: code => {
            if (code !== 0)
                return;
            root.niriRouted = root.writing;
            root.sync();                     // the style or the theme changed while writing
        }
    }
}
