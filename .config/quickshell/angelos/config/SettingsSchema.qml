import QtQuick
import Quickshell.Io

// Every angelOS setting with its default value. Config.qml loads the user's
// ~/.config/angelos/settings.json into one copy and keeps a second, untouched
// copy as `Config.defaults` ("Reset this page", undo labels).
JsonAdapter {
    property JsonObject appearance: JsonObject {
        property string customAccent: "#c77dff"
        property string motion: "full"      // how much moves: full | calm (no flashes, shaking, sudden loud sounds) | off (no animations: the shell, niri, hell) — config/Motion
        property string iconStyle: "angelos" // the shell's icons: angelos (our own) | pixelarticons | hackernoon — widgets/IconSets.js (D3)
        property string customAccentHell: ""  // hell's accent from its wallpaper ("From wallpaper"); heaven's stays customAccent
        property string language: "ru"
        property string mode: "dark"        // light | dark | auto
        property int lightFrom: 8           // auto: light theme from this hour
        property int darkFrom: 20           // auto: dark theme from this hour
        property string flavor: "overdose" // bubblegum | overdose | cyberangel
        property real opacity: 0.84         // panel background opacity (blur shows through)
        property bool blur: true
        property int px: 2                  // size of one "art pixel" in screen pixels
        property real fontScale: 1          // ×1 … ×2 in quarters; Theme.fontPx keeps each font on its pixel grid
        property bool shadows: true         // hard pixel drop shadows
        property bool themeApps: true       // render templates for kitty/foot/gtk/niri
        property var disabledTemplates: []
        property bool qtStyle: false        // Qt apps in angelOS colours and a pixel style through qt6ct (scripts/qt-theme.py switches QT_QPA_PLATFORMTHEME for apps)
        property string fontTitle: ""       // "" = Pixeloid Sans
        property string fontBody: ""        // "" = CozetteVector
        property string fontMono: ""        // "" = Pixeloid Mono
        property bool autoWallpaperColors: true // flavor "wallpaper": follow wallpaper changes
        property string paletteScreen: ""  // screen whose wallpaper feeds the palette; "" = first
    }

    property JsonObject bar: JsonObject {
        property string style: "taskbar"    // taskbar | top | island | dock | capsules | windose (BarLayout.styles)
        property bool autoHide: false       // taskbar: slides away below the screen edge, back on the pointer at the edge
        property int autoHideMs: 700        // how long it waits after the pointer leaves
        property var screens: []            // empty = every screen
        property bool compactOnVertical: true
        property bool showWindows: true
        property string tasksWidth: "fill"  // the "Windows" element: fill (takes the free room) | compact (as wide as its buttons)
        property bool taskLabels: false
        property int taskMinWidth: 40       // task buttons with titles, in art pixels
        property int taskMaxWidth: 90
        property string workspaceStyle: "hearts" // hearts | icons | both
        property int workspaceIcons: 3      // max app icons per workspace
        property bool allWindows: false     // taskbar: every window, not only current workspace
        property bool showMedia: true
        property bool showSeconds: false
        property string clockFormat: "auto" // auto (12 h in English, 24 h in Russian) | 24 | 12
        property string startLabel: "angelOS"
        property string startStyle: "classic" // classic (Win98 list) | win11 (centred, pinned grid) | fullscreen (iPhone-like app grid) | xmb (PSP) | windose (NGO window) | wii (channels) | spotlight (a search pill)
        property var startPinned: []        // desktop entry ids pinned in Start
        property string startAlign: "auto" // auto (classic at the button, win11 centred) | left | center | right
        property string taskbarAlign: "left" // left | center — Start and the window buttons in the middle, like Windows 11
        property int startWidth: 100        // Start menu width, % of the default
        property int startRows: 3           // win11: rows of pinned apps
        property var startPrefs: ({})       // deep settings per Start look: {"win11": {"columns": 8, …}} (services/StartPrefs)
        property string avatar: ""          // the user's picture in Start (a copy in ~/.local/share/angelos); "" = the system's (AccountsService, ~/.face)
        property bool avatarPixel: false    // the avatar drawn in big pixels, like the rest of angelOS
        property string userName: ""        // the name under / next to it; "" = the login name
        property string logoStyle: "classic" // wordmark: classic | angel | windose (NGO, pill O) | hell (gothic, drips) | chrome (Y2K)
        property string logoEmblem: "heart" // emblem: heart (winged, halo) | pill | star | cd | kitty
        property bool logoFastfetch: true   // fastfetch draws the chosen emblem (~/.config/fastfetch/logo.txt)
        property bool logoText: true        // the wordmark next to the emblem on the Start button (false: the emblem only)
        property bool metaTap: true         // a short Meta tap opens Start (Windows-like)
        property int metaTapMs: 400         // longer presses are holds, not taps
        property bool metaTapFullscreen: false // also over fullscreen windows / games
        property var layout: ({})           // {left:[], center:[], right:[]}; empty = defaults
        property var hidden: []             // widget ids removed from the bar
        property string trayTint: "accent"  // off | mono | accent — recolor tray icons to the theme
        property string trayDensity: "normal" // tray grid: compact | normal | airy | spacious (fewer, bigger cells)
        property string rightDensity: "normal" // the right side of the bar (tray, bell, clock…): compact | normal | airy
        property bool tintTasks: false      // same for window buttons
        property string taskRightClick: "menu" // menu (window menu with Close) | close (closes at once) | none
        property bool taskMiddleClose: true // middle click on a window button closes the window
        property bool taskHoverClose: false // × on the hovered window button
    }

    property JsonObject wallpaper: JsonObject {
        property string dir: "~/Pictures"
        property string fallback: ""
        property var outputs: ({})          // "DP-1" -> path
        property var workspaces: ({})       // "DP-1:2" -> path
        property string transition: "mosaic-dither" // mosaic-dither | mosaic | dither | none (only when the picture changes)
        property int duration: 750
        property int maxBlock: 48
    }

    property JsonObject workspaces: JsonObject {
        property string popupMode: "bar"    // bar (flash next to the hearts) | window | off
        property string popupPosition: "bottom-center"
        property bool indicator: false      // heart strip on the right edge
        property int popupMs: 650
        property bool phrases: true
        property string switchFx: "soft"    // soft | slide | bounce | teleport | pixel | heart | glitch | instant
        property string heartAnim: "smart"  // hearts/icons indicator: smart | collide | ender | hop | worm | pixel | beat | sparkle | drop | glitch | slide | off
        property string sprite: "heart"     // the desk sprite on the bar/strip/popup and the "Heart" transition's shape: heart | star | cd
        property real heartSpeed: 1.0       // × speed of the indicator animation (2 = twice as fast)
        property real switchSpeed: 1.0      // × speed of the switch animation: niri's slide (cfg/animation.kdl) and angelOS's captured ones
        property var names: ({})            // "DP-1:1" -> "работа"
    }

    // window decorations (modules/decor, Settings → Windows → Decorations): niri draws no
    // title bars (prefer-no-csd), so apps without their own get angelOS's
    property JsonObject decor: JsonObject {
        property bool titlebars: true       // angelOS title bars over floating windows without a frame of their own
        property var skip: ["helium", "chromium", "google-chrome", "brave-browser", "firefox", "zen", "librewolf", "org.gnome.*", "org.quickshell", "quickshell", "steam", "discord", "vesktop", "spotify", "code", "code-oss", "cursor", "obsidian", "org.telegram.desktop", "com.mitchellh.ghostty"] // app ids that draw their own (a * at the end: a prefix)
        property bool gtkButtons: true      // GTK 3/4 window buttons drawn like angelOS's (templates gtk3/gtk4)
        property string gtkLayout: "maximize,close" // GTK title bar buttons, in order (gsettings button-layout, right side)
    }

    // window menu (modules/bar/parts/WindowMenu.qml): "Make floating / Back to tiling" and
    // "Maximize to edges" are off by default — they sit behind an experimental toggle that only
    // shows in expert settings. Right-click on a window button without expert mode only gets you
    // Fullscreen, Move to desk / monitor, Close, End task.
    property JsonObject windows: JsonObject {
        property bool floatButtons: false   // experimental: floating + maximize buttons in the window menu
    }

    property JsonObject alttab: JsonObject {
        property string style: "angelos"    // angelos | ngo | y2k — angelOS's own switcher; niri = niri's with live previews
        property string scope: "all"        // all | output (this monitor) | workspace (this desk)
        property int delayMs: 150           // a quick Alt+Tab tap switches without showing anything
        property bool titles: true          // window titles under the icons
    }

    property JsonObject lyrics: JsonObject {
        property bool enabled: true         // current line in the middle of the bar
        property var screens: []            // empty = every bar
        property int offsetMs: 0
        property string artwork: "note"          // note | cover
        property bool typewriter: true
        property string preferPlayer: "spotify"
        property var sources: ["local", "player", "lrclib", "netease", "kugou", "qq", "ovh"] // tried in this order
        property int sourcesVersion: 0      // 2 = the list knows kugou/qq/local/player (older lists get them once)
        // the line's brightness follows the volume (services/LyricsGlow): off | auto (a
        // RØDECaster's fader when one is plugged in, else the real level) | rode | level
        property string glow: "auto"
        property int glowFloor: 30          // % the line never goes below (30–100)
        property string glowTap: "main"     // RØDECaster: where the fader is read — main (the mix after the faders) | aux01 … aux89 (multitrack pairs)
        property real glowRodeMin: -40      // dB of the fader that is "all the way down" (calibrated in Lyrics)
        property real glowRodeMax: 0        // dB of the fader at the top
        property real glowLevelMin: -48     // dBFS of the music that dims the line to the floor
        property real glowLevelMax: -14     // dBFS that lights it fully
    }

    property JsonObject setup: JsonObject {
        property bool complete: false       // the first-run wizard done or set up later (it holds the desktop until then)
        property bool gameAsked: false      // the installer already asked "with the game?" (ANGELOS_GAME): the wizard does not ask again
        property bool keyboardAsked: false  // …and the keyboard layouts (KB_LAYOUTS)
    }

    property JsonObject notifications: JsonObject {
        property bool dnd: false
        property int timeout: 6000
        property string screen: ""          // empty = focused output
        property string position: "top-right"
        property int maxPopups: 4
    }

    property JsonObject osd: JsonObject {
        property bool enabled: true
        property bool layout: true          // show keyboard layout switches
        property string position: "bottom-center"
        property int ms: 900
    }

    property JsonObject desktop: JsonObject {
        property var widgets: []            // [{uid, type, screen, x, y, settings}]; x/y < 0 = from the right/bottom
        property bool initialized: false
        property bool snap: true
        property string titleSuffix: "exe"  // every angelOS window, widget and caption ends in .exe | .sh | .bin (I18n.exe)
        // the right-click menu on the wallpaper (services/DeskMenu, Settings → Right-click menu)
        property string menuStyle: "list"   // list (the usual, Windows 11-like) | radial (a ring) | y2k (glossy bubble) | tiles (Control Center) | wings | harp (heaven's own; in hell the circle's own takes their place) | pentagram
        property var menuQuick: ["terminal", "files", "monitor", "wallpaperPick", "settings"] // the list's top row, the ring's first slots (up to 6)
        property var menuItems: ["view", "new", "wallpaper", "open", "sep", "displaySettings", "personalize", "more"] // the rest, in order; "sep" = a line in the list
        property var menuCustom: []         // own entries [{id: "custom:<n>", label, icon, kind: app|command|path|url, target}]
        property string menuSize: "normal"  // compact | normal | large
        property bool menuIcons: true       // icons in the list
        property bool menuLabels: true      // names under the ring's icons
        property bool menuAnim: true        // the ring flies out, the list pops
    }

    property JsonObject voxtype: JsonObject {
        property string indicator: "angelos" // angelos | classic (old GTK circle) | off
        property string position: "bottom-center"
    }

    property JsonObject launcher: JsonObject {
        property string terminal: "kitty"
        property var usage: ({})            // desktop id -> launches
        property bool calc: true            // Start search and the launcher count: 2+2, 10 km in mi, 100 usd in rub
        property bool settings: true        // Start search and the launcher find settings too, mixed with apps by relevance
    }

    property JsonObject lock: JsonObject {
        property int idleMinutes: 0         // 0 = never lock automatically
        property bool onSleep: true         // lock before suspend/hibernate (logind), so waking up shows the lock
        property bool pixelate: true
        property bool hearts: true          // floating pixel hearts
        property bool reactions: true       // hearts on typing, a broken heart on a mistake, a burst on unlock
        property bool indicators: true      // Caps Lock, layout, battery, time locked, missed notifications
        property bool logo: true            // the angelOS logo above the clock
        property bool stream: false         // NGO stream overlay: LIVE badge, viewers, cute chat
        property string streamTitle: ""      // "" = "angel is on a break" 
    }

    property JsonObject idle: JsonObject {
        property int minutes: 0             // start the idle screen after N idle minutes; 0 = by hand only
        property string text: ""            // "" = angelOS ASCII art
        property string effect: "random"    // random | decrypt | rain | beams | wave | typewriter | hearts | glitch
        property string colors: "accent"    // accent | mono | rainbow
        property bool clock: true
        property bool allScreens: true
    }

    property JsonObject sidebar: JsonObject {
        property bool enabled: false        // experimental
        property string screen: ""          // "" = first screen
        property string edge: "right"       // left | right | top | bottom — where the tab sits
        property real offset: 0.5           // tab position along that edge, 0..1
        property var sections: ["toggles", "media", "sound", "system", "ai"]
    }

    property JsonObject capture: JsonObject {
        property string skin: "ropes"       // ropes | window | stream — region selector and recording overlay
        property bool themeColors: false    // NGO skins in the angelOS theme instead of the NGO palette
    }

    property JsonObject plugins: JsonObject {
        property var enabled: ({})          // id -> bool (missing = manifest default)
        property var data: ({})             // id -> plugin settings object
        property var removed: []            // bundled plugins removed by hand (hidden; "Restore" brings them back)
    }

    property JsonObject dotfiles: JsonObject {
        property string repo: "~/AngelOS-Dotfiles"
        property string command: "./install.sh"
        property string env: "DOTFILES_MODE=full SKIP_PACKAGES=1 INSTALL_VOXTYPE=0 DOWNLOAD_VOXTYPE_MODEL=0 ENABLE_SERVICES=0"
        property bool reloadNiri: true
    }

    property JsonObject system: JsonObject {
        property string terminal: "kitty"
        property string fileManager: "nautilus"
        property string monitor: "auto"
        property string monitorProgram: ""
        property bool monitorInTerminal: false
        property bool monitorFloat: true    // the task manager opens as a floating window (niri rule)
        property string monitorSize: "medium" // compact | medium | large | tall | custom
        property int monitorWidth: 1200     // custom size, logical px
        property int monitorHeight: 760
        property string monitorPlace: "center" // center | corner (bottom-right, next to the tray)
        property bool nautilusDefaults: false // angelOS Nautilus extensions + prefs applied once
        property string primaryScreen: ""   // the main screen (widgets, the angel, the lock…); "" = the widest
        property var screenTune: ({})       // Monitor → Brightness and colour: {output: {brightness 0.3–1 (gamma), saturation −1…1 (NVIDIA vibrance)}} (services/ScreenTune)
    }

    property JsonObject cursor: JsonObject {
        property string theme: ""           // "" = leave the system cursor alone
        property int size: 24
        property bool flatpak: true         // also hand the theme to Flatpak apps
        property bool shake: true           // shake the mouse to find the pointer: it grows for a moment (macOS)
        property string shakeSensitivity: "normal" // low | normal | high — how hard a shake has to be
        property real shakeScale: 4         // how big it grows, × the cursor size
        property string hell: "circle"      // the demon's cursor while she rules: circle (the circle's own, scripts/cursors.py) | a hell theme | "" = she leaves it alone
        property string hellPick: "angelOS-Hell" // the hell theme last picked by hand (Settings → Cursor → Hell → One theme)
        property bool hellByCircle: false   // the old default "angelOS-Hell" became "circle" once (services/Cursors)
        property string beforeHell: ""      // never picked one: the cursor she replaced, put back by the angel
        property int beforeHellSize: 0
        property string beforeMac: ""       // the cursor the Golden Gate skin's arrow replaced (services/Cursors)
    }

    property JsonObject updates: JsonObject {
        property string repo: ""            // "" = found automatically (installer marker, ~/AngelOS-Dotfiles)
        property bool autoCheck: true       // look for updates once a day, never installs by itself
        property string lastCheck: ""
        property int available: 0
    }

    property JsonObject network: JsonObject {
        property bool showWifi: true        // bar/sidebar Wi-Fi indicator when a Wi-Fi adapter exists
        property bool showBluetooth: true
        property bool showWired: true       // bar: the wired connection's indicator (when there is a wired adapter)
    }

    property JsonObject y2k: JsonObject {
        property bool helper: true          // the pixel angel in a screen corner
        property string helperScreen: ""   // "" = the main screen (Shell.primaryScreen), "focus" = where the focus is
        property string helperTips: "rare" // off | rare | often
        property bool helperGreeted: false
        property bool sparkles: true        // sparkle trail over the bare desktop
        property var sparkleScreens: []     // empty = every screen
        property bool sounds: true
        property real soundVolume: 0.55
        property real helperVolume: 0.6     // the angel's / demon's voice, pips and effects, on top of soundVolume
        property var soundOff: ["click"]    // events kept quiet: startup notify error click shutdown angel
        property var soundTweaks: ({})      // System sounds: {event: {on, vol (0–1.5), sound ("" | other event | "file:/path"), vary}}
        property var clickButtons: ["left", "right"] // which mouse buttons make the click sound (left right middle)
        property bool clickRelease: false   // a softer tick when the button comes up
        property bool quietFullscreen: true // no click / typing sounds over a fullscreen window (games)
        property bool quietHours: false     // no sounds from quietFrom to quietTo (hours)
        property int quietFrom: 23
        property int quietTo: 8
        property bool boot: true            // CD-ROM style loading screen once per login
        property var bootScreens: []        // empty = every screen
        property string soundPack: "y2k"    // y2k (synthesised here) | overdose (NEEDY GIRL OVERDOSE sounds, downloaded on first use)
        property bool cuteSounds: true      // overdose pack: little sounds on cute actions (Start, toggles, screenshots…)
        // angel ↔ demon (services/Angel): who lives in the corner
        property string character: "angel"  // angel | demon
        property double demonSince: 0       // ms; the demon arrived
        property var pleas: []              // ms of the lucky "come back, angel" pleas; 3 within 2 h bring her back
        property double lastPlea: 0         // pleas count once per 10 minutes
        property double wheelAt: 0          // the Wheel of Hell's last spin (one per 20 minutes)
        property double cursedUntil: 0      // the wheel's cursed cursor: another hell cursor until then
        property string cursedWas: ""       // the hell cursor it replaced
        property var pranks: []             // the demon's pranks this round [{id, key, old, new, at, undone}]; each shows off a feature
        property var seenTips: []           // settings pages whose first-visit tip the angel already told
        property double nextPrank: 0        // ms; not before
        property string cracks: "full"      // the demon's broken screen corner: full | weak | off
        property string breakage: "circle"  // what her fist breaks there: circle (the circle's own set, story/circles.json) | random | one kind (HellLook.breakageKinds)
        property bool breakageByCircle: false // the old default "glass" became "circle" once (services/Cracks)
        property bool heavenFx: true        // sun rays and a choir when the angel comes back
        property bool raysSeen: false       // the rays played when she first appeared; not again on every start
        property string textShake: "light"  // the helper's letters twitch now and then: off | light | strong
        property string hellStyle: "pack"   // the demon's wallpaper: pack (pixel paintings, Hell pack) | drawn
        property bool shake: true           // the angel ↔ demon swap shakes the screen (the demon brings 8-bit rocks)
        property bool hellWallpaper: true   // (no longer read: the demon always brings hell's wallpaper, the angel gives yours back)
        property int returns: 0             // times the angel came back from hell; 3 open the portal (Angel.portalOpen)
        property string hellPicture: ""     // "" = generated pixel hell (scripts/hell-wallpaper.py)
        property var angelSaved: null       // wallpaper + theme mode kept while the demon rules
        property bool jokes: true           // she jokes now and then, not only tips
        property string hellMenu: "circle" // the right-click menu while the demon rules: circle (the circle's own, story/circles.json → dress) | pentagram | a circle's look (HellLook.dressMenuIds) | radial | y2k | tiles | "" (the usual one; heaven's own looks are never hell's — the circle's own takes their place)
        property string hellSettings: "circle" // Settings while the demon rules: circle (the circle's own) | grimoire (a book) | a circle's look (HellLook.dressSettingsIds) | "" (the usual window)
        property bool hellDressByCircle: false // the old defaults pentagram / grimoire became "circle" once (services/DeskMenu)
        property string hellStart: "skin"   // Start while the demon rules: skin (your look, hell version + a hell Start button) | hell (StartHell) | "" (untouched)
        property bool hellWidgets: true     // desktop widgets burn over to their hell look while the demon rules
        property string hellAltTab: "hell"  // Alt+Tab while the demon rules: hell (AltTabHell, hell's own) | skin (your style re-inked in the circle's colours) | "" (untouched)
        property bool hellTerminal: true    // kitty / foot / Alacritty in the circle's colours while the demon rules (+ kitty: a scorched background; fish: her line and the circle's command colours)
        property bool hellApps: true        // GTK and Qt apps in hell's colours while the demon rules (gtk-live.py, qt-theme.py)
        property bool hellBar: true         // the bar while the demon rules: each style's hell version (HellBarFrame: the circle's stone at the edges, calm plates under the content; the dock stays as it is)
        property bool hellLyrics: true      // the bar's lyrics while the demon rules: hell's blackletter in the circle's colour, no typewriter, no animation
        property string angelLook: "glitch" // glitch (cracked halo, pictures) | chibi (the first pictures) | adult (30×40 pixels) | mini (the first 20×21); kept as picked while the story shows her otherwise (Angel.angelLook)
        property string demonLook: "glitch" // the same for the demon (glitch: the sleepless neon one)
        property real helperScale: 1.0      // 0.75–2.00: Ctrl + mouse wheel, 5 % a notch; rendered size capped to screen (Y2K → Helper → Size)
    }

    // the game: angelOS is a story played over the real desktop (services/Story, story/).
    // The player's save is its own file (~/.config/angelos/save.json), not here.
    property JsonObject game: JsonObject {
        property bool enabled: true         // false: plain dotfiles — no angel, demon, novel or hell (installer ANGELOS_GAME=0, the setup wizard, `angelos game off`)
        property bool calm: false           // older settings: became appearance.motion "calm" (config/Motion migrates it once)
    }

    // the novel (services/Novel, ~/AngelOs-Nov): chapters the angel plays out on the desktop
    property JsonObject novel: JsonObject {
        property bool enabled: true
        property string dir: "~/AngelOs-Nov"   // story/*.json and sprites/<who>/*.png (the author's editor: `angelos novel edit`)
        property string gender: ""          // from the setup wizard: m | f | "" (not said) — she still asks
        property string name: ""            // how she calls you ({name}); "" = the login name
    }

    // the lens at the pointer (services/Lens, Settings → Keyboard and mouse → Lens)
    property JsonObject lens: JsonObject {
        property string mode: "live"        // live: a glass beside the pointer, frame by frame (extras/lens-live) | snapshot: on the pointer, a picture of the screen
        property real zoom: 2               // how much a fresh lens magnifies
        property int size: 300              // its diameter (or side), px
        property string shape: "circle"     // circle | square
        property bool crisp: true           // sharp pixels (off: smoothed like KDE)
        property int refresh: 0             // s; re-take the picture under the lens this often (0 = only on a click / R)
        property bool keys: true            // niri keys Mod+Alt+= / Mod+Alt+- / Mod+Alt+0 (cfg/angelos-windows.kdl)
    }

    property JsonObject stream: JsonObject {
        property bool auto: true            // follow OBS: stream mode while OBS streams (obs-websocket)
        property bool manual: false         // stream mode by hand (button, `angelos stream on`)
        property int port: 4455             // obs-websocket port (OBS → Tools → WebSocket Server Settings)
        property var screens: []            // the streamed screens; empty = every screen
        property bool hideAngel: true       // the angel leaves the streamed screens (or hides)
        property bool mute: true            // angelOS sounds stay quiet
        property bool dnd: true             // Do not disturb while live
        property bool effects: true         // no sparkles, loading screen or angel/demon effects on the streamed screens
        property bool dndSet: false         // stream mode switched DND on (switched off again when the stream ends)
        property bool suppressed: false     // switched off by hand during this stream (kept through a shell restart)
    }

    property JsonObject settingsUi: JsonObject {
        property bool expert: false         // false: home tiles, main settings only; true: every page in a sidebar
        // how the window lays the same pages out (modules/settings/views): win11 (like Windows
        // 11: categories on the left, cards on the right — the default) | sidebar (macOS-like,
        // what older installs had) | controlpanel (Win98: a folder of icons, a page fills the
        // window) | properties (a Win98 properties sheet: a section's pages are tabs) | tiles
        property string view: "win11"
        property bool win11Once: false      // an install still on the old default (sidebar) moved to win11 once
        property string viewPicked: ""      // the view picked in the setup wizard — the player's first choice, kept when changed later
        property string skin: "classic"     // classic angelOS | Windose desktop | stream studio
        property bool skinChosen: false     // the look was picked (the wizard, or the banner on the settings home)
        property var usage: ({})            // page id -> visits; "Everyday" on the home page follows it
    }

    // the Golden Gate skin (settingsUi.skin "goldengate"; services/GoldenGate, modules/mac): the
    // whole desktop like macOS 27 for people coming from a Mac
    property JsonObject mac: JsonObject {
        property real glass: 0.35           // Liquid Glass: 0 clear … 1 tinted (like Appearance → Liquid Glass)
        property string accent: "blue"      // blue | purple | pink | red | orange | yellow | green | graphite
        property bool barBackground: false  // the menu bar on a band of its own ("Show menu bar background")
        property bool appMenus: true        // the focused app's own menus in the menu bar (scripts/appmenu.py)
        property bool keys: false           // Mac-style shortcuts (the skin's binds in niri's angelos.kdl) — offered, never imposed
        property bool floating: true        // new windows float and overlap like on a Mac (off: niri's columns)
        // the skin's own window title bars (modules/decor), apart from Config.decor (the other skins'):
        // on, a Mac title bar with the traffic lights over every floating window that draws none of
        // its own; decorSkip are the ones that do (browsers with their own frame, GTK/libadwaita,
        // Electron and Steam) — Helium with the system frame has none, so it gets one
        property bool titlebars: true
        property string minimizeEffect: "genie" // genie | scale — how a window goes to the Dock (modules/mac/MacMinimizeFx)
        property var decorSkip: ["firefox", "zen", "librewolf", "chromium", "google-chrome", "brave-browser", "org.gnome.*", "io.missioncenter.*", "org.pipewire.Helvum", "org.pulseaudio.pavucontrol", "com.shellyorg.shelly", "localsend*", "com.mitchellh.ghostty", "org.quickshell", "quickshell", "steam", "discord", "vesktop", "spotify", "code", "code-oss", "cursor", "obsidian", "org.telegram.desktop"]
        property int dockSize: 48           // Dock icons, logical px
        property bool dockMagnify: true     // icons grow under the pointer
        property int dockMagnifySize: 96    // the icon right under the pointer, logical px (dockSize..128)
        property bool dockMacIcons: true    // MacTahoe's icons in the Dock (DockIcons, scripts/mac-icons.py)
        property bool dockAutohide: false
        property bool dockRecents: true     // recently used apps after the divider
        property var dockApps: []           // desktop ids in the Dock; empty: Start's pinned apps
        property string font: ""            // "" = Inter (open, drawn close to SF Pro); any installed family
        property bool wallpaper: true       // the skin's own wallpaper (scripts/goldengate-wallpaper.py), light or dark with the theme
        property var wallBefore: ({})       // the wallpapers it replaced, given back when the skin goes
    }

    property JsonObject developer: JsonObject {
        property bool enabled: false
        property string provider: "claude-cli" // claude-cli | codex-cli (browser login) | openai | anthropic (API key)
        property string openaiModel: "gpt-5.4"
        property string anthropicModel: "claude-opus-5-5"
        property string claudeCliModel: "sonnet" // "" = the CLI default; aliases: haiku / sonnet / opus / fable
        property string codexCliModel: ""
        property var efforts: ({})          // provider -> low | medium | high | xhigh | max | ultra ("" = model default)
        property int autoRepair: 1          // automatic repair rounds after failed checks (0–2)
        property int maxOutputTokens: 32000
    }
}
