pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The Golden Gate skin (Config.settingsUi.skin "goldengate"): the whole desktop like macOS 27
// for people coming from a Mac — the menu bar with the focused app's menus, the Dock, Spotlight,
// Control Center, System Settings, windows with traffic lights (modules/mac). This is its switch,
// its measures and its colours. The measures are Apple's (Human Interface Guidelines; the
// reference shots behind them: docs/GOLDEN-GATE.md) in logical pixels, grown with the font
// scale (Theme.fs). While the demon rules the skin stays, in a hell version of its own
// (`hell`): obsidian glass and blood — like every bar style has one.
Singleton {
    id: root

    // the skin is chosen (also while the first-run wizard holds the desktop)
    readonly property bool chosen: Config.ready && Config.settingsUi.skin === "goldengate"
    readonly property bool on: chosen
    readonly property bool hell: on && Angel.demon
    readonly property bool dark: hell || Theme.dark

    // ---- measures (HIG: menu bar 24 pt, body text 13 pt, menus 13 pt on 22 pt rows) ----
    readonly property real s: Theme.fs
    function px(v) {
        return Math.round(v * s);
    }
    readonly property int barHeight: px(24)
    readonly property int textSize: px(13)
    readonly property int smallSize: px(11)
    readonly property int menuRow: px(22)
    readonly property int menuRadius: px(12)
    readonly property int menuPad: px(5)            // the rounded highlight sits this far inside the menu
    readonly property int windowRadius: 16          // niri's geometry-corner-radius (logical px, not scaled)
    readonly property int panelRadius: px(26)       // Control Center, Notification Center, Spotlight's results
    readonly property int iconSize: px(16)

    // Inter (open, close to SF Pro) or Config.mac.font: Theme.macFont, which PxText uses too
    readonly property string font: Theme.macFont
    readonly property string monoFont: Theme.macMono

    // ---- colours ----
    // the accent of Appearance (macOS 26/27 values, Theme.macAccents); hell's own in hell
    readonly property color accent: hell ? Theme.hellAccent : Theme.macAccent
    readonly property color accentText: "#ffffff"
    readonly property color label: hell ? Theme.hellText : dark ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0, 0, 0, 0.86)
    readonly property color secondaryLabel: hell ? Theme.hellTextDim : dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
    readonly property color tertiaryLabel: dark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.26)
    readonly property color separator: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.1)
    readonly property color windowBg: hell ? Theme.hellBody : dark ? "#1e1e1e" : "#f5f5f5"
    readonly property color contentBg: hell ? Theme.hellFace : dark ? "#232323" : "#ffffff"
    readonly property color sidebarBg: hell ? Theme.hellSunken : dark ? "#2a2a2a" : "#e9e9e9"
    readonly property color groupBg: hell ? Theme.hellFaceAlt : dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.035)
    readonly property color controlBg: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color hoverBg: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.07)
    // Liquid Glass: the material of menus, the Dock, Control Center. Golden Gate's slider goes from
    // clear to tinted (Config.mac.glass); behind it niri's blur (BackgroundEffect)
    readonly property real tint: Math.max(0, Math.min(1, Config.mac.glass))
    function glass(extra) {
        // no blur behind it (Settings → blur off): nearly opaque, as macOS's Reduce Transparency —
        // clear glass over unblurred windows can't be read
        const a = (Config.appearance.blur ? 0.42 + tint * 0.5 : 0.9) + (extra || 0);
        return hell ? Qt.rgba(0.07, 0.03, 0.03, Math.min(0.97, a + 0.1)) : dark ? Qt.rgba(0.12, 0.12, 0.13, Math.min(0.97, a)) : Qt.rgba(0.97, 0.97, 0.975, Math.min(0.97, a));
    }
    readonly property color glassFill: glass(0)
    // a darker edge and a brighter highlight (Golden Gate's "more depth and separation")
    readonly property color glassEdge: hell ? Qt.alpha(Theme.hellBlood, 0.55) : dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.14)
    readonly property color glassHighlight: hell ? Qt.alpha(Theme.hellEmber, 0.35) : dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.75)
    readonly property color shadow: Qt.rgba(0, 0, 0, dark ? 0.5 : 0.22)
    // window title bars (modules/decor, Settings → Windows): the skin keeps its own set
    // (Config.mac.titlebars, decorSkip), the other skins Config.decor's — switching skins brings
    // back each one's
    readonly property bool titlebars: on ? Config.mac.titlebars : Config.decor.titlebars
    readonly property var decorSkip: on ? (Config.mac.decorSkip || []) : (Config.decor.skip || [])
    function setTitlebars(v) {
        if (on)
            Config.mac.titlebars = v;
        else
            Config.decor.titlebars = v;
    }
    function setDecorSkip(list) {
        if (on)
            Config.mac.decorSkip = list;
        else
            Config.decor.skip = list;
    }

    // the traffic lights (close, minimize, zoom) and their rims
    readonly property var lights: ["#ff5f57", "#febc2e", "#28c840"]
    readonly property var lightRims: ["#e0443e", "#dea123", "#1aab29"]

    // ---- Control Center ("cc") and Notification Center ("nc"): one of them open on one screen ----
    property string panel: ""
    property string panelScreen: ""
    function openPanel(kind, screenName) {
        Shell.closeTransient();
        panelScreen = screenName;
        panel = kind;
    }
    function closePanel() {
        panel = "";
    }
    function togglePanel(kind, screenName) {
        if (panel === kind && panelScreen === screenName)
            closePanel();
        else
            openPanel(kind, screenName);
    }
    Connections {
        target: Shell
        function onDismissMenus() {
            root.closePanel();
        }
    }

    // ---- what the skin puts on while it is chosen, and gives back after ----
    // (not in dev runs and tests: nothing is downloaded, nothing of yours changes)
    readonly property bool live: Config.ready && !Shell.dev
    // its fonts (scripts/fonts.py, pinned downloads): Inter, then JetBrains Mono — once a session
    property var fontsTried: []
    Timer {
        interval: 2500
        repeat: true
        running: root.on && root.live && Fonts.catalog.length > 0
        onTriggered: {
            if (Fonts.busy)
                return;
            const want = ["inter", "jetbrains-mono"].find(id => !Fonts.installed(id) && !root.fontsTried.includes(id));
            if (!want) {
                stop();
                // fresh fonts: GTK, Qt and the rest get them now (goldengate.py, qt-theme.py)
                if (root.fontsTried.length)
                    ThemeExport.apply();
                return;
            }
            root.fontsTried = root.fontsTried.concat([want]);
            Fonts.install(want);
        }
    }
    // its wallpaper (scripts/goldengate-wallpaper.py, drawn here once, light and dark): put on when
    // the skin is chosen, the light or dark one with the theme; the ones it replaced come back
    // when the skin goes — unless you picked another one meanwhile
    property var walls: ({})
    function ours(p) {
        return !!p && String(p).indexOf("/angelos/wallpapers/goldengate-") >= 0;
    }
    function putWallpaper() {
        if (!on || !live || !Config.mac.wallpaper || hell)
            return;
        const want = Theme.dark ? walls.dark : walls.light;
        if (!want)
            return;
        const w = Config.wallpaper;
        const before = Config.mac.wallBefore || {};
        const first = !before.saved;
        // the first time: what was there is kept; later only our own two swap with the theme
        if (first)
            Config.mac.wallBefore = {
                "saved": true,
                "fallback": w.fallback,
                "outputs": w.outputs,
                "workspaces": w.workspaces
            };
        else if (!ours(w.fallback) || Object.keys(w.outputs || {}).length || Object.keys(w.workspaces || {}).length)
            return;
        if (w.fallback !== want || Object.keys(w.outputs || {}).length || Object.keys(w.workspaces || {}).length)
            Wallpapers.setEverywhere(want);
    }
    function giveBackWallpaper() {
        const b = Config.mac.wallBefore || {};
        if (!b.saved)
            return;
        if (ours(Config.wallpaper.fallback)) {
            Config.wallpaper.fallback = b.fallback || "";
            Config.wallpaper.outputs = b.outputs || ({});
            Config.wallpaper.workspaces = b.workspaces || ({});
        }
        Config.mac.wallBefore = ({});
    }
    Process {
        id: wallMaker
        command: ["python3", Quickshell.shellDir + "/scripts/goldengate.py", "wallpapers"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.walls = JSON.parse(text);
                } catch (e) {}
                root.putWallpaper();
            }
        }
    }
    function arrive() {
        if (live && on && !wallMaker.running)
            wallMaker.running = true;
    }
    onOnChanged: {
        if (!on)
            closePanel();
        if (live) {
            if (on)
                arrive();
            else
                giveBackWallpaper();
        }
    }
    onLiveChanged: arrive()
    Component.onCompleted: arrive()
    Connections {
        target: Theme
        function onDarkChanged() {
            root.putWallpaper();
        }
    }
    Connections {
        target: Config.mac
        function onWallpaperChanged() {
            if (Config.mac.wallpaper)
                root.putWallpaper();
            else
                root.giveBackWallpaper();
        }
    }

    // ---- the menu bar's ink: black over a light wallpaper, white over a dark one ----
    // (it has no background of its own unless Config.mac.barBackground)
    property var barLight: ({})                  // screen name -> 0…1, from wallpaper-color.py --bar
    function barInk(screenName) {
        if (hell)
            return Theme.hellText;
        if (Config.mac.barBackground)
            return label;
        const l = barLight[screenName];
        return l === undefined ? (dark ? "#ffffff" : "#000000") : l > 0.6 ? Qt.rgba(0, 0, 0, 0.86) : "#ffffff";
    }
    function barBand(screenName) {
        return Config.mac.barBackground ? glass(0.1) : "transparent";
    }
    // which wallpaper is under each bar right now
    readonly property var barWalls: {
        if (!on)
            return [];
        const out = [];
        for (const sc of Shell.screens) {
            const ws = Niri.activeWorkspace(sc.name);
            const p = Wallpapers.resolve(sc.name, ws ? ws.idx : 1);
            if (p)
                out.push([sc.name, Wallpapers.display(p)]);
        }
        return out;
    }
    onBarWallsChanged: probeNext()
    property var _probing: null
    property var _probed: ({})                    // path -> lightness
    function probeNext() {
        if (probe.running)
            return;
        const next = {};
        let todo = null;
        for (const [name, path] of barWalls) {
            if (_probed[path] !== undefined)
                next[name] = _probed[path];
            else if (!todo)
                todo = [name, path];
        }
        barLight = next;
        if (todo) {
            _probing = todo;
            probe.command = ["python3", Quickshell.shellDir + "/scripts/wallpaper-color.py", todo[1], "--bar"];
            probe.running = true;
        }
    }
    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                const path = root._probing ? root._probing[1] : "";
                let v = 0.4;
                try {
                    v = JSON.parse(text).bar;
                } catch (e) {}
                const p = Object.assign({}, root._probed);
                p[path] = v;
                root._probed = p;
            }
        }
        onExited: Qt.callLater(root.probeNext)
    }
}
