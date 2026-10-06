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
    // Liquid Glass: the material of the menu bar's menus, the Dock, Control Center, Spotlight, the
    // banners and the widgets. Golden Gate's slider goes from clear to tinted (Config.mac.glass).
    // Behind it niri blurs and saturates what is under the surface (BackgroundEffect +
    // templates/niri-mac.kdl's layer rule); over the tint a static shader draws the rim — the edge
    // highlight and the lens's light (shaders/liquid_glass.frag, widgets/MacGlass).
    readonly property real tint: Math.max(0, Math.min(1, Config.mac.glass))
    // "Reduce transparency" (Accessibility, like macOS's): solid tint, no blur, no rim effect
    readonly property bool reduceTransparency: Config.ready && Config.mac.reduceTransparency
    // niri-game-mode is on (a fullscreen window; cfg/game-mode.kdl "effects off"): it turns niri's
    // blur off for angelOS's layers too, the glass goes solid and the shader is unloaded
    property bool gameMode: false
    FileView {
        path: Config.home + "/.config/niri/cfg/game-mode.kdl"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.gameMode = text().indexOf("effects off") >= 0
        onLoadFailed: root.gameMode = false
    }
    // the glass itself (clear, rim, saturation) — else the solid fallback
    readonly property bool glassFx: on && !reduceTransparency && !gameMode && !hell
    // ask niri for blur behind Golden Gate's surfaces
    readonly property bool blurOn: Config.appearance.blur && !reduceTransparency && !gameMode
    function glass(extra) {
        // no blur behind it (Settings → blur off, Reduce transparency, game mode): nearly opaque, as
        // macOS's Reduce Transparency — clear glass over unblurred windows can't be read
        const a = (blurOn ? 0.26 + tint * 0.62 : 0.94) + (extra || 0);
        return hell ? Qt.rgba(0.07, 0.03, 0.03, Math.min(0.97, a + 0.1)) : dark ? Qt.rgba(0.12, 0.12, 0.13, Math.min(0.97, a)) : Qt.rgba(0.97, 0.97, 0.975, Math.min(0.97, a));
    }
    readonly property color glassFill: glass(0)

    // ---- the skin's settings: their limits, and "Reset the theme" (Settings → Appearance) ----
    // every number has a range and every choice a list (Settings shows the same ones): a value out
    // of them — settings.json edited by hand, an older version — goes back into them, never to 0
    readonly property var limits: ({
            "mac.glass": [0, 1],
            "mac.soundVolume": [0, 1],
            "mac.dockSize": [32, 96],
            "mac.dockMagnifySize": [32, 128],
            "appearance.fontScale": [1, 2],
            "appearance.lightFrom": [0, 23],
            "appearance.darkFrom": [0, 23]
        })
    readonly property var choices: ({
            "mac.accent": ["blue", "purple", "pink", "red", "orange", "yellow", "green", "graphite"],
            "mac.minimizeEffect": ["genie", "scale"],
            "mac.dockPosition": ["bottom", "left", "right"],
            "appearance.mode": ["light", "dark", "auto"],
            "desktop.widgetStyle": ["auto", "pixel", "mac"]
        })
    // the screen edge the Dock stands on
    readonly property string dockEdge: choices["mac.dockPosition"].includes(Config.mac.dockPosition) ? Config.mac.dockPosition : "bottom"
    function sanitize() {
        if (!Config.ready)
            return;
        const fix = (path, v) => {
            const [sec, key] = path.split(".");
            if (JSON.stringify(Config[sec][key]) !== JSON.stringify(v))
                Config[sec][key] = v;
        };
        for (const path in limits) {
            const [sec, key] = path.split(".");
            const [lo, hi] = limits[path];
            const v = Number(Config[sec][key]);
            fix(path, isFinite(v) ? Math.max(lo, Math.min(hi, v)) : Config.defaultOf(path));
        }
        if (Config.mac.dockMagnifySize < Config.mac.dockSize)
            Config.mac.dockMagnifySize = Config.mac.dockSize;
        for (const path in choices) {
            const [sec, key] = path.split(".");
            if (!choices[path].includes(Config[sec][key]))
                fix(path, Config.defaultOf(path));
        }
    }
    // (any of them changed, also from the file: checked once things settle)
    readonly property string _watched: Config.ready ? JSON.stringify([Config.mac.glass, Config.mac.soundVolume, Config.mac.dockSize, Config.mac.dockMagnifySize, Config.mac.accent, Config.mac.minimizeEffect, Config.mac.dockPosition, Config.appearance.mode, Config.appearance.fontScale, Config.desktop.widgetStyle]) : ""
    on_WatchedChanged: if (_watched)
        Qt.callLater(sanitize)
    // what "Reset the theme" puts back: what the skin's own pages show (Dock, Appearance,
    // Wallpaper, Widgets' style, Windows, the Mac keys). The apps kept in the Dock stay (they are
    // yours, not a setting: Dock → "Reset the order"), and so does the skin itself
    readonly property var themeKeys: ["mac.glass", "mac.accent", "mac.barBackground", "mac.appMenus", "mac.keys", "mac.floating", "mac.minimizeEffect", "mac.dockSize", "mac.dockMagnify", "mac.dockMagnifySize", "mac.dockMacIcons", "mac.dockAutohide", "mac.dockPosition", "mac.font", "mac.wallpaper", "mac.reduceTransparency", "mac.sounds", "mac.soundVolume", "mac.volumeSound", "appearance.mode", "appearance.lightFrom", "appearance.darkFrom", "appearance.blur", "appearance.fontScale", "desktop.widgetStyle"]
    function resetTheme() {
        return Config.resetKeys(themeKeys);
    }
    // the apps' own minimize buttons reach angelOS (extras/minimize-hook, Settings → Windows)
    property bool hookInstalled: false
    Process {
        running: true
        command: ["sh", "-c", '[ -f "$HOME/.local/lib/angelos/lib/libangelos-minimize.so" ] && echo yes || echo no']
        stdout: SplitParser {
            onRead: line => root.hookInstalled = line === "yes"
        }
    }
    // a darker edge and a brighter highlight (Golden Gate's "more depth and separation")
    readonly property color glassEdge: hell ? Qt.alpha(Theme.hellBlood, 0.55) : dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.14)
    readonly property color glassHighlight: hell ? Qt.alpha(Theme.hellEmber, 0.35) : dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.75)
    readonly property color shadow: Qt.rgba(0, 0, 0, dark ? 0.5 : 0.22)

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
    // ---- wallpapers: every theme keeps its own ----
    // The pixel theme and Golden Gate each have their own set — one picture everywhere, per monitor
    // or per desktop (Config.wallpaper.themes.pixel / .mac). Config.wallpaper's fallback/outputs/
    // workspaces are the set of the theme in front (Config.wallpaper.themeOf): switching the skin
    // saves them into that theme's slot and puts the other theme's back, so a picture chosen in one
    // never moves into the other. Golden Gate without a set of its own yet gets its wallpaper
    // (scripts/goldengate.py wallpapers, light and dark, Config.mac.wallpaper); that one follows
    // light and dark as long as you keep it. Hell's wallpaper is the save's (services/Wallpapers),
    // untouched here.
    readonly property string wallTheme: chosen ? "mac" : "pixel"
    readonly property string _wallKey: live ? wallTheme : ""
    // Config.ready turns true a moment before the file's values are in: settle first
    on_WallKeyChanged: if (_wallKey)
        wallSettle.restart()
    Timer {
        id: wallSettle
        interval: 400
        onTriggered: if (root._wallKey)
            root.swapWalls()
    }
    property var walls: ({})
    property bool _wantDefault: false       // Golden Gate came without a set of its own: its picture
    function ours(p) {
        return !!p && String(p).indexOf("/angelos/wallpapers/goldengate-") >= 0;
    }
    function _set(w) {
        return {
            "fallback": w.fallback || "",
            "outputs": w.outputs || ({}),
            "workspaces": w.workspaces || ({})
        };
    }
    function _same(a, b) {
        return JSON.stringify(_set(a)) === JSON.stringify(_set(b));
    }
    function swapWalls() {
        const was = Config.wallpaper.themeOf || "";
        const now = wallTheme;
        if (was === now)
            return;
        const themes = Object.assign({}, Config.wallpaper.themes || {});
        if (!was) {
            // the first time (settings from before per-theme wallpapers): what the screens show is
            // the set of the theme in front; the pixel set Golden Gate kept aside (mac.wallBefore)
            // is the pixel theme's
            const b = Config.mac.wallBefore || {};
            if (b.saved && !themes.pixel)
                themes.pixel = _set(b);
            if (!themes[now] && !(now === "mac" && ours(Config.wallpaper.fallback)) && Config.wallpaper.fallback)
                themes[now] = _set(Config.wallpaper);
        } else {
            themes[was] = _set(Config.wallpaper);
        }
        Config.wallpaper.themes = themes;
        Config.wallpaper.themeOf = now;
        if (Config.mac.wallBefore && Config.mac.wallBefore.saved)
            Config.mac.wallBefore = ({});
        const mine = themes[now];
        if (mine) {
            _wantDefault = false;
            if (!_same(mine, Config.wallpaper)) {
                Config.wallpaper.fallback = mine.fallback;
                Config.wallpaper.outputs = mine.outputs;
                Config.wallpaper.workspaces = mine.workspaces;
            }
        } else if (now === "mac") {
            _wantDefault = true;
            putWallpaper();
        }
    }
    // Golden Gate's own picture: on a theme without a set of its own (or when the switch is turned
    // on), else only the light one and the dark one swap with the theme while it is still in place
    function putWallpaper() {
        if (!on || !live || !Config.mac.wallpaper || hell)
            return;
        const want = Theme.dark ? walls.dark : walls.light;
        if (!want)
            return;
        const w = Config.wallpaper;
        const plain = !Object.keys(w.outputs || {}).length && !Object.keys(w.workspaces || {}).length;
        if (!_wantDefault && !(ours(w.fallback) && plain))
            return;
        _wantDefault = false;
        if (w.fallback !== want || !plain) {
            // the skin's own picture, not the player's pick (no achievement)
            Achievements.mute++;
            Wallpapers.setEverywhere(want);
            Achievements.mute--;
        }
    }
    // the switch turned off while Golden Gate's picture is on: the pixel theme's set as a start
    function giveBackWallpaper() {
        if (!on || !live || !ours(Config.wallpaper.fallback))
            return;
        const px = (Config.wallpaper.themes || {}).pixel;
        if (!px)
            return;
        Config.wallpaper.fallback = px.fallback;
        Config.wallpaper.outputs = px.outputs;
        Config.wallpaper.workspaces = px.workspaces;
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
        if (live && on)
            arrive();
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
            if (Config.mac.wallpaper) {
                root._wantDefault = true;
                root.putWallpaper();
            } else {
                root.giveBackWallpaper();
            }
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
