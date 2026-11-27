pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// serp skin (after frostpix's pc-kit): the Serpantinum skin of angelOS — Config.settingsUi.skin "serp".
// Its own chrome (modules/serp: islands bar, dock, panels, settings) over angelOS's own Strip,
// windows, Halo, angel and hell. Everything the skin keeps for itself lives in serp.json (not in
// settings.json): the palette, the font, the radius, the bar and the dock. Here: the switch, the
// settings, the colour roles (Serpantinum's: base / mantle / surface0-2 / text / subtext / accent…)
// from a preset or from the wallpaper, the measures, and which panel is open where.
Singleton {
    id: root

    // Built very early (services/Skin, read by every plugin, asks for it): at that moment it may
    // touch only Config and Theme — Halo, Shell, Niri and Wallpapers are asked a moment later
    // (`awake`), else they were built in the middle of other singletons and those threw
    // ("Heaven.has is not a function"… at the shell's start, 2026-11-13)
    property bool awake: false
    Timer {
        interval: 1
        running: true
        onTriggered: root.awake = true
    }

    // ---- the switch ----
    // not inside the capture overlay's own Quickshell (circle-root): nothing of the skin is drawn
    // there, and its services would start work (and sockets) in that second process
    readonly property bool isCircle: Quickshell.shellDir.indexOf("circle-root") >= 0
    readonly property bool on: Config.ready && Config.settingsUi.skin === "serp" && !isCircle
    readonly property bool hell: on && Theme.hell
    function setSkin(s) {
        GoldenGate.setSkin(s);   // the skin-morph plugin animates only Classic <-> Golden Gate
    }

    // ---- the skin's own settings (serp.json) ----
    readonly property alias cfg: cfg
    FileView {
        id: cfgFile
        path: Config.dir + "/serp.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: cfg
            // look
            property string palette: "wallpaper"     // wallpaper | a preset's id (palettes below)
            property string font: "Adwaita Mono"
            property int radius: 10                  // corners of islands, panels, cards
            property real opacity: 0.92              // of the islands and panels
            property bool blur: true
            property bool glass: false               // Serpantinum's liquid glass (the wallpaper refracted) instead of flat
            property real glassTint: 0.35            // 0 clear … 1 tinted
            // bar
            property string barLayout: "islands"     // islands | full (one band)
            property bool barSeconds: true
            property bool barWeather: true
            property bool barMedia: true             // the now-playing chip in the left island
            property string deskStyle: "pills"       // pills | numbers
            // dock
            property bool dock: true
            property int dockSize: 44                // icons, logical px
            property bool dockAutohide: false
            property bool dockMagnify: true
            property var dockApps: []                // desktop ids; empty: Start's pinned apps
            property bool dockRunning: true          // running apps that aren't pinned come after a separator
            // notifications: where the cards come out (angelOS's corners)
            property string notifPosition: "top-right"
        }
    }

    // ---- measures ----
    readonly property real s: Theme.fs
    function px(v) {
        return Math.round(v * s);
    }
    readonly property int radius: px(cfg.radius)
    readonly property int radiusSmall: px(Math.max(4, cfg.radius - 4))
    // the islands stand where angelOS's Halo stands (HaloWindow: the float look's pill is u·4 from
    // the edge and px(16) tall, px = its size step × the art pixel) — one line across the top
    // not in circle-root: Halo there brings half the shell and its helpers up a second time
    readonly property bool haloFloat: awake && !isCircle && Halo.skin === "float"
    readonly property int barGap: haloFloat ? Theme.u * 4 : px(8)
    readonly property int barPill: haloFloat ? Math.round(16 * Halo.scale) * Theme.u : px(28)
    readonly property int barHeight: barGap + barPill          // the zone the bar keeps
    readonly property bool dockAutohideOn: cfg.dockAutohide || Config.bar.autoHide
    property int zoneNow: -1          // what SerpZone keeps now (for `serp status`)
    readonly property string font: fontOk(cfg.font) ? cfg.font : Theme.macMono
    readonly property int textSize: px(13)
    readonly property int smallSize: px(11)
    readonly property int iconSize: px(16)
    function fontOk(f) {
        return !!f && Qt.fontFamilies().indexOf(f) >= 0;
    }
    // Serpantinum's motion: 250 ms OutCubic for most, 380-400 ms OutQuint for shapes that stretch
    readonly property int quick: 150
    readonly property int normal: 250
    readonly property int slow: 400

    // ---- colours ----
    // Serpantinum's roles (Catppuccin names): base mantle crust / text subtext0 subtext1 /
    // surface0-2 overlay0 / mauve (the accent) blue red green yellow peach teal pink. Its 94
    // presets come along in data/palettes.json; "wallpaper" is its matugen idea done with
    // angelOS's own quantizer; "angel" is ours.
    property var palettes: ({})
    FileView {
        path: Quickshell.shellDir + "/modules/serp/data/palettes.json"
        printErrors: false
        onLoaded: {
            try {
                const p = JSON.parse(text());
                p["angel"] = root.angelPalette;
                root.palettes = p;
            } catch (e) {}
        }
    }
    readonly property var angelPalette: ({
            "name": "angelOS",
            "base": "#12101a", "mantle": "#0c0a12", "crust": "#07060b",
            "text": "#f1ecff", "subtext0": "#a79fc2", "subtext1": "#c9c2e0",
            "surface0": "#1d1a28", "surface1": "#272336", "surface2": "#322d44", "overlay0": "#5d5675",
            "mauve": "#f4c2e8", "blue": "#b4befe", "red": "#f38ba8", "green": "#a6e3a1",
            "yellow": "#f9e2af", "peach": "#fab387", "teal": "#94e2d5", "pink": "#f5c2e7"
        })
    readonly property var paletteIds: Object.keys(palettes).sort((x, y) => palettes[x].name.localeCompare(palettes[y].name))

    // the picture on the primary screen's active desk (the settings' preview)
    readonly property string wallFile: {
        if (!on || !awake)
            return "";
        clock.tick;
        const scr = Shell.primaryName;
        const ws = Niri.activeWorkspace(scr);
        // what the background really draws: a scene's day or night still, else the picture
        const p = Wallpapers.still(Wallpapers.resolve(scr, ws ? ws.idx : 1), new Date());
        return p ? (p.startsWith("file://") ? p : "file://" + p) : "";
    }
    Timer {
        id: clock
        property int tick: 0
        interval: 10 * 60 * 1000
        running: root.on
        repeat: true
        onTriggered: tick++
    }
    // "Обои": angelOS's OWN wallpaper colours (Appearance → colours from the wallpaper:
    // PaletteGenerator → Theme), laid out in Serpantinum's roles — the panels match the rest of
    // the desktop. The grounds go deep (Serpantinum's base is darker than its cards), the accents
    // keep their hue and are lifted to read on dark.
    function lift(c, l) {
        c = Qt.color(c);
        return c.hslLightness >= l ? c : Qt.hsla(Math.max(0, c.hslHue), Math.max(c.hslSaturation, 0.35), l, 1);
    }
    readonly property color wallAccent: Theme.accent
    readonly property var wallPalette: ({
            "name": "Обои",
            "base": Theme.mix(Theme.face, "#000000", 0.5), "mantle": Theme.mix(Theme.face, "#000000", 0.62), "crust": Theme.mix(Theme.face, "#000000", 0.78),
            "text": Theme.dark ? Theme.text : "#ececf0", "subtext0": lift(Theme.textDim, 0.6), "subtext1": lift(Theme.mix(Theme.textDim, Theme.text, 0.5), 0.72),
            "surface0": Theme.mix(Theme.face, "#000000", 0.25), "surface1": Theme.mix(Theme.face, "#000000", 0.1), "surface2": Theme.mix(Theme.faceAlt, Theme.text, 0.1), "overlay0": Theme.mix(Theme.faceAlt, Theme.text, 0.3),
            "mauve": lift(Theme.accent, 0.66), "blue": lift(Theme.accent2, 0.7), "red": lift(Theme.danger, 0.66), "green": lift(Theme.ok, 0.66),
            "yellow": lift(Theme.title2, 0.72), "peach": lift(Theme.accent3, 0.7), "teal": lift(Theme.accent4, 0.66), "pink": lift(Theme.mix(Theme.accent, Theme.accent2, 0.5), 0.72)
        })
    readonly property var hellPalette: ({
            "name": "Ад",
            "base": Theme.hellBody, "mantle": Theme.hellSunken, "crust": "#000000",
            "text": Theme.hellText, "subtext0": Theme.hellTextDim, "subtext1": Theme.hellTextDim,
            "surface0": Theme.hellFace, "surface1": Theme.hellFaceAlt, "surface2": Theme.hellPlate, "overlay0": Theme.hellRim,
            "mauve": Theme.hellAccent, "blue": Theme.hellEmber, "red": Theme.hellBlood, "green": Theme.hellGold,
            "yellow": Theme.hellGold, "peach": Theme.hellFlame, "teal": Theme.hellFlame, "pink": Theme.hellEmber
        })
    readonly property var pal: hell ? hellPalette : cfg.palette === "wallpaper" ? wallPalette : palettes[cfg.palette] || (cfg.palette === "angel" ? angelPalette : wallPalette)
    function paletteOf(id) {
        return id === "wallpaper" ? wallPalette : palettes[id] || angelPalette;
    }

    readonly property color base: pal.base
    readonly property color mantle: pal.mantle
    readonly property color crust: pal.crust
    readonly property color text: pal.text
    readonly property color subtext0: pal.subtext0
    readonly property color subtext1: pal.subtext1
    readonly property color subtext: pal.subtext0
    readonly property color surface0: pal.surface0
    readonly property color surface1: pal.surface1
    readonly property color surface2: pal.surface2
    readonly property color overlay: pal.overlay0
    readonly property color mauve: pal.mauve
    readonly property color accent: pal.mauve
    readonly property color onAccent: pal.crust
    readonly property color red: pal.red
    readonly property color green: pal.green
    readonly property color yellow: pal.yellow
    readonly property color blue: pal.blue
    readonly property color peach: pal.peach
    readonly property color teal: pal.teal
    readonly property color pink: pal.pink
    readonly property color ground: glassOn ? Qt.alpha(base, 0.06) : Qt.alpha(base, Math.max(0.5, Math.min(1, cfg.opacity)))
    readonly property color hover: Qt.alpha(text, 0.08)
    readonly property color selected: Qt.alpha(accent, 0.2)
    readonly property color line: Qt.alpha(text, 0.08)
    readonly property bool blurOn: cfg.blur && Config.appearance.blur && !glassOn   // the liquid glass replaces niri's blur
    // liquid glass: on, not in hell, not while a game runs (niri-game-mode turns effects off)
    readonly property bool glassOn: on && cfg.glass && !hell && !GoldenGate.gameMode
    // a plate that stays readable whatever the glass (menus over windows: the plugins' popovers)
    readonly property color solid: Qt.alpha(base, Math.max(0.9, cfg.opacity))
    // the desktop widgets' card: no refraction there (the wallpaper itself is behind), a frosted
    // tint instead (MacWidgetCard's wallpaper blur) while the glass is on
    readonly property color cardFill: glassOn ? Qt.alpha(base, 0.35 + cfg.glassTint * 0.4) : ground

    // ---- panels: one open at a time, on one screen ----
    property string panel: ""          // "" | quick | media | calendar | notifs | eq
    property string panelScreen: ""
    property string panelTab: ""       // the net panel's tab: wifi | bt
    function openPanel(kind, screenName, tab) {
        Shell.closeTransient();
        panelTab = tab || "";
        panel = kind;
        panelScreen = screenName || Niri.focusedOutput || Shell.primaryName;
    }
    function closePanel() {
        panel = "";
    }
    function togglePanel(kind, screenName, tab) {
        if (panel === kind && panelScreen === (screenName || panelScreen) && (!tab || tab === panelTab))
            closePanel();
        else
            openPanel(kind, screenName, tab);
    }
    function isOpen(kind, screenName) {
        return panel === kind && panelScreen === screenName;
    }
    Connections {
        target: root.awake ? Shell : null
        function onDismissMenus() {
            root.closePanel();
        }
    }
    onOnChanged: if (!on)
        closePanel()

    // ---- the playing track's clock, one for everything that turns with it (the music widget's
    // disc in its face and its hover copy alike): it only goes forward, and takes the player's
    // position again only on a real jump (a seek, a new track) — the player reports it a little
    // late, and taking it every second turned the disc back a hair each time ----
    property int mediaUsers: 0
    property real mediaPos: 0
    property real mediaAt: Date.now()
    property real mediaTick: Date.now()
    readonly property bool mediaPlaying: !isCircle && Lyrics.playing
    readonly property real mediaNow: mediaPos + (mediaPlaying ? Math.max(0, mediaTick - mediaAt) : 0)
    function mediaRead(force) {
        const p = Lyrics.player;
        if (!p)
            return;
        p.positionChanged();
        const real = p.position * 1000;   // MprisPlayer.position is in seconds
        const now = Date.now(), est = mediaPos + (mediaPlaying ? Math.max(0, now - mediaAt) : 0);
        if (force || Math.abs(real - est) > 1500) {
            mediaPos = real;
            mediaAt = now;
        }
    }
    onMediaPlayingChanged: {
        // freeze (or resume) where it is now, without a jump
        mediaPos = mediaPos + (!mediaPlaying ? Math.max(0, Date.now() - mediaAt) : 0);
        mediaAt = Date.now();
        mediaTick = mediaAt;
    }
    Connections {
        target: Lyrics
        function onTitleChanged() {
            root.mediaRead(true);
        }
    }
    Timer {
        interval: 33
        repeat: true
        running: root.mediaUsers > 0 && root.mediaPlaying
        onTriggered: root.mediaTick = Date.now()
    }
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.mediaUsers > 0
        onTriggered: root.mediaRead(false)
    }

    // the built-in desktop widgets that have a face of the skin's own (modules/serp/widgets)
    readonly property var widgetFaces: ["Clock", "Sysmon", "Music", "Disks", "Discord"]

    // the Serpantinum settings window (modules/serp/SerpSettings)
    property bool settingsOpen: false
    property string settingsPage: "theme"

    // the wallpaper is drawn on these screens (WallpaperView via hunks/boot.py): the boot show
    // («Пробуждение») opens onto the desktop only then
    property var wallDrawn: ({})
    function noteWallDrawn(screen, on) {
        if (!!wallDrawn[screen] === on)
            return;
        const m = Object.assign({}, wallDrawn);
        m[screen] = on;
        wallDrawn = m;
    }
    function wallsDrawn(screens) {
        return (screens || []).every(s => !!wallDrawn[s.name]);
    }
    // the bar's tray orb opens / gathers (SerpBar): `qs -c angelos ipc call serp tray`, a key bind
    signal trayToggled(string screen)
    // «clear all» notifications: the cards fly off to the right one after another (SerpNotifCard,
    // 35 ms apart, at most 8 steps), then the history goes. Motion off: at once
    property bool notifsClearing: false
    function clearNotifs() {
        if (notifsClearing)
            return;
        if (Motion.still) {
            Notifs.clearHistory();
            return;
        }
        notifsClearing = true;
        notifsClearTimer.restart();
    }
    Timer {
        id: notifsClearTimer
        interval: 8 * 35 + 300
        onTriggered: {
            Notifs.clearHistory();
            root.notifsClearing = false;
        }
    }
    // the bar's devices panel (SerpBar): `qs -c angelos ipc call serp devices`
    signal devicesToggled(string screen)
    IpcHandler {
        target: "serp"
        function devices(): string {
            if (!root.on)
                return "the serp skin is off";
            root.devicesToggled(Niri.focusedOutput);
            return "ok";
        }
        function tray(): string {
            if (!root.on)
                return "the serp skin is off";
            root.trayToggled(Niri.focusedOutput);
            return "ok";
        }
        function panel(kind: string): string {
            if (!root.on)
                return "the serp skin is off";
            root.togglePanel(kind, Niri.focusedOutput || Shell.primaryName);
            return root.panel || "closed";
        }
        function settings(page: string): void {
            if (page)
                root.settingsPage = page;
            root.settingsOpen = !root.settingsOpen || !!page;
        }
        function skin(on: bool): string {
            root.setSkin(on ? "serp" : "classic");
            return on ? "serp" : "classic";
        }
        function status(): string {
            return JSON.stringify({
                "on": root.on,
                "hell": root.hell,
                "palette": root.cfg.palette,
                "accent": root.accent.toString(),
                "palettes": root.paletteIds.length,
                "wall": root.wallFile,
                "panel": root.panel,
                "haloStrip": Halo.strip,
                "barHeight": root.barHeight,
                "zone": root.zoneNow
            });
        }
    }
}
