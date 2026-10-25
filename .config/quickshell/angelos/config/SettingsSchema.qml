import QtQuick
import Quickshell.Io

// Every angelOS setting with its default value. Config.qml loads the user's
// ~/.config/angelos/settings.json into one copy and keeps a second, untouched
// copy as `Config.defaults` ("Reset this page", undo labels).
JsonAdapter {
    property JsonObject appearance: JsonObject {
        property bool highContrast: false   // Accessibility → Contrast: stronger text and edges (config/Theme.qml)
        property string customAccent: "#c77dff"
        property string motion: "full"      // how much moves: full | calm (no flashes, shaking, sudden loud sounds) | off (no animations: the shell, niri, hell) — config/Motion
        property string iconStyle: "angelos" // the shell's icons: angelos (our own) | pixelarticons | hackernoon — widgets/IconSets.js (D3)
        property string folders: "theme"     // Pixora's folders (scripts/folder-tint.py): pixora (as drawn) | theme (the accent) | pink | lavender | mint | sky | gold
        property string customAccentHell: ""  // unused since 2026-10-08: hell wears its circle's accent, not its wallpaper's
        property string language: "ru"
        property string mode: "dark"        // light | dark | auto
        property string dayLook: "dusk"     // the interface by day (Theme.dayLooks): dusk | sage | lavender | olive | amber | glass | scheme
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
        property string paletteArea: "all" // where in the wallpaper the colour comes from: all | sky | middle | ground | custom (services/PaletteGenerator, ColorQuantizer)
        property var paletteRect: [0.25, 0.1, 0.5, 0.3] // custom: x, y, width, height as parts of the picture
    }

    property JsonObject bar: JsonObject {
        property bool autoHide: false       // taskbar: slides away below the screen edge, back on the pointer at the edge
        property string edge: "bottom"      // taskbar: the screen edge it sits on, like Windows 10 — bottom | top | left | right (BarLayout.edge)
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
        property string startButtonStyle: "classic" // the bar's Start button: classic (bevelled, the logo) | capsule (an XP-like "start" pill in the accent)
        property string startStyle: "classic" // classic (Win98 list) | win11 (centred, pinned grid) | fullscreen (iPhone-like app grid) | xmb (PSP) | spotlight (a search pill)
        property var startPinned: []        // desktop entry ids pinned in Start
        // the buttons along Start's bottom, in order (services/StartItems.buttons; unknown ids are skipped):
        // downloads | lock | sleep | power | reboot | logout | settings | home | terminal | updates | idle
        property var startButtons: ["updates", "lock", "sleep", "power"]
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
        // fastfetch's style (scripts/fastfetch_style.py, FastfetchLogo.styles): compact | angel |
        // helper | receipt | stream | window | mini, or "own"
        // (the config is left to the user; then only logoFastfetch draws into logo.txt)
        property string fastfetchStyle: "compact"
        // its picture moving for a moment in a new terminal (scripts/fastfetch_anim.py): off |
        // short (2.5 s) | long (6 s); still whenever motion is off
        property string fastfetchAnim: "short"
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
        property var taskPinned: []         // app ids pinned to the taskbar: their buttons lead the row, starting the app while none runs
        property var taskOrder: []          // Desktop: the taskbar's apps in the order dragged into
    }

    property JsonObject wallpaper: JsonObject {
        property string dir: "~/Pictures"
        property string fallback: ""
        property var outputs: ({})          // "DP-1" -> path
        property var workspaces: ({})       // "DP-1:2" -> path
        property string transition: "mosaic-dither" // mosaic-dither | mosaic | dither | none (only when the picture changes)
        property var behindApps: [{"id": "spotify", "depth": ""}] // angel-niri: apps whose floating windows stand behind a layered scene's nearer things — [{id: app-id, depth: "" | "deep" | "behind:<layer id>"}] (services/SceneBehind)
        property int duration: 750
        // the verdict transition's word: "auto" (DESCEND into hell, ASCEND out of it, else
        // DESCEND), "off" (a halo instead), or any text of one's own
        property string verdictTitle: "auto"
        property int maxBlock: 48
        // every theme keeps its own wallpapers (services/GoldenGate: swapWalls): "pixel" (the pixel
        // skins) and "mac" (Golden Gate) -> {fallback, outputs, workspaces}; fallback/outputs/
        // workspaces above are the set of the theme in front (themeOf), saved here when it goes
        property var themes: ({})
        property string themeOf: ""
        // the newest release whose wallpapers were offered (services/Wallpapers: releases)
        property int releaseSeen: 0
        // one wallpaper in several files (day / night, 21:9, 32:9, 9:16 …, scripts/wall-meta.py):
        // every screen shows the file that fits the theme and its shape (services/Wallpapers: pick)
        property bool variants: true
        // pixel wallpapers (services/Wallpapers: pixel, scripts/wall-pixelate.py): any picture is
        // shown as a copy redrawn in big pixels for the screen it is on; the original is not touched
        property bool pixel: false
        property int pixelSize: 4          // screen pixels to one art pixel on a 1080-pixel screen: 2 … 12
        property int pixelColors: 32       // colours of the copy's palette: 8 … 64
        property int pixelDither: 60       // 0 … 100: how much of the smooth parts is dithered
        // half-alive wallpapers (services/LiveWalls): stars twinkle and fall in a night sky,
        // water ripples and mirrors them, the picture's lights twinkle
        property bool live: true
        property int liveStrength: 60      // 10 … 100
        property bool liveStars: true
        property bool liveMeteors: true
        property bool liveWater: true
        property bool liveLights: true
        property bool liveEvents: true      // now and then: a glint over a ring, a pebble, a gust
        property int liveFps: 24            // 0: every frame of the screen
        property var liveOverrides: ({})   // path -> {sky, water: "on"|"off", axis: 0..1}
        // the release's name, small and see-through in a free corner (widgets/ReleaseMark)
        property bool releaseMark: true
        property string releaseMarkCorner: "auto"   // auto | bottom-right | bottom-left | top-right | top-left
        property int releaseMarkOpacity: 35         // 10 … 80
        property string sceneDepth: "clock"         // clock | release | "": behind a layered scene's nearer layers (WallpaperView)
        property string sceneDepthStyle: "neon"     // outline | neon | chrome | cutout (widgets/SceneDepthText)
        property bool sceneDepthTexture: true       // the text takes the picture's grain
        // a wallpaper's own picks (services/Wallpapers: own): a release's folder (its wallpapers share them)
        // or a picture -> {liveStrength, liveStars, …, sceneDepth, …}; what is not there is the value above
        property var perWall: ({})
    }

    property JsonObject workspaces: JsonObject {
        property string popupMode: "bar"    // bar (flash next to the hearts) | window | off
        property string popupPosition: "bottom-center"
        property bool indicator: false      // heart strip on the right edge
        property int popupMs: 650
        property bool phrases: true
        property string switchFx: "soft"    // services/WorkspaceAnim.styles: soft | dash | spring | snap | zoom | card | wipe | fade | dissolve | realm | glitch | crt | instant
        property string heartAnim: "smart"  // hearts/icons indicator: smart | collide | ender | hop | worm | pixel | beat | sparkle | drop | glitch | slide | off
        property string sprite: "heart"     // the desk sprite on the bar/strip/popup: heart | star | cd
        property real heartSpeed: 1.0       // × speed of the indicator animation (2 = twice as fast)
        property real switchSpeed: 1.0      // × speed of the switch animation: niri's slide (cfg/animation.kdl) and angelOS's captured ones
        property var names: ({})            // "DP-1:1" -> "работа"
    }

    // the apps' own window buttons (their client-side decorations; Settings → Windows → Decorations,
    // the pixel skins only — Golden Gate always has the traffic lights): angelOS draws no title
    // bars over windows
    property JsonObject decor: JsonObject {
        property bool gtkButtons: true      // GTK 3/4 window buttons drawn like angelOS's (templates gtk3/gtk4)
        property string gtkLayout: "maximize,close" // GTK title bar buttons, in order (gsettings button-layout, right side)
        // the bar of Helium and Chromium on their "GTK" theme — the tab strip, the open tab and
        // the toolbar are one colour there (templates/gtk3.css): "" = the title bars', or #rrggbb
        property string browserBar: ""
    }

    property JsonObject windows: JsonObject {
        // Desktop instead of the Strip: windows float with title bars (angel-niri's stacking; on
        // plain niri a rule in angelos.kdl, ThemeExport); Golden Gate is always Desktop (WindowConfig)
        property bool floatAll: false
        property bool desktopHintSeen: false // the first-time keys hint (modules/osd/Osd.qml) was shown
        property string titleButtons: "left" // angel-niri title bars: the traffic lights on the left (Mac) | right (Windows)
        property string green: "maximize"   // the green button: maximize | fullscreen (onto a desk of its own, like a Mac)
        property bool pixelCorners: true    // angel-niri: square windows get pixel staircase corners (services/WindowConfig)
        property bool inactiveDim: true     // angel-niri: a sparse grid of dark dots over the windows not in focus (services/WindowConfig)
        property var dimOutputs: []         // the monitors with those dots; empty: every monitor
        property bool pixelOverview: true   // angel-niri: the overview in pixels: sharp thumbnails, pixel frames and desk numbers (services/WindowConfig)
        property bool pixelShadow: true     // angel-niri: dithered window shadows, the focused one glows in the accent (services/WindowConfig)
        property bool remember: true        // angel-niri: programs pinned by hand open on their monitor and desk (services/WindowConfig)
        property bool clipboardKeep: true   // angel-niri: the clipboard outlives the program it was copied from (services/WindowConfig)
        // angel-niri: a floating window let go mid-drag flies on, bounces off the edges, squashes
        // against them and sways like jelly while dragged (services/WindowConfig); each 0 = off
        property bool throwOn: true
        property real throwStrength: 1      // 0.3 barely slides … 2 crosses the screen
        property real throwBounce: 0.5      // speed kept off an edge, 0 … 0.95
        property real throwSquash: 1        // 0 … 2
        property real throwWobble: 1        // 0 … 2
        // cobwebs (services/Cobweb): a window nobody moved for a while gets a spider and its web
        property bool cobweb: false         // off for a new user: a web over the window took its clicks (16.10)
        property bool cobwebInside: true    // the web over the window itself (off: only the bar's buttons)
        property bool cobwebBar: true       // a small web and spider on the window's button in the bar / Dock
        property string cobwebSpeed: "normal" // fast (10 min → 1 h) | normal (30 min → 4 h) | slow (2 h → a day)
        property string cobwebStyle: "classic" // the cocoon's look: classic (the dotted grid it always had) | silk (procedural mesh)
        // silk mesh tuning (services/CobwebWeb buildCocoon, preview in Settings → Windows → Cobwebs;
        // the ranges are clamped in services/Cobweb tunerRange)
        property real cobwebDensity: 1   // strand layers (0.5–2): more layers only append
        property real cobwebBundles: 0   // long edge-to-edge bands (0–1.4)
        property real cobwebBridges: 1   // ties between neighbouring strands (0–2)
        property real cobwebGravity: 1   // thread sag (0–2.5)
        // programs nobody sees go to sleep: frozen + squeezed into zram, messengers only nap (services/AppSleep)
        property bool appSleep: true
        property int appSleepMin: 15        // minutes out of sight before it sleeps
        property string appSleepNever: ""   // more programs never put to sleep: "obsidian,strata" (app id or process name)
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
        property var haloScreens: []        // of those, the screens whose line is in the Halo instead of the bar (Lyrics.placeOn)
        property int offsetMs: 0
        property string artwork: "note"          // note | cover
        property bool typewriter: true
        property int wordLeadMs: 250        // word by word: each word this much before it is sung, to sing along (Lyrics.wordLead)
        property bool byWord: true
        property bool onBeat: true          // word by word: each word on the music's beat or half-beat nearest its time (services/LyricsBeat hears the player)          // a line with its words' times appears word by word as it is sung (Lyrics.wordChars), not typed
        property string preferPlayer: "spotify"
        property var sources: ["local", "player", "lrclib", "amll", "netease", "kugou", "qq", "lrccx", "musixmatch", "ovh"] // tried in this order
        property int sourcesVersion: 0      // 2 = the list knows kugou/qq/local/player, 3 = amll/lrccx/musixmatch (older lists get them once)
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
        property bool gameAsked: false      // the installer already asked "with the game?" (ANGELOS_GAME): the wizard shows that answer
        property bool keyboardAsked: false  // …and the keyboard layouts (KB_LAYOUTS)
        property string from: ""            // the wizard's "where do you come from": windows | mac | linux | new | ""
        property string persona: ""         // the wizard's "who are you": streamer | worker | regular | creative | ""
        property var apps: []               // the apps ticked in the wizard (data/apps-catalog.json ids), browsers included
        property string browser: ""         // the wizard's «Which browser?»: a catalog id or desktop:<file.desktop>; "" = not picked (the default one stays)
        property int introSeen: 0           // the first run's intro last seen (SetupIntro.version): a newer one plays once after the update
        property string telemetry: ""       // send telemetry to the author (services/Telemetry): "" not asked yet | yes | no — asked by the wizard or TelemetryPrompt
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
        property bool caps: true            // Caps Lock: an arrow on the bar while it is on (services/CapsLock)
        property string position: "bottom-center"
        property int ms: 900
    }

    property JsonObject desktop: JsonObject {
        property var widgets: []            // [{uid, type, screen, x, y, size, frame, scale, settings}]; x/y < 0 = from the right/bottom; size s | m | l; frame "" (= widgetFrame) | window | plate | none
        property bool initialized: false
        property string widgetFrame: "window" // the pixel widgets' frame: window (a little .exe window) | plate (a plain plate, its name on hover) | none (straight on the wallpaper)
        property string weatherCity: ""     // the clock's weather: "" = where the IP says (ip-api.com), else a city name (Open-Meteo's geocoding)
        property string widgetSet: ""       // the wizard's widget set: empty | minimum | center ("" = never asked)
        property bool snap: true
        property int gridStep: 8            // the widgets' grid cell, in angelOS pixels: 4 | 8 | 16 | 32 (used while `snap` is on)
        property string titleSuffix: "exe"  // every angelOS window, widget and caption ends in .exe | .sh | .bin (I18n.exe)
        property string widgetStyle: "auto" // desktop widgets: auto (macOS cards with the Golden Gate skin, pixel windows otherwise) | pixel | mac (DesktopWidgets.macStyle)
        // the right-click menu on the wallpaper (services/DeskMenu, Settings → Right-click menu)
        property string menuStyle: "list"   // list (the usual) | wings | harp (heaven's own; in hell the circle's own takes their place) | pentagram
        property var menuQuick: ["clipboard", "screenshot", "terminal", "nextWallpaper"] // the top row of signed icons (up to 6)
        property var menuItems: ["addWidget", "note", "wallpaperPick", "displaySettings", "personalize"] // the list under it, in order (up to 8); "sep" = a line
        property var menuCustom: []         // own entries [{id: "custom:<n>", label, icon, kind: app|command|path|url, target}]
        property string menuSize: "normal"  // compact | normal | large
        property bool menuIcons: true       // icons in the list
        property bool menuLabels: true      // names under the ring's icons
        property bool menuAnim: true        // the ring flies out, the list pops
        property bool menuToys: true        // hell's menu looks play: the wheel spins, the fork pokes… (circles/CircleToy)
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
        property bool files: true           // …and files by name or type ("sex", ".jpeg", ".картинки"), services/FileSearch
        property bool filePreview: true     // thumbnails of pictures and videos in those results, Spotlight's preview
        property bool clipboardPaste: true  // Win+V: the picked entry is pasted into the window you were in, not only copied (services/Clipboard, issue #61)
    }

    // password managers: Bitwarden (bw, rbw) and 1Password (op) in the launcher, services/Vault
    property JsonObject vault: JsonObject {
        property bool enabled: true         // `pw NAME` in the launcher finds logins; Enter copies the password
        property int clearAfter: 30         // seconds until a copied secret is wiped from the clipboard (0 = never)
        property int lockAfter: 15          // idle minutes until a vault the shell opened is locked again (0 = never)
        property bool lockWithScreen: true  // …and when the screen locks
        property bool hideOnStream: true    // on air: names and logins are masked in the results
        property bool everywhere: true      // an open vault's entries also among the launcher's ordinary results, no `pw` needed (never on air)
    }

    // spelling in the shell's own text fields (notes, replies), services/Spell
    // the keys pressed, on screen (Mod+Shift+K; services/KeyCast): shortcuts, and typing if asked;
    // never while a password is typed
    property JsonObject keycast: JsonObject {
        property bool enabled: false
        property bool text: false           // plain typing too, not only shortcuts and special keys
    }

    // Discord: the people of your call as little pixel people walking over the bar (DiscordCrew)
    property JsonObject discord: JsonObject {
        property bool crew: false
        property string crewScreen: ""      // "" = the main screen (Shell.primaryScreen)
        property string crewSize: "m"       // s | m | l — everyone's size
        property string crewMain: "me"      // who is drawn bigger: "me" | "none" | a Discord user id
        property bool crewNames: true       // the names over the heads
        property bool crewBurst: true       // whoever leaves the call bursts
        property bool crewDrag: true        // they take the pointer: carried, thrown, a menu on right click
        property var crewSteps: ({})        // user id → art pixels bigger (+) or smaller (−) than the rest
        property var crewHidden: []         // user ids not shown
    }

    property JsonObject spell: JsonObject {
        property bool enabled: true         // misspelt words are underlined (needs a dictionary: Settings → Keyboard → Spelling)
        property var off: []                // installed dictionaries switched off: ["en-GB", …]
        property bool suggest: true         // the strip of corrections under a note while the caret is in a misspelt word
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
        property string style: "ngo"        // ngo (the NGO stream) | heaven (a game's login screen at heaven's gate)
        property string passwordOn: "main"  // main (Settings → Monitor → Main screen; keys typed on any screen reach it) | focus (where niri's focus is)
        property real size: 1.5             // the login window: ×1 … ×2, kept to whole screen pixels
        property string unlockFx: "auto"    // auto (the look's own) | heart | pixels | crt | gate | glitch | none
        property bool replay: true          // the stream shows a random video, blurred beyond reading…
        property int replayDelay: 30        // …after this many seconds locked
        property string replayDir: ""       // "" = ~/Videos
        property bool streamCam: true       // NGO: the angel in a webcam window (sleeps, peeks, cries, cheers)
        property bool streamMeters: true    // NGO: followers / stress / affection / darkness, from the real machine
        property bool streamAlerts: true    // NGO: polls in the chat, donations, raids, followers, milestones
        property bool highlights: true      // NGO: mistakes become clips, the unlock shows the stream's highlights
        property bool heavenAngel: true     // heaven: the angel by the gate
        property bool wish: true            // heaven: the unlock is a prayer (gacha: 3★/4★/5★, pity)
        property bool dailyReward: true     // heaven: the daily login reward calendar
        property bool notices: true         // heaven: the notice board (updates, notifications, music…)
        property bool wishPaid: true        // heaven: past the day's free prayer, an unlock prays for 160 ✦ (HeavenStars)
        property string chestNotified: ""   // the day the "day's chest is waiting" notification came (services/Chests)
        property string frame: ""           // heaven: the login plate's frame from the pass: "" | rose | holo
        property bool sddmWalls: true       // the login screen (SDDM theme) follows the desktop's wallpapers
    }

    property JsonObject idle: JsonObject {
        property int minutes: 0             // start the idle screen after N idle minutes; 0 = by hand only
        property string text: ""            // "" = angelOS ASCII art
        property string effect: "random"    // random | decrypt | rain | beams | wave | typewriter | hearts | glitch
        property string colors: "accent"    // accent | mono | rainbow
        property bool clock: true
        property bool allScreens: true
        // Always On Display (modules/idle/AodFace): the screens that are not the main one show the
        // time, music, notifications and the devices' charge on black instead of the art
        property bool aod: true
        property bool aodMusic: true
        property bool aodNotifications: true
        property bool aodDevices: true
        property bool aodAngel: true
        // services/Awake: no idle screen, lock, screens off or sleep while…
        property bool awakeStream: true     // …stream mode is on
        property bool awakeFullscreen: true // …a window fills a whole screen (video, game)
    }

    property JsonObject sidebar: JsonObject {
        property bool enabled: false        // experimental
        property string look: "phone"       // phone (a pixel flip phone in 3D, modules/sidebar/Phone) | panel (a plain window)
        property string screen: ""          // "" = first screen
        property string edge: "right"       // left | right | top | bottom — where the tab sits
        property real offset: 0.5           // tab position along that edge, 0..1
        property var sections: ["toggles", "media", "sound", "system", "ai"]
    }

    // the flip phone (services/PhoneLine; Settings → Taskbar → Sidebar)
    property JsonObject phone: JsonObject {
        property bool calls: true           // the angel (or the demon) calls now and then, and texts
        property bool timerCalls: true      // a timer's end rings the phone too
        property bool keyTones: true        // the keys beep (quieter on stream)
        property string ringtone: ""        // the composer's tune for her calls; "" = hers (PhoneScripts.tunes)
        property var look: ({})             // the tuning: {shell, gems, sticker, charm, wall} (PhoneScripts.looks)
    }

    property JsonObject capture: JsonObject {
        property string skin: "ropes"       // ropes | window | stream — region selector and recording overlay
        property bool themeColors: false    // NGO skins in the angelOS theme instead of the NGO palette
        // Settings → System → Screenshots and recording (read by ~/.local/bin/niri-screenshot-region
        // and niri-record-region straight from settings.json)
        property string shotDir: ""         // "" = ~/Pictures/Screenshots
        property string shotFormat: "png"   // png | jpg
        property bool shotCursor: false     // the pointer on the picture
        property bool shotCopy: true        // copied to the clipboard as well
        property bool shotOpen: false       // opened in the image viewer after
        property bool shotPreview: true     // the overlay's saved shot waits in the screen's corner: a click edits it (services/ShotEdit)
        property string shotPreviewAt: "auto" // where: "auto" (a place the angel and the widgets leave free) or a Place.js name
        property bool classic: false        // the screenshot key opens the old region selector, not the overlay
        property string recordDir: ""       // "" = ~/Videos
        property int recordFps: 60
        property string recordAudio: "none" // none | system (what you hear) | mic | both
        property string recordCodec: "auto" // auto (NVENC on NVIDIA, else VA-API, else x264) | nvenc | vaapi | x264
        property bool replay: false         // instant replay: the last seconds of the main screen kept in memory, Mod+Alt+G saves them (services/Capture)
        property int replaySec: 30
        property int discordMb: 20          // «≤20 MB for Discord» (services/VideoGrab): the size a video is squeezed under
        property bool timelapse: false      // the day's timelapse: gpu-screen-recorder writes the main screen at a frame a second, glued at midnight (services/Timelapse)
        property int timelapseStep: 30      // a frame of the video every this many seconds of the day
    }

    property JsonObject plugins: JsonObject {
        property var enabled: ({})          // id -> bool (missing = manifest default)
        property var data: ({})             // id -> plugin settings object
        property var removed: []            // bundled plugins removed by hand (hidden; "Restore" brings them back)
        // Community Plugins (services/CommunityPlugins): the registry checked once a day, a
        // notification for new versions (the ones it told about: notifiedFor)
        property bool autoCheck: true
        property string lastCheck: ""
        property string notifiedFor: ""
        property bool storeRetired: false   // the old stand-alone Community Store plugin moved aside (once)
    }

    property JsonObject dotfiles: JsonObject {
        property string repo: "~/AngelOS-Dotfiles"
        property string command: "./install.sh"
        property string env: "DOTFILES_MODE=full SKIP_PACKAGES=1 INSTALL_VOXTYPE=0 DOWNLOAD_VOXTYPE_MODEL=0 ENABLE_SERVICES=0"
        property bool reloadNiri: true
        property string adminWarned: ""     // the admin verdict last told about (verdict@main@owner): once, not after every restart
    }

    property JsonObject system: JsonObject {
        property string terminal: "kitty"
        property bool convertRing: true     // Shift + right click on files in Strata: the conversion ring (services/Convert)
        property string fileManager: ""     // the Start menu's «Files»; "" = the default one (xdg-open: Strata)
        property string monitor: "auto"
        property string monitorProgram: ""
        property bool monitorInTerminal: false
        property bool monitorFloat: true    // the task manager opens as a floating window (niri rule)
        property string monitorSize: "medium" // compact | medium | large | tall | custom
        property int monitorWidth: 1200     // custom size, logical px
        property int monitorHeight: 760
        property string monitorPlace: "center" // center | corner (bottom-right, next to the tray)
        property bool nautilusDefaults: false // angelOS Nautilus extensions + prefs applied once
        property bool strataDefaults: false // angelOS items in Strata's menu + its theme applied once (services/StrataSetup)
        property string qsWarned: ""        // the outdated Quickshell version already warned about (services/QsVersion)
        property string primaryScreen: ""   // the main screen (widgets, the angel, the lock…); "" = the widest
        property bool primaryAsked: false   // asked once (MainScreenPrompt) where the main screen is, or it was picked already
        property var screenTune: ({})       // Monitor → Brightness and colour: {output: {brightness 0.3–1 (gamma), saturation −1…1 (NVIDIA vibrance)}} (services/ScreenTune)
        property bool focusBoost: true      // the focused window's processes a few nice steps up, back when the focus leaves (niri-game-mode)
        property string helpAgent: ""       // Maintenance → Helper: claude | codex | opencode — the agent «Call the helper» starts with (scripts/help-agent.sh: out of a limit → the next account, Claude profiles → Codex → opencode); "" = Claude
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
        property int paperSeen: 0           // the release whose «what's new» paper was put away (ChangelogPaper)
        property string notifiedFor: ""     // the newest incoming commit told about: once, not after every restart
    }

    property JsonObject network: JsonObject {
        property bool showWifi: true        // bar/sidebar Wi-Fi indicator when a Wi-Fi adapter exists
        property bool showBluetooth: true
        property bool showWired: true       // bar: the wired connection's indicator (when there is a wired adapter)
    }

    // laptops: the battery and what runs on it (services/Power; Settings → System → Battery, Power)
    property JsonObject power: JsonObject {
        property bool showBattery: true     // bar: the battery as hearts (only where there is a battery)
        property bool barPercent: false     // …and the percentage next to them
        property bool alerts: true          // a notification at lowAt, veryLowAt and criticalAt (once per discharge)
        property int lowAt: 20
        property int veryLowAt: 10
        property int criticalAt: 5
        property string criticalAction: "suspend" // at criticalAt, after a minute's warning: suspend | hibernate | poweroff | nothing
        property bool plugSound: true       // the charger in / out: the USB in / out sounds (Golden Gate: its own "power")
        property bool angel: true           // the angel (the demon) notices the battery: tired, sleepy, glad of the charger
        property string eco: "auto"         // the eco mode (Motion "off" + no blur + niri's animations off, no cava spectrum, Settings not kept built): auto | on | off
        property int ecoAt: 30              // auto: on battery at or below this; 100 = whenever on battery
        property bool ecoWithSaver: true    // auto: also while the power profile is "power-saver"
        property bool ecoSaverProfile: true // the eco mode switches the profile to power-saver (and back when it ends)
        property bool esports: false        // the esports power profile: a game all the time (services/Power, niri-game-mode)
        property int chargeLimit: 100       // stop charging at this % (charge_control_end_threshold; 100 = off), set again at every login
        // idle on battery (−1 = as on mains); on mains: lock.idleMinutes, screenOffMinutes, sleepMinutes
        property int batteryLockMinutes: -1
        property int screenOffMinutes: 0    // the screens go dark (niri power-off-monitors); 0 = never
        property int batteryScreenOffMinutes: 5
        property int sleepMinutes: 0        // suspend when idle; 0 = never
        property int batterySleepMinutes: 15
        property bool dim: true             // the backlight dims 30 s before the screens go off (or the lock, or sleep)
        property string lidAction: "suspend"     // the lid closed on battery: suspend | hibernate | lock | nothing
        property string lidActionAc: "suspend"   // …on mains; with a monitor plugged in the lid does nothing (niri turns the panel off)
    }

    // the charge of the mouse, the keyboard, the headphones… (services/Peripherals; the bar's
    // ampoules; Settings → Devices → Device charge)
    property JsonObject peripherals: JsonObject {
        property bool show: true            // bar: an ampoule a device (only where a device reports its charge)
        property bool glyphs: true          // the device's icon next to its ampoule
        property string percent: "low"      // the number next to it: never | low | always
        property bool keyboardAccent: false // the keyboard's lights follow the system's colour (services/Devices)
        property var keyboardColors: []      // the colours last given to the keyboard's lights, newest first (Settings → Device driver)
        property int showBelow: 100         // on the bar only the devices at or below this % (100 = all of them)
        property string sort: "manual"      // manual (the list in Settings) | lowest (the emptiest first)
        property int max: 4                 // at most this many on the bar, the rest in the panel
        property string size: "normal"      // the ampoule's width: slim | normal | wide
        property bool rack: true            // the shelf they stand on
        property string palette: "realm"    // the liquid: realm (the theme's accents; blood and fire in hell) | traffic | ice | mono | custom
        property var colors: ["#e5484d", "#f5c542", "#3fb68b"] // custom: empty, half, full
        property string paint: "height"     // height: the colours run up the glass and the charge cuts them | level: all of it in the level's colour
        property bool steps: true           // pixel steps, a colour an art-pixel row; false = blended
        property bool glint: true           // the glass's pixel highlight
        property bool bubbles: true         // bubbles rise while it charges
        property bool alerts: true          // a notification at lowAt and veryLowAt (once per discharge, per device)
        property int lowAt: 20
        property int veryLowAt: 10
        property bool fullAlert: false      // …and when one is charged
        property bool angel: true           // the angel (the demon) notices a device running low
        property bool upower: true          // source: UPower (Bluetooth, Logitech, gamepads)
        property bool vendor: true          // source: the makers' own HID reports (scripts/peripherals.py: LAMZU)
        property bool headset: true         // source: headsetcontrol, where installed (USB headsets)
        property int pollMinutes: 5         // how often the last two are asked
        property int keepMinutes: 1440      // a device that stopped answering stays this long (as it was for ten minutes, then dimmed); 0 = gone at once
        property var hidden: []             // device ids left out
        property var names: ({})            // id -> a name of your own
        property var kinds: ({})            // id -> its icon: mouse | keyboard | headset | gamepad | phone | pen | speaker | touchpad | other
        property var sequence: []           // ids in your order (sort: manual); new ones go to the end
    }

    // laptops: keys, the backlight, the lid, a convertible (services/Laptop, Backlight)
    property JsonObject laptop: JsonObject {
        property bool keys: true            // cfg/angelos-laptop.kdl: brightness, keyboard light, touchpad, airplane, Mod+P projection keys
        property int brightnessStep: 5      // % per brightness key press
        property real minBrightness: 0.02   // the keys never go darker than this (0 would black out some panels)
        property bool kbdAuto: true         // the keyboard light goes out with the screen and comes back with it
        property bool autoRotate: true      // a convertible in tablet mode turns the screen with the accelerometer
        property bool rotationLock: false   // …held where it is
        property bool tabletKeyboard: true  // tablet mode starts the on-screen keyboard (wvkbd / squeekboard when installed)
        property bool fingerprint: true     // the lock takes a finger too (fprintd with an enrolled finger)
    }

    // touchpad gestures of angelOS's own (scripts/gesture-watch.py; niri keeps its 3-finger
    // swipes and the 4-finger one up/down); gesture -> action id (services/Gestures.actions)
    property JsonObject gestures: JsonObject {
        property bool enabled: true
        property var map: ({})              // {"pinchIn": "launcher", …}; missing = Gestures.defaults
        property string sensitivity: "normal" // low | normal | high
    }

    property JsonObject y2k: JsonObject {
        property bool helper: true          // the pixel angel in a screen corner
        property string helperScreen: ""   // "" = the main screen (Shell.primaryScreen), "focus" = where the focus is
        property string helperTips: "rare" // off | rare | often
        property bool helperGreeted: false
        property bool sparkles: true        // sparkle trail over the bare desktop
        property var sparkleScreens: []     // empty = every screen
        property bool sounds: true
        property bool settingsMusic: true   // the P5 settings window's lounge loop (data/sounds/settings)
        property real soundVolume: 0.55
        property real helperVolume: 0.6     // the angel's / demon's voice, pips and effects, on top of soundVolume
        property var soundOff: ["click"]    // events kept quiet: startup notify error click shutdown angel
        property var soundTweaks: ({})      // System sounds: {event: {on, vol (0–1.5), sound ("" | other event | "file:/path"), vary}}
        property bool circleDuck: true      // programs slide to 0 while hell's circles change, then back to their faders (services/AppDuck)
        property var clickButtons: ["left", "right"] // which mouse buttons make the click sound (left right middle)
        property bool clickRelease: false   // a softer tick when the button comes up
        property bool quietFullscreen: true // over a fullscreen window (games, films) only the volume and screenshot sounds
        property bool quietHours: false     // no sounds from quietFrom to quietTo (hours)
        property int quietFrom: 23
        property int quietTo: 8
        property bool boot: true            // CD-ROM style loading screen once per login
        property var bootScreens: []        // empty = every screen
        property string soundPack: "y2k"    // y2k (synthesised here) | overdose (NEEDY GIRL OVERDOSE sounds, downloaded on first use) | pc2k («Нулевые», data/sounds/pc2k)
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
        property string angelSkin: ""       // the angel's colours from heaven's prayers: "" | moon | mint | gold (services/HeavenStars)
        property string angelLook: "glitch" // glitch (cracked halo, pictures) | chibi (the first pictures) | adult (30×40 pixels) | mini (the first 20×21); kept as picked while the story shows her otherwise (Angel.angelLook)
        property string demonLook: "glitch" // the same for the demon (glitch: the sleepless neon one)
        property real helperScale: 1.0      // 0.75–2.00: Ctrl + mouse wheel, 5 % a notch; rendered size capped to screen (Y2K → Helper → Size)
    }

    // Recovery (services/Recovery, scripts/recovery.py): progress and settings on your GitHub
    property JsonObject recovery: JsonObject {
        property bool auto: true            // with gh logged in: save to the private repo once a day
        property string lastPush: ""        // ISO time of the last save there
    }

    // Wellbeing (services/Wellbeing; Settings → Wellbeing), like GNOME's: how long you sit at the
    // computer (~/.local/state/angelos/screen-time.json), a daily limit, and breaks the angel
    // (the demon) reminds you of — the eyes, a stretch, water
    property JsonObject wellbeing: JsonObject {
        property bool track: true           // count the screen time (input within the last 2 minutes, unlocked)
        property bool apps: true            // …and per app (the focused window's app id)
        property int dailyLimit: 0          // minutes a day; 0 = no limit
        property bool limitWarn: true       // at the limit: the angel says so (and again after "15 more minutes")
        property bool breaks: true          // the reminders at all
        property string via: "angel"        // angel (a notification when she's not around) | notify
        property bool eyes: true            // look into the distance (20-20-20)
        property int eyesEvery: 20          // minutes of use
        property bool move: true            // get up and stretch
        property int moveEvery: 60
        property int moveLength: 5          // minutes away from the computer that count as the break
        property bool water: true           // a glass of water
        property int waterEvery: 60
        property int waterGoal: 8           // glasses a day
        property bool quietFullscreen: true // a game or a video fills the screen: the reminder waits
        property bool quietStream: true     // the stream mode: the reminder waits
        property bool quietDnd: false       // do not disturb: the reminder waits (off: she is not a notification)
        property int keepDays: 60           // history kept
    }

    // the game: angelOS is a story played over the real desktop (services/Story, story/).
    // The player's save is its own file (~/.config/angelos/save.json), not here.
    property JsonObject game: JsonObject {
        property bool enabled: true         // false: plain dotfiles — no angel, demon, novel or hell (installer ANGELOS_GAME=0, the setup wizard, `angelos game off`)
        property bool diaryTab: true        // the diary's bookmark on a screen edge (modules/diary/DiaryTab), once its key is had
        property string diaryEdge: "left"   // left | right | top | bottom — where the bookmark sits (dragged there)
        property real diaryOffset: 0.35     // its place along that edge, 0..1
        property string diarySide: ""       // the Angel's diary opens from: "right" | "left" | "" (the author's pick, story/diary.json → side)
        property bool calm: false           // older settings: became appearance.motion "calm" (config/Motion migrates it once)
    }

    // games: a fast mouse thinned while one runs (.local/bin/mouse-coalesce; niri-game-mode's flag)
    property JsonObject gaming: JsonObject {
        property int mouseRate: 0           // motion reports a second in games: 0 = the mouse as it is | 1000 | 2000 | 4000
        property string mouseDevice: ""     // a part of the mouse's /dev/input/by-id name ("" = the first USB mouse)
        property bool tuneNotes: true       // a new Steam game gets its note: Proton and launch options (services/GameTune)
        property int backgroundFps: 30      // angel-niri: while a game runs, the other screens redraw at most this often (0 = as they are; niri-game-mode)
        property bool tearing: true         // angel-niri: a fullscreen game's frames shown at once, not at the next vblank (niri-game-mode → set-tearing)
        property bool pointerLock: true     // angel-niri: the pointer stays on a focused fullscreen game's screen, Mod lets it out (niri-game-mode → set-pointer-lock)
        property bool gpuClocks: true       // NVIDIA: the graphics clock kept up while a game runs (niri-game-mode → scripts/gpu-clocks-setup.sh's helper)
    }

    // the novel (services/Novel, ~/AngelOs-Nov): chapters the angel plays out on the desktop
    property JsonObject novel: JsonObject {
        property bool enabled: true
        property string dir: "~/AngelOs-Nov"   // story/*.json and sprites/<who>/*.png (the author's editor: `angelos novel edit`)
        property string gender: ""          // from the setup wizard: m | f | "" (not said) — she still asks
        property string name: ""            // how she calls you ({name}); "" = the login name
    }

    // Quick Share: LocalSend's protocol without the app (services/QuickShare, scripts/quickshare.py)
    property JsonObject quickshare: JsonObject {
        property bool enabled: true         // be seen by and find LocalSend devices on this network
        property string alias: ""           // how others see this computer; "" = "angelOS <hostname>"
        property string receive: "ask"      // ask (everyone, with a question) | trusted (only trusted, no question) | off
        property string dir: ""             // "" = ~/Downloads/LocalSend
        property var trusted: []            // [{fp, alias}] — their files come without a question
        property string pin: ""             // asked from senders when set
        property bool kdeconnect: true      // KDE Connect's devices too (its daemon, package kdeconnect): a phone with its app gets files while locked
    }

    // Quick Look: Space on a file in Nautilus (services/QuickLook, scripts/quicklook.py)
    property JsonObject quicklook: JsonObject {
        property bool enabled: true         // answer Nautilus's Space (the name GNOME's sushi uses)
    }

    // the Halo (Нимб, services/Halo, modules/halo): a pixel Dynamic Island at the top centre — music
    // with its lyrics, timers, recordings as capsules over the windows; a thin arc when nothing happens
    property JsonObject halo: JsonObject {
        property bool enabled: true
        property var screens: []            // empty = every screen
        property int hoverMs: 400           // the pointer resting this long opens it (a click at once)
        property string size: "m"           // s | m | l: the pill's and the cards' scale
        property bool showMusic: true       // what gets a capsule (Settings → Halo)
        property bool showTimers: true
        property bool showRec: true
        // at rest, the closed pill instead of the bare arc (Settings → Halo → «At rest»): a side
        // each — clock | weather | screen (time today) | none — and the arc or the angel between
        // them; both sides none and the arc = the thin arc alone, as it was
        property string idleLeft: "clock"
        property string idleRight: "weather"
        property string idleMiddle: "cat"   // ring | cat (modules/halo/HaloCat.js: RunCat's cat runs with the processor, sleeps after a minute without input; the old "angel" = cat)
        property bool catBongo: true        // the cat taps a paw on its desk for each key pressed (services/KeyCast --taps: the side only)
        property int idleRotate: 0          // s; the right side turns through the others this often (0 = it stays)
        property int pauseKeep: 30          // s; paused music keeps the pill this long, then the pill rests and a ▶ bubble with its cover stays beside it (0 = at once)
        property bool musicSmart: true      // music without synced lyrics (a browser video, a song with none) doesn't take the pill: its cover and dancing bars take the right side, its title peeks 5 s on a new track
        property int hintsLeft: 3           // the first openings at rest show what the wheel, a drop and a right click do; ✕ = 0
        property bool privacyDot: true      // an orange (microphone) / green (camera) dot beside it while a program records (services/Sensors)
        property bool shotThumb: true       // a saved screenshot's picture in the pill for a few seconds: drag it out or onto the shelf
        property bool coverTint: true       // the pill's outline and the dancing bars in the colour of the song's cover
        property string anim: "steps"       // how the pill grows: steps (whole 8-bit jumps) | spring (a bounce)
        // the look (modules/halo HaloWindow `skin`): ears | notch | float | tamagotchi
        // (classic, win98, neon, lcd and ticker were dropped 16.10: Halo.skin falls back to notch)
        property string skin: "notch"
        property string musicView: "cover"  // the open Halo's song tile: cover (a square picture) | cassette (reels turning) | vinyl (a spinning record)
        property bool redesignOnce: false
        property bool notify: true          // a notification: 3 s in the pill (its icon, the app, the title), the text when you point at it; the corner popup then stays away (critical ones still come)
        property bool osd: true             // volume, the microphone and brightness: a bar in the Halo instead of the OSD box (where the Halo is)
        property bool calls: true           // a call (a program from the list taking the microphone): a green capsule, its time, mute (that program's capture only), open the program
        property var callApps: []           // more call programs (a part of the name PipeWire knows them by)
        property string overFullscreen: "nothing" // over a full-screen game or film: nothing | timer (a timer's end only)
        property bool streamHide: false     // on a streamed screen: no file names, pictures or notification texts in it (off: the viewers see it all)
        property bool nightDim: true        // after sunset (the weather's city) the Halo dims a little and the cat sleeps sooner   // 16.10 redesign: an install moved once to the notch look and the steps
        property bool fixedWidth: true      // the closed pill keeps one width whatever it shows (the text is cut to fit)
        property bool bassGlow: true        // the music's pill moves with the bass (services/Bass, shaders/halo_bass)
        property string bassStyle: "dither" // dither (a pixel band along the inner edge) | halo (an arc over the pill, a ring on a kick; the pill comes down 4 px)      // how the pill grows: spring (a bounce) | steps (in whole 8-bit jumps)
        // the quick buttons page, in this order (services/HaloButtons.catalog has them all)
        property var buttons: ["pomodoro", "timer", "record", "picker", "note"]
        property bool reserve: true         // a strip of its own at the top: windows start below it, no tab is covered (the open card still lies over)
        // with the strip (reserve): bar (like a Mac's menu bar: windows start and stay below it) |
        // maximized (only maximized and snapped windows keep clear, the rest may go under) |
        // hide (no strip: the Halo slides away while a window touches the top, back on hover)
        property string windows: "bar"
        property bool browserBridge: true   // the browsers' download percent: their small extension (scripts/browser-downloads.py)
    }

    // the mini island (services/Island, scripts/island): links open in a small browser of its own
    property JsonObject island: JsonObject {
        property bool enabled: true         // links from Circle, the clipboard, notifications open there (else the browser)
        property var size: []               // [w, h] once the user resized it (else landscape 960×640, fitted to the screen)
    }

    // the screenshot = Circle to Search / Live Text (services/CircleSearch, Mod+Shift+S / Print; Settings → Screenshots)
    property JsonObject circle: JsonObject {
        property string engine: "google"    // plugins/web-search/Engines.js: google | duckduckgo | yandex | ecosia | bing | brave | mojeek
        property string translateTo: "auto" // auto (Cyrillic → en, else → ru) | ru | en | uk | de | ja | …
        property bool liveText: true        // read the whole screen at once and outline the words
        property bool lens: true            // the "search the picture" button (Google Lens)
        property bool lensWindow: true      // Lens's results in angelOS's own window (services/LensSearch), else Google's page in the island
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
        property bool castHinted: false     // the angel told once that OBS can take her onto the stream (StreamMode.hintCast)
        // the chat on screen (services/StreamChat): a chat reader's session log, read only
        property string chatLog: ""         // the folder of its *.jsonl logs ("" = off)
        property bool chatHalo: true        // each message a moment on the Halo, the cat there cheering
        property bool chatRunners: true     // a little cat with the nick runs along the bottom of the streamed screen
        property bool chatRunnersViewersOnly: true // angel-niri: the cats only in the stream's capture, not on the monitor
        // privacy on stream (services/Privacy): the mode on by itself while OBS is live
        property bool privacyAuto: false
        property bool privacyPlates: true   // a «Privacy ON» plate over each hidden window, for the viewers alone (modules/y2k/PrivacyCast: OBS's window capture)
        property bool privacySet: false     // …and it was the stream that switched it on (off again when the stream ends)
        // what the viewers see over a hidden window, drawn by angel-niri (services/Privacy:
        // set-privacy-look): plate | mosaic | cat | angel | image | black; the picture for image;
        // apps with their own {appId: {look, image}}
        property string privacyLook: "plate"
        property string privacyImage: ""
        property var privacyApps: ({})
        // the angel on stream (services/StreamAngel, modules/y2k/AngelHelper): she sits on the
        // streamed screen's taskbar (its bottom edge when the bar is elsewhere) and talks with the mic
        property bool streamer: false
        // turned off from her own menu ("Перестать быть стримером"): her menu offers it back
        property bool streamerDropped: false
        property string streamerMic: "auto" // auto | obs:<OBS input> | pw:<PipeWire source> (scripts/stream-mic.py)
        property int streamerThreshold: 30  // % of the voice meter (-55…-12 dBFS) where her mouth opens
        property int streamerSize: 30       // % of the screen's height above the bar (10–50; Ctrl + wheel on her)
        property string streamerSide: "right" // right | left — the bottom corner she sits in
        property string streamerScreen: ""  // "" = the first streamed screen (else the main one)
        // where you see her (Mod+Alt+A switches): screen — on your screen too | obs — only in
        // her own window for OBS (modules/y2k/StreamerCast: "Window capture (PipeWire)" →
        // "angelOS · ангел для OBS"), which draws her all the time OBS runs either way
        property string streamerView: "screen"
        property bool streamerKeys: true    // the niri key Mod+Alt+A (cfg/angelos-windows.kdl)
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
        // the Settings window's look (services/SettingsLook): win11 (the Windows 11 view, the default
        // while P5 is being redone) | p5 (the P5 window over the desk); asked once (SettingsLookPrompt)
        property string look: "win11"
        property bool lookAsked: false
        property bool skinChosen: false     // the look was picked (the wizard, or the banner on the settings home)
        property var usage: ({})            // page id -> visits; "Everyday" on the home page follows it
        property var searchHistory: []      // what was searched and opened, newest first: [{q, title, page, icon}] (SettingsView: a click into the empty search shows it)
    }

    // the Golden Gate skin (settingsUi.skin "goldengate"; services/GoldenGate, modules/mac): the
    // whole desktop like macOS 27 for people coming from a Mac
    property JsonObject mac: JsonObject {
        property real glass: 0.35           // Liquid Glass: 0 clear … 1 tinted (like Appearance → Liquid Glass)
        property bool reduceTransparency: false // solid glass: no blur, no rim shader (Accessibility → Display, like macOS)
        property bool sounds: true          // Golden Gate's system sounds (data/sounds/macos, yours in ~/.local/share/angelos/sounds/macos)
        property real soundVolume: 0.5      // their volume, 0 … 1 (on top of the system's)
        property bool volumeSound: true     // the "pop" when the volume changes
        property string accent: "blue"      // blue | purple | pink | red | orange | yellow | green | graphite
        property bool barBackground: false  // the menu bar on a band of its own ("Show menu bar background")
        property bool appMenus: true        // the focused app's own menus in the menu bar (scripts/appmenu.py)
        // Qt apps' menus in the menu bar too: the AppMenu registrar on the bus, so Qt apps started
        // while it is there export their menu bar and hide their own. Off: Qt apps keep their own menus
        property bool qtGlobalMenu: false
        // apps that draw their own title bar: Golden Gate's Qt frame (QT_WAYLAND_DECORATION adwaita) is
        // not put over them (Shell.envFor; desktop ids or app ids)
        property var ownFrameApps: ["org.telegram.desktop", "TelegramDesktop", "com.ayugram.desktop", "io.github.kotatogram", "org.materialgram.desktop"]
        property bool keys: false           // Mac-style shortcuts: Golden Gate's key profile (cfg/keybinds-macos.kdl, services/KeyProfile) — offered, never imposed
        property string minimizeEffect: "genie" // genie | scale — how a window goes to the Dock (modules/mac/MacMinimizeFx)
        property int dockSize: 48           // Dock icons, logical px
        property bool dockMagnify: true     // icons grow under the pointer
        property int dockMagnifySize: 96    // the icon right under the pointer, logical px (dockSize..128)
        property bool dockMacIcons: true    // MacTahoe's icons in the Dock (DockIcons, scripts/mac-icons.py)
        property bool dockAutohide: false
        property string dockPosition: "bottom" // bottom | left | right — the screen's edge the Dock stands on
        property var dockApps: []           // desktop ids in the Dock; empty: Start's pinned apps
        property string font: ""            // "" = Inter (open, drawn close to SF Pro); any installed family
        property bool wallpaper: true       // the skin's own wallpaper (scripts/goldengate-wallpaper.py), light or dark with the theme
        property var wallBefore: ({})       // the wallpapers it replaced, given back when the skin goes
    }

    property JsonObject developer: JsonObject {
        property bool enabled: false
        property bool showLaptop: false      // developer mode: the laptop's settings on a desktop too, to show them (services/Laptop.has)
        property string provider: "claude-cli" // claude-cli | codex-cli (browser login) | openai | anthropic (API key)
        property string openaiModel: "gpt-5.4"
        property string anthropicModel: "claude-opus-5-5"
        property string claudeCliModel: "sonnet" // "" = the CLI default; aliases: haiku / sonnet / opus / fable
        property string codexCliModel: ""
        property var efforts: ({})          // provider -> low | medium | high | xhigh | max | ultra ("" = model default)
        property int autoRepair: 1          // automatic repair rounds after failed checks (0–2)
        property int maxOutputTokens: 32000
    }

    // what the right-click menus hold besides the desktop's (services/DeskMenu)
    property JsonObject menus: JsonObject {
        // panel | task | widget → {quick: [ids], items: [ids]}; missing = DeskMenu.defaults
        property var layouts: ({})
        // the middle button's ring on the wallpaper: eight ids clockwise from the top ([] = DeskMenu.ringDefault)
        property var ring: []
        // the plugins' entries switched on ("<plugin>:<n>", a menu component "<plugin>:menu")
        property var plugins: []
    }
}
