pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.config
import qs.services
import qs.modules.settings
import qs.modules.y2k
import qs.modules.alttab
import qs.modules.bar
import qs.modules.bar.parts
import qs.widgets
import "../../novel/NovelCore.js" as Core
import "../../services/Intents.js" as Intents
import "../../widgets/Icons.js" as Icons
import "../../widgets/IconSets.js" as IconSets

// angelOS UI self-test, started by scripts/test-ui.sh (ANGELOS_TEST=1, Qt's
// offscreen platform, a throwaway HOME). Inside the real shell, so the type
// anchors of shell.qml are the ones in use:
//   pages     every settings page loads in each settings skin (no errors), the sidebar is
//             always there; sub-pages (advanced groups) open on their own; ◀ ▶ history
//   views     every settings view (sidebar, Control Panel, Properties, tiles) in each skin:
//             its home, a page, a plugin's page, the search, the keyboard, `settings <page>`
//   previews  every preview scene loads and plays through its frames
//   search    settings search: 40 typical queries, average and worst time
//   rig       the helper's pictures (SpriteRig): both figures read, sized as
//             their rig.json says, all nine circle skins, swapped and played through without errors
//   alttab    the Alt+Tab switcher styles (and hell's own) load and follow the pick
//   bar       bar widgets (Wi-Fi, Bluetooth, wired, tray, desk sprites) load, their panels open
//   wrap      long switch labels wrap inside a narrow group instead of running past it
//   start     every Start look (the bodies of StartOverlay) loads, searches, walks with the keys, Esc closes
//   heaven-menus  heaven's own right-click menus (wings, harp) build round a pointer; all
//             16 entries fit and stay apart at every size on landscape and portrait screens at
//             scale 1–2, middle and corner; their ink reads in every heaven palette
//   hell      the built-in desktop widgets and a hell window frame load in heaven and in hell,
//             the widgets burn over and back, the six hell cursors are in the catalog; each
//             circle's own Settings dress and right-click menu build and read
//   game      the save (services/Story) loads, all nine circles and every scene are valid
//             data, each circle has its trial; a fall lands on the heaviest sin, a right
//             answer goes a circle deeper, the pact gets out with its mark; the game turns
//             off and on again
//   game-exit the way out of hell with the game's clock moved instead of waited (issue #31):
//             too early → the minutes left; ten minutes later → the trial; a time saved in
//             the future, a scene that no longer exists, limbo across a restart, a player
//             stuck under the old rules (a broken plea counter) — none blocks the way out;
//             pleas are understood in any wording, with typos and the wrong layout
//   debug     the game's debug panel: every tab builds, its writes and overrides take
//   pace      into hell through the portal shows the circle; back and forth within
//             story/game.json's pace.quickSwitch is instant, later the whole show again (C1)
//   walls     heaven's wallpaper stays as it is in hell, a pick in hell lasts for its circle,
//             an older save is untangled, hell's accent is its own (C2)
//   motion    Motion off: no animation lengths, heaven ⇄ hell at once without the shows;
//             calm is the game's calm; the old game.calm toggle migrates (C4); heaven's own
//             menus never show in hell
//   achievements  the list is valid, each heaven thing has its achievement; the game off opens
//             all of heaven and counts nothing, on again re-locks; earning and taking back
//             open and lock; counts, kinds, progress; the demon's pranks count for nothing
//   cava      the cava widget (over a stand-in cava) starts, and starts again after it was
//             hidden and shown with the same config (B4: the lock, sleep, a fullscreen game)
//   rmb       a right-click menu opens where the button went down (B2); a right click into
//             the window's corner pixel does not crash Qt
//   setup     the first-run wizard holds the desktop (Start, the launcher, the clipboard, the
//             session menu, Settings, Alt+Tab wait; the screens count as unseen) and
//             `angelos setup skip` lets it go; opened again it is a window holding nothing,
//             every question shows (the keyboard's from Settings, through the tree) and the
//             last one finishes
// Prints "TEST <name> PASS|FAIL [detail]" and "TEST-PAGE <id>" markers (the
// script ties log errors to the page that caused them), "TEST DONE <n>" last.
Scope {
    id: root

    property int failures: 0
    property int rigStep: 0                 // the sprite-rig phase: which look, asked yet, what it saw
    property bool rigAsked: false
    property var rigSeen: []
    SetupFlow {
        id: wizard
    }
    property var setupSeen: []
    property int setupBack: -1
    function named(item, name) {
        // the first item under `item` with this PxGroup name
        if (!item)
            return null;
        if (item.name === name && item.advanced !== undefined)
            return item;
        for (const c of item.children || []) {
            const f = named(c, name);
            if (f)
                return f;
        }
        if (item.contentItem && item.contentItem !== item)
            return named(item.contentItem, name);
        return null;
    }
    function report(name, ok, detail) {
        if (!ok)
            failures++;
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + (detail ? " " + detail : ""));
    }

    FloatingWindow {
        id: win
        implicitWidth: 1100
        implicitHeight: 780
        title: "angelOS self-test"
        color: Theme.desk

        SettingsView {
            id: view
            anchors.fill: parent
            hostWindow: win
        }
        // a second Settings window (Shell.newSettingsWindow): a place of its own, built for the
        // "multi" phase only
        Loader {
            id: second
            active: false
            visible: false
            width: 1000
            height: 700
            sourceComponent: SettingsView {
                settingsNav: SettingsNav {
                    settingsPage: "sound"
                }
            }
        }
        // A built-in app window without a skin override follows the selected Windose look.
        PxWindow {
            id: appWindow
            visible: false
            width: Theme.u * 180
            height: Theme.u * 120
            title: "angelOS app"
            Column {
                spacing: Theme.u * 6
                PxText {
                    text: "angelOS app"
                    kind: "big"
                }
                PxField {
                    placeholder: "Search…"
                    width: Theme.u * 115
                }
                PxButton {
                    id: appAction
                    text: "Action"
                }
            }
        }
        PxPreview {
            id: preview
            visible: false
            width: Theme.u * 200
        }
        TestEvent {
            id: sim
        }
        // a right-click menu area (the wallpaper's, a widget's, the bar's)
        ContextClick {
            id: ctxClick
            width: 400
            height: 300
            z: -100
            visible: false          // only for its check: the corner-pixel test needs nobody there
            property var got: null
            onMenu: (x, y) => got = Qt.point(x, y)
        }
        SpriteRig {
            id: rig
        }
        // the Alt+Tab switcher's looks, with a stand-in for its window
        Loader {
            id: altTabStage
            property string style: ""
            active: style !== ""
            sourceComponent: style === "ngo" ? atNgo : style === "y2k" ? atY2k : style === "hell" ? atHell : atAngel
        }
        Component {
            id: atAngel
            AltTabAngel {
                host: altTabHost
            }
        }
        Component {
            id: atNgo
            AltTabNgo {
                host: altTabHost
            }
        }
        Component {
            id: atY2k
            AltTabY2k {
                host: altTabHost
            }
        }
        Component {
            id: atHell
            AltTabHell {
                host: altTabHost
            }
        }
        // bar widgets outside a real bar (the layer-shell bar needs a compositor)
        Loader {
            id: barStage
            active: false
            sourceComponent: Row {
                property alias wifi: wifiW
                property alias bt: btW
                property alias wired: wiredW
                property alias tray: trayW
                WifiButton {
                    id: wifiW
                }
                BluetoothButton {
                    id: btW
                }
                WiredButton {
                    id: wiredW
                }
                Tray {
                    id: trayW
                }
                Workspaces {
                    screenName: "TEST-1"
                }
            }
        }
        // switch labels on a page as narrow as the grimoire's right one
        Loader {
            id: wrapStage
            active: false
            sourceComponent: Column {
                id: wrapPage
                readonly property string long: "Калькулятор: 2+2·3, 15% от 200, 10 км в милях, 100 usd в rub"
                property alias group: groupW
                property alias direct: directT
                property alias inRow: rowT
                property alias row: rowW
                property alias inColumn: colT
                property alias row2: row2W
                property alias short: shortT
                property alias free: freeT
                width: Theme.u * 170
                PxGroup {
                    id: groupW
                    width: parent.width
                    title: "wrap"
                    PxToggle {
                        id: directT
                        text: wrapPage.long
                    }
                    PxToggle {
                        id: shortT
                        text: "Да"
                    }
                    SettingRow {
                        id: rowW
                        label: "Поиск"
                        PxToggle {
                            id: rowT
                            text: wrapPage.long
                        }
                    }
                    SettingRow {
                        id: row2W
                        label: "Поиск"
                        Column {
                            width: parent.width
                            PxToggle {
                                id: colT
                                text: wrapPage.long
                            }
                        }
                    }
                }
                // nothing fixes the width here: the label stays on one line
                Row {
                    PxToggle {
                        id: freeT
                        text: wrapPage.long
                    }
                }
            }
        }
        // the desktop widgets' content in heaven and in hell (Theme.realm), and a hell frame
        // (hidden: cava must not start its audio tap here)
        Loader {
            id: hellStage
            property string kind: ""
            visible: false
            active: kind !== "" && kind !== "frame"
            source: active ? Quickshell.shellDir + "/modules/desktop/widgets/" + kind + "Widget.qml" : ""
        }
        // the cava widget for real, over test-ui.sh's stand-in cava (it prints frames like
        // the real one): hidden and shown again it must come back (B4)
        Loader {
            id: cavaStage
            active: false
            width: 200
            height: 100
            source: Quickshell.shellDir + "/modules/desktop/widgets/CavaWidget.qml"
            onLoaded: {
                item.screenName = "selftest";
                item.widget = {
                    "uid": "selftest",
                    "settings": {}
                };
            }
        }
        Loader {
            id: frameStage
            active: hellStage.kind === "frame"
            sourceComponent: PxWindow {
                hell: true
                compact: true
                title: "clock.exe"
                width: Theme.u * 120
                height: Theme.u * 60
            }
        }
        // the Start looks outside their layer-shell overlay
        Loader {
            id: startStage
            property string style: ""
            active: style !== ""
            sourceComponent: ({
                    "classic": stClassic,
                    "win11": stWin11,
                    "fullscreen": stFull,
                    "xmb": stXmb,
                    "windose": stWindose,
                    "wii": stWii,
                    "spotlight": stSpot
                })[style] || null
        }
        Component {
            id: stClassic
            StartMenuBody {}
        }
        Component {
            id: stWin11
            StartWin11 {}
        }
        Component {
            id: stFull
            StartFullscreen {
                width: 1100
                height: 780
            }
        }
        Component {
            id: stXmb
            StartXmb {
                width: 1100
                height: 780
            }
        }
        Component {
            id: stWindose
            StartWindose {}
        }
        Component {
            id: stWii
            StartWii {
                width: 1100
                height: 780
            }
        }
        Component {
            id: stSpot
            StartSpotlight {}
        }
        QtObject {
            id: altTabHost
            property var screen: null
            function appName(w) {
                return w ? w.app_id : "";
            }
            function place(w) {
                return w ? "desk " + w.workspace_id : "";
            }
        }
        RightClickGuard {}
    }
    // a window that never takes focus, like the shell's layer-shell panels: Qt
    // 6.11 crashes on a right click at its (0,0) unless something accepts it
    // another window takes the focus, so `bare` has no active focus item
    Window {
        id: focusThief
        width: 40
        height: 40
        visible: false
    }
    Window {
        id: bare
        width: 160
        height: 120
        visible: false
        flags: Qt.WindowDoesNotAcceptFocus
        color: Theme.desk
        RightClickGuard {}
    }

    readonly property var queries: ["обои", "звук", "крупнее", "прозрачность панели", "хоткеи", "курсор", "шрифт", "блокировка", "заставка", "уведомления", "bluetooth", "wi-fi", "монитор", "частота обновления", "раскладка", "скорость мыши", "тёмная тема", "цвет", "лирика", "виджеты", "часы", "пуск", "панель сверху", "остров", "анимация", "сердечки", "скриншот", "запись экрана", "геймпад", "плагины", "обновления", "ангел", "демон", "стрим", "wallpaper", "volume", "bigger", "shortcuts", "transparency", "notifications"]
    // variants worth playing per scene ("" = the scene's default)
    readonly property var variants: ({
            "WallpaperFx": Wallpapers.transitions.map(t => t.id),
            "StartMenu": ["classic", "win11", "fullscreen", "xmb", "windose", "wii", "spotlight"],
            "BarStyle": ["taskbar", "top", "island", "dock", "capsules", "windose"],
            "DeskSwitch": WorkspaceAnim.styles.map(s => s.id),
            "OpenFx": WindowAnim.openStyles.map(s => s.id),
            "CloseFx": WindowAnim.closeStyles.map(s => s.id),
            "LockScreen": ["pixelate", "hearts", "reactions", "indicators", "stream", "heaven", "fx:heart", "fx:pixels", "fx:crt", "fx:gate", "fx:glitch"],
            "CaptureSkin": ["ropes", "window", "stream"],
            "CircleFx": ["full", "calm", "off"],
            "Breakage": ["circle", "glass", "tv", "burn", "claws", "sigil", "fog", "whirl", "ooze", "coin", "ripple", "spatter", "pitch", "frost", "random"]
        })

    property string phase: "wait"
    property var list: []
    property int index: -1
    property double started: 0
    property bool expertPass: false
    property int navStep: 0
    property int switchStep: 0
    property string navNote: ""
    property int multiStep: 0
    property var settingsSkins: ["classic", "windose", "stream"]
    property int settingsSkinIndex: 0
    property bool settingsShotPending: false
    property string settingsShotFlavor: ""
    property string settingsShotMode: ""
    property bool undoFrom: false
    property var altTabStyles: []
    property var startStyles: []
    property var startSeen: []
    property bool startTried: false
    property string startShot: ""
    property var hellSteps: []
    property var hellSeen: []
    property bool hellLoaded: false
    property var altTabSeen: []
    property string altTabShot: ""
    readonly property string shots: Quickshell.env("ANGELOS_TEST_SHOTS") || ""
    property bool undoDone: false
    property int cavaFirst: 0
    property int paceRuns: 0
    property bool paceSlow: false
    property int undoSteps: 0
    // views: [view, skin] cases and where in one case the driver is
    property var viewCases: []
    property int viewCase: -1
    property int viewStep: 0
    property var viewNote: null

    Timer {
        id: tick
        interval: 20
        repeat: true
        running: true
        onTriggered: root.step()
    }
    // a whole run must not hang CI (test-ui.sh gives the whole shell 300 s; a run takes
    // ~110 s here and GitHub's runner is slower, so 140 s was too tight)
    Timer {
        interval: 285000
        running: true
        onTriggered: {
            root.report("timeout", false, "phase " + root.phase);
            root.finish();
        }
    }

    function finish() {
        tick.stop();
        console.log("TEST DONE " + failures);
        Qt.callLater(Qt.quit);
    }

    function startPages(expert) {
        expertPass = false;
        Config.settingsUi.skin = settingsSkins[settingsSkinIndex];
        const ids = view.allPages.map(p => p.id);
        list = ["home"].concat(ids);
        index = -1;
        phase = "pages";
        nextPage();
    }
    function nextPage() {
        index++;
        if (index >= list.length) {
            if (settingsSkinIndex + 1 < settingsSkins.length) {
                settingsSkinIndex++;
                startPages(false);
            }
            else
                startViews();
            return;
        }
        console.log("TEST-PAGE " + list[index]);
        Shell.settingsPage = list[index];
        started = Date.now();
    }
    function startViews() {
        viewCases = [];
        for (const v of ["win11", "sidebar", "controlpanel", "properties", "tiles"])
            for (const skin of settingsSkins)
                viewCases.push([v, skin]);
        viewCase = -1;
        phase = "views";
        nextViewCase();
    }
    function nextViewCase() {
        viewCase++;
        viewStep = 0;
        if (viewCase >= viewCases.length) {
            Config.settingsUi.view = "sidebar";
            Config.settingsUi.skin = "classic";
            view.setQuery("");
            if (shots)
                startSettingsShots();
            else
                startPreviews();
            return;
        }
        const [v, skin] = viewCases[viewCase];
        console.log("TEST-PAGE view:" + v + ":" + skin);
        Config.settingsUi.skin = skin;
        Config.settingsUi.view = v;
        Shell.settingsPage = "home";
        Shell.settingsSub = "";
        started = Date.now();
    }
    // one step of a view case; true when it is done (passed or reported)
    function viewTick() {
        const [v, skin] = viewCases[viewCase];
        const name = "view:" + v + ":" + skin;
        const d = view.diagnostics();
        const ms = Date.now() - started;
        const ready = d.viewStatus === Loader.Ready && d.view === v && (d.atHome || d.status === Loader.Ready);
        const waiting = ms < 6000;
        const next = () => {
            viewStep++;
            started = Date.now();
        };
        if (viewStep === 0) {
            // the home: the folder / the tiles show their own, the others a page
            if (!ready && waiting)
                return;
            report(name + ":home", ready && d.atHome === (v === "controlpanel" || v === "tiles"), "status " + d.viewStatus + "/" + d.status + ", at home " + d.atHome);
            Shell.settingsPage = "sound";
            next();
        } else if (viewStep === 1) {
            if ((!ready || d.page !== "sound") && waiting)
                return;
            const locs = view.sectionLocs.map(l => l.page + (l.sub ? "›" + l.sub : ""));
            report(name + ":page", ready && d.page === "sound" && (v !== "properties" || locs.length >= 2), locs.join(", "));
            const pl = Plugins.settingsPages[0];
            viewNote = pl ? pl.id : "";
            Shell.settingsPage = pl ? "plugin:" + pl.id : "lyrics";
            next();
        } else if (viewStep === 2) {
            if ((!ready || (viewNote && d.plugin !== viewNote)) && waiting)
                return;
            report(name + ":plugin", ready && (!viewNote || d.plugin === viewNote), viewNote ? "plugin " + d.plugin : "no plugin pages");
            view.setQuery("обои");
            next();
        } else if (viewStep === 3) {
            if (view.results.length === 0 && waiting)
                return;
            const r = view.results[0];
            report(name + ":search", !!r && !!view.viewItem && !!view.viewItem.resultsSlot, view.results.length + " results");
            viewNote = r ? r.page : "";
            view.openResult(r);
            next();
        } else if (viewStep === 4) {
            if ((!ready || d.page !== viewNote) && waiting)
                return;
            report(name + ":open-result", ready && d.page === viewNote && d.query === "", "page " + d.page);
            // the keyboard: from the home (or the account) the view's own keys move on
            Shell.settingsPage = "home";
            next();
        } else if (viewStep === 5) {
            if (!ready && waiting)
                return;
            const before = Shell.settingsPage + "|" + Shell.settingsSub;
            let ok;
            if (v === "controlpanel" || v === "tiles") {
                ok = view.navKeyForTest(Qt.Key_Down) && view.navKeyForTest(Qt.Key_Right) && view.navKeyForTest(Qt.Key_Return);
                ok = ok && !view.atHome;
            } else if (v === "win11") {
                // ↓↓ categories, → a category's first page, Enter the next page, ← back up to the
                // category, ↑, End the last category, Home the first (your account, at the top)
                const at = s => s.pages.length > 1 ? "cat:" + s.id : s.pages[0];
                const last = view.navSections[view.navSections.length - 1];
                const steps = [[Qt.Key_Down, "cat:system"], [Qt.Key_Down, "cat:devices"], [Qt.Key_Right, "bluetooth"], [Qt.Key_Return, "mouse"], [Qt.Key_Left, "cat:devices"], [Qt.Key_Up, "cat:system"], [Qt.Key_End, at(last)], [Qt.Key_Home, at(view.navSections[0])]];
                const went = [];
                ok = true;
                for (const [key, want] of steps) {
                    view.navKeyForTest(key);
                    went.push(Shell.settingsPage);
                    ok = ok && Shell.settingsPage === want;
                }
                report(name + ":keys", ok, before + " → " + went.join(" → "));
                Shell.settingsOpen = true;
                Shell.openSettings("lyrics");
                next();
                return;
            } else {
                ok = view.navKeyForTest(Qt.Key_Down);
                ok = ok && Shell.settingsPage + "|" + Shell.settingsSub !== before;
            }
            report(name + ":keys", ok, before + " → " + Shell.settingsPage + "|" + Shell.settingsSub);
            // `angelos settings lyrics`
            Shell.settingsOpen = true;
            Shell.openSettings("lyrics");
            next();
        } else if (viewStep === 6) {
            if ((!ready || d.page !== "lyrics") && waiting)
                return;
            report(name + ":settings-cli", ready && d.page === "lyrics", "page " + d.page);
            if (v === "win11") {
                // Mod+S (`angelos settings appearance`, an old id): opens its page, closes it again
                Shell.toggleSettings("appearance");
                const opened = Shell.settingsOpen && Shell.settingsPage === "theme";
                Shell.toggleSettings("appearance");
                const closed = !Shell.settingsOpen;
                Shell.settingsOpen = true;
                report(name + ":mod-s", opened && closed, "open " + opened + ", closed " + closed);
            }
            nextViewCase();
        }
    }
    function startSettingsShots() {
        settingsShotFlavor = Config.appearance.flavor;
        settingsShotMode = Config.appearance.mode;
        list = [];
        for (const skin of settingsSkins)
            for (const page of ["home", "appearance", "updates"])
                list.push([skin, page]);
        list.push(["windose", "home", "chosen"]);
        list.push(["stream", "home", "narrow"]);
        list.push([settingsSkins[0], "stars"]);
        index = -1;
        phase = "settings-shots";
        nextSettingsShot();
    }
    function nextSettingsShot() {
        index++;
        settingsShotPending = false;
        if (index >= list.length) {
            win.implicitWidth = 1100;
            win.implicitHeight = 780;
            win.width = 1100;
            win.height = 780;
            Config.appearance.flavor = settingsShotFlavor;
            Config.appearance.mode = settingsShotMode;
            Config.settingsUi.skin = "windose";
            settingsShotPending = true;
            appWindow.visible = true;
            appWindow.grabToImage(r => {
                r.saveToFile(shots + "/windose-app-window.png");
                appWindow.visible = false;
                startPreviews();
            });
            return;
        }
        const [skin, page, size] = list[index];
        Config.settingsUi.skinChosen = size === "chosen";
        win.implicitWidth = size === "narrow" ? 720 : 1100;
        win.implicitHeight = size === "narrow" ? 480 : 780;
        win.width = size === "narrow" ? 720 : 1100;
        win.height = size === "narrow" ? 480 : 780;
        Config.settingsUi.skin = skin;
        Config.appearance.flavor = page === "appearance" ? "nord" : page === "updates" ? "gruvbox" : "overdose";
        Config.appearance.mode = page === "appearance" ? "light" : "dark";
        Shell.settingsPage = page;
        started = Date.now();
    }
    function startPreviews() {
        const names = preview.sceneNames;
        list = [];
        for (const s of names)
            for (const v of [""].concat(variants[s] || []))
                list.push([s, v]);
        index = -1;
        phase = "previews";
        preview.visible = true;
        nextPreview();
    }
    function nextPreview() {
        index++;
        if (index >= list.length) {
            preview.visible = false;
            phase = "search";
            started = Date.now();
            return;
        }
        console.log("TEST-PAGE preview:" + list[index][0]);
        preview.scene = list[index][0];
        preview.variant = list[index][1];
        preview.frame = 0;
        started = Date.now();
    }

    function step() {
        if (phase === "wait") {
            if (Config.ready && view.allPages.length > 0) {
                report("settings-default-classic", Config.settingsUi.skin === "classic" && view.skin === "classic",
                       "saved default " + Config.settingsUi.skin + ", view " + view.skin);
                // a settings.json with no settingsUi.view: the Windows 11 look, the default since 2026-10-04
                report("settings-default-win11", Config.settingsUi.view === "win11" && view.viewId === "win11",
                       "saved " + Config.settingsUi.view + ", shown " + view.viewId);
                Config.settingsUi.skin = "windose";
                report("windose-app-windows", appWindow.skin === "windose" && appWindow.windose && appWindow.settingsSkin === "windose" && appAction.settingsSkin === "windose",
                       "unconfigured app skin " + appWindow.skin);
                Config.settingsUi.skin = "classic";
                report("classic-app-windows", appWindow.skin === "" && !appWindow.windose && appWindow.settingsSkin === "classic" && appAction.settingsSkin === "classic",
                       "unconfigured app skin " + appWindow.skin);
                const oldFlavor = Config.appearance.flavor;
                Config.appearance.flavor = "gruvbox";
                const windoseA = String(Theme.windoseRose);
                const streamA = String(Theme.streamBg);
                Config.appearance.flavor = "nord";
                const windoseB = String(Theme.windoseRose);
                const streamB = String(Theme.streamBg);
                Config.appearance.flavor = oldFlavor;
                report("settings-palette", windoseA !== windoseB && streamA !== streamB,
                       "Windose " + windoseA + " → " + windoseB + ", Stream " + streamA + " → " + streamB);
                startPages(false);
            }
            return;
        }
        if (phase === "pages") {
            const d = view.diagnostics();
            const ms = Date.now() - started;
            if (d.status === Loader.Loading && ms < 8000)
                return;
            const name = "page:" + settingsSkins[settingsSkinIndex] + ":" + list[index];
            report(name, d.status === Loader.Ready && view.frame.skin === settingsSkins[settingsSkinIndex] && d.settingsSkin === settingsSkins[settingsSkinIndex],
                   d.status === Loader.Ready ? ms + " ms, page skin " + d.settingsSkin : "status " + d.status + " " + d.source);
            if (list[index] === "home" || list[index] === "appearance")
                report("sidebar:" + settingsSkins[settingsSkinIndex] + ":" + list[index], d.sidebarVisible === true);
            nextPage();
            return;
        }
        if (phase === "views") {
            viewTick();
            return;
        }
        if (phase === "settings-shots") {
            if (settingsShotPending)
                return;
            const d = view.diagnostics();
            // an old page id ("appearance") opens its page of the tree ("theme")
            if (d.status !== Loader.Ready || d.page !== SettingsTree.resolve(list[index][1]).page || Date.now() - started < 120)
                return;
            const [skin, page, size] = list[index];
            const file = shots + "/settings-" + skin + "-" + page + (size ? "-" + size : "") + ".png";
            settingsShotPending = true;
            view.grabToImage(r => {
                r.saveToFile(file);
                nextSettingsShot();
            });
            return;
        }
        if (phase === "previews") {
            const [scene, variant] = list[index];
            if (preview.stageStatus === Loader.Loading && Date.now() - started < 4000)
                return;
            if (preview.stageStatus !== Loader.Ready) {
                report("preview:" + scene + (variant ? "/" + variant : ""), false, "status " + preview.stageStatus);
                nextPreview();
                return;
            }
            // play the scene through, a few frames per tick
            if (preview.frame < preview.frames) {
                preview.frame = Math.min(preview.frames, preview.frame + 4);
                return;
            }
            report("preview:" + scene + (variant ? "/" + variant : ""), true, "");
            nextPreview();
            return;
        }
        if (phase === "search") {
            if (!SettingsSearch.loaded) {
                SettingsSearch.load();
                if (Date.now() - started < 15000)
                    return;
            }
            let worst = 0, total = 0, empty = 0;
            for (const q of queries) {
                const t0 = Date.now();
                const r = SettingsSearch.search(q + " ", 14);   // a fresh key: no cache
                const ms = Date.now() - t0;
                worst = Math.max(worst, ms);
                total += ms;
                if (!r || r.length === 0)
                    empty++;
            }
            const avg = total / queries.length;
            report("search-speed", SettingsSearch.loaded && avg <= 15 && worst <= 60, "avg " + avg.toFixed(1) + " ms, worst " + worst + " ms");
            report("search-results", empty <= 4, empty + "/" + queries.length + " queries found nothing");
            phase = "nav";
            return;
        }
        if (phase === "nav") {
            // ◀ ▶: account → sound → its sub-page System sounds → its "Clicks" group, back
            // twice lands on sound, forward once on System sounds again. Each step waits until
            // the last one is in the history (recordLoc runs later, Qt.callLater): on a slow
            // machine the next tick came first and a page never got into it
            if (navStep > 0 && view.lastLoc !== Shell.settingsPage + "|" + Shell.settingsSub && Date.now() - started < 3000)
                return;
            started = Date.now();
            if (navStep === 0) {
                Shell.settingsPage = "account";
                navStep = 1;
                return;
            }
            const go = [["sound", ""], ["sfx", ""], ["taskbar", "Иконки"]];
            if (navStep <= go.length) {
                Shell.settingsPage = go[navStep - 1][0];
                Shell.settingsSub = go[navStep - 1][1];
                navStep++;
                return;
            }
            if (navStep === go.length + 1) {
                const it = view.diagnostics();
                const pg = view.pageItem;
                // the sub-page: in the Windows 11 look its card unfolds in place, the others stay
                // folded; in the older views its heading is the group, the other groups step aside
                const groups = pg && pg.advancedGroups ? pg.advancedGroups : [];
                const own = groups.find(c => c.title === "Иконки");
                const others = groups.filter(c => c.title !== "Иконки");
                if (view.fluent)
                    report("subpage", it.sub === "Иконки" && !!own && !own.folded && others.length > 0 && others.every(c => c.visible && c.folded), "taskbar › " + it.sub + ": unfolded " + (own ? !own.folded : "none") + ", others folded " + others.filter(c => c.folded).length + "/" + others.length);
                else
                    report("subpage", it.sub === "Иконки" && !!pg && pg.focusGroup === "Иконки" && others.length > 0 && others.every(c => !c.visible), "taskbar › " + it.sub + ", " + others.filter(c => c.visible).length + " other groups still shown");
                view.back();
                navStep++;
                return;
            }
            if (navStep === go.length + 2) {
                view.back();
                navStep++;
                return;
            }
            if (navStep === go.length + 3) {
                const afterBack = Shell.settingsPage;
                view.forward();
                navStep++;
                navNote = afterBack;
                return;
            }
            report("nav-back", navNote === "sound" && Shell.settingsPage === "sfx" && view.sectionOf("sfx") === "system", "taskbar›Иконки → ◀ ◀ " + navNote + " → ▶ " + Shell.settingsPage + " (section " + view.sectionOf(Shell.settingsPage) + ")");
            phase = "multi";
            multiStep = 0;
            started = Date.now();
            return;
        }
        if (phase === "multi") {
            // two Settings windows: each on its own page and sub-page, the pages in each find
            // their own window (Shell.settingsNavFor), moving in one leaves the other where it is
            if (multiStep === 0) {
                Shell.settingsPage = "taskbar";
                second.active = true;
                multiStep = 1;
                started = Date.now();
                return;
            }
            const v2 = second.item;
            const d2 = v2 ? v2.diagnostics() : null;
            const d1 = view.diagnostics();
            if (multiStep === 1) {
                if ((!d2 || d2.status !== Loader.Ready || d1.status !== Loader.Ready || d1.page !== "taskbar") && Date.now() - started < 6000)
                    return;
                const nav2 = v2 ? v2.settingsNav : null;
                const p2 = v2 ? v2.pageItem : null;
                report("multi-open", !!d2 && d2.page === "sound" && d1.page === "taskbar" && Shell.settingsPage === "taskbar" && !!p2 && p2.nav === nav2 && Shell.settingsNavFor(p2) === nav2 && Shell.settingsViewFor(p2) === v2 && Shell.settingsNavFor(view.pageItem) === Shell && Theme.settingsViews.includes(v2) && Theme.settingsViews.includes(view),
                       "second " + (d2 ? d2.page : "none") + ", main " + d1.page + ", page finds its window " + (!!p2 && Shell.settingsNavFor(p2) === nav2) + ", views " + Theme.settingsViews.length);
                // a sub-page in the second window, another page in the main one
                nav2.settingsPage = "taskbar";
                nav2.settingsSub = "Иконки";
                Shell.settingsPage = "sfx";
                multiStep = 2;
                started = Date.now();
                return;
            }
            if (multiStep === 2) {
                if ((d2.page !== "taskbar" || d2.status !== Loader.Ready || d1.page !== "sfx" || d1.status !== Loader.Ready || Date.now() - started < 200) && Date.now() - started < 6000)
                    return;
                const p2 = v2.pageItem;
                const p1 = view.pageItem;
                report("multi-apart", d2.sub === "Иконки" && !!p2 && p2.focusGroup === "Иконки" && d1.page === "sfx" && Shell.settingsSub === "" && !!p1 && p1.focusGroup === "" && v2.canBack && v2.backStack.every(l => l.indexOf("sfx") < 0),
                       "second " + d2.page + "›" + d2.sub + " (focus " + (p2 ? p2.focusGroup : "?") + "), main " + d1.page + "›" + Shell.settingsSub + ", second's history " + JSON.stringify(v2.backStack));
                // a link inside the second window goes on there (Shell.settingsGo), not in the main one
                Shell.settingsGo(p2, "sound");
                multiStep = 3;
                started = Date.now();
                return;
            }
            if (multiStep === 3) {
                if (d2.page !== "sound" && Date.now() - started < 3000)
                    return;
                const before = Shell.settingsMore.count;
                const made = Shell.newSettingsWindow("bar");
                const row = made ? Shell.settingsMore.get(Shell.settingsMore.count - 1) : null;
                const key = row ? row.key : -1;
                const page = row ? row.page : "";
                Shell.closeSettingsWindow(key);
                report("multi-link", d2.page === "sound" && Shell.settingsPage === "sfx" && made && page === "taskbar" && Shell.settingsMore.count === before,
                       "link in the second → " + d2.page + ", main stays " + Shell.settingsPage + "; new window at «bar» → " + page + ", closed " + (Shell.settingsMore.count === before));
                second.active = false;
                phase = "view-switch";
                switchStep = 0;
                started = Date.now();
                return;
            }
        }
        if (phase === "view-switch") {
            // Windows 11 → the sidebar → Windows 11 on one page (a hell dress moves the page into
            // its frame the same way): the folded cards come back, and a sub-page unfolds in place
            if (switchStep === 0) {
                Shell.settingsPage = "taskbar";
                Shell.settingsSub = "";
                Config.settingsUi.view = "win11";
                switchStep = 1;
                started = Date.now();
                return;
            }
            const d = view.diagnostics();
            const want = switchStep === 2 ? "sidebar" : "win11";
            if ((d.view !== want || d.status !== Loader.Ready || d.page !== "taskbar" || Date.now() - started < 300) && Date.now() - started < 6000)
                return;
            if (switchStep <= 2) {
                Config.settingsUi.view = switchStep === 1 ? "sidebar" : "win11";
                switchStep++;
                started = Date.now();
                return;
            }
            const groups = view.pageItem && view.pageItem.advancedGroups ? view.pageItem.advancedGroups : [];
            if (switchStep === 3) {
                report("view-switch", view.fluent && groups.length > 0 && groups.every(g => g.visible && g.folded), "win11 → sidebar → win11 on taskbar: " + groups.filter(g => g.visible && g.folded).length + "/" + groups.length + " folded cards shown");
                Shell.settingsSub = "Иконки";
                switchStep++;
                started = Date.now();
                return;
            }
            const own = groups.find(c => c.title === "Иконки");
            const others = groups.filter(c => c.title !== "Иконки");
            report("subpage-win11", !!own && own.visible && !own.folded && others.length > 0 && others.every(c => c.visible && c.folded), "taskbar › Иконки: unfolded " + (own ? !own.folded : "none") + ", others folded " + others.filter(c => c.visible && c.folded).length + "/" + others.length);
            Shell.settingsSub = "";
            Config.settingsUi.view = "sidebar";
            // settings undo puts a changed setting back
            const before = Config.appearance.shadows;
            phase = "undo";
            started = Date.now();
            undoSteps = Config.undoStack.length;
            Config.appearance.shadows = !before;
            undoFrom = before;
            return;
        }
        if (phase === "undo") {
            // wait for the save (debounced) that records the step
            if (Config.undoStack.length <= undoSteps && !undoDone && Date.now() - started < 3000)
                return;
            if (phase === "undo" && !undoDone) {
                undoDone = true;
                Config.undo();
                started = Date.now();
                return;
            }
            if (Config.appearance.shadows !== undoFrom && Date.now() - started < 3000)
                return;
            report("settings-undo", Config.appearance.shadows === undoFrom, "shadows back to " + Config.appearance.shadows);
            // "Reset this page" brings defaults back
            Config.appearance.px = 4;
            Config.resetKeys(["appearance.px"]);
            report("settings-reset", Config.appearance.px === Config.defaults.appearance.px, "px " + Config.appearance.px);
            console.log("TEST-PAGE sprite-rig");
            phase = "rig";
            return;
        }
        if (phase === "rig") {
            // one look a tick: another folder's rig.json is read in the background. The swap
            // flips `who` in one go: with the figures' looks apart (the helper: an ophanim
            // angel and a glitch demon) both are read up front, so the flip ("!") needs no wait;
            // every frame of every part gets shown
            const steps = [["", "", "angel"], ["", "", "demon"], ["glitch", "glitch", "angel"], ["glitch", "glitch", "demon"], ["", "", "demon"], ["ophanim", "glitch", "angel"], ["ophanim", "glitch", "demon!"], ["ophanim", "glitch", "angel!"]]
                .concat(["limbo", "lust", "gluttony", "greed", "wrath", "heresy", "violence", "fraud", "treachery"].map(s => ["ophanim", "glitch", "demon", s]))
                .concat([["ophanim", "glitch", "demon", "__missing__"], ["ophanim", "glitch", "angel!"]]);
            if (rigStep < steps.length) {
                const [av, dv, w, skin] = steps[rigStep];
                const who = w.replace("!", ""), atOnce = w.endsWith("!"), variant = who === "angel" ? av : dv;
                if (!rigAsked) {
                    rig.angelVariant = av;
                    rig.demonVariant = dv;
                    rig.who = who;
                    rig.skin = skin || "";
                    rigAsked = true;
                    started = Date.now();
                    if (!atOnce)
                        return;
                }
                if (!atOnce && rig.file.loadedPath !== rig.file.path && Date.now() - started < 2000)
                    return;
                rigAsked = false;
                rigStep++;
                const r = rig.rig;
                const name = (skin || variant ? (skin || variant) + " " : "") + who;
                const circleSkin = who === "demon" && skin && skin !== "__missing__";
                const folder = circleSkin ? "demon-" + skin : who + (variant ? "-" + variant : "");
                if (!rig.ready || rig.file.name !== folder || rig.file.loadedPath !== rig.file.path)
                    rigSeen.push(name + " FAIL: " + (rig.ready ? "still " + rig.file.loadedPath.replace(/.*sprites\//, "") : "no rig"));
                else if (rig.implicitWidth !== r.size[0] * rig.px || rig.implicitHeight !== r.size[1] * rig.px || rig.body.width !== r.body.w * rig.px)
                    rigSeen.push(name + " FAIL: " + rig.implicitWidth + "×" + rig.implicitHeight + " for " + r.size);
                else
                    rigSeen.push(name + " " + r.size[0] + "×" + r.size[1] + " " + Object.keys(r.parts).join("+"));
                // every circle's demon has both wings and the tail (and may have more: gluttony's belly)
                if (circleSkin && r && !["tail", "wing_left", "wing_right"].every(k => !!r.parts[k]))
                    rigSeen.push(name + " FAIL: missing animated wing or tail");
                for (let i = 0; i < 16; i++) {
                    rig.tick = i;
                    rig.blink = i % 3 === 0;
                    rig.talk = i % 2 === 0;
                    // Overlapping face patches must let the blink win (including circle skins).
                    if (rig.blink && rig.talk && rig.talking !== !(r && r.blinkCoversTalk))
                        rigSeen.push(name + " FAIL: blink and talk at once → talking " + rig.talking);
                }
                rig.flutter = !rig.flutter;
                return;
            }
            const seen = rigSeen;
            report("sprite-rig", seen.every(s => s.indexOf("FAIL") < 0), seen.join(", "));
            console.log("TEST-PAGE alttab");
            AltTab.items = [1, 2, 3, 4, 5].map(i => ({
                        "id": 9000 + i,
                        "app_id": ["kitty", "helium", "discord", "org.gnome.Nautilus", "unknown.app"][i - 1],
                        "title": "window " + i,
                        "workspace_id": i
                    }));
            AltTab.index = 1;
            altTabStyles = ["angelos", "ngo", "y2k", "hell"];
            altTabSeen = [];
            phase = "alttab";
            started = Date.now();
            return;
        }
        if (phase === "alttab") {
            if (!altTabStage.style) {
                altTabStage.style = altTabStyles[altTabSeen.length];
                started = Date.now();
                return;
            }
            if (altTabStage.status === Loader.Loading && Date.now() - started < 4000)
                return;
            const it = altTabStage.item;
            const ok = altTabStage.status === Loader.Ready && it && it.implicitWidth > 0 && it.implicitHeight > 0;
            // ANGELOS_TEST_SHOTS=<dir>: a picture of each style to look at
            if (ok && shots && !altTabShot) {
                altTabShot = "wait";
                it.width = it.implicitWidth;
                it.height = it.implicitHeight;
                const name = shots + "/alttab-" + altTabStage.style + ".png";
                it.grabToImage(r => {
                    r.saveToFile(name);
                    root.altTabShot = "done";
                });
                return;
            }
            if (altTabShot === "wait" && Date.now() - started < 3000)
                return;
            altTabShot = "";
            for (let i = 0; i < 6; i++)
                AltTab.index = (AltTab.index + 1) % AltTab.items.length;
            altTabSeen.push(altTabStage.style + (ok ? " " + Math.round(it.implicitWidth) + "×" + Math.round(it.implicitHeight) : " FAIL"));
            altTabStage.style = "";
            if (altTabSeen.length < altTabStyles.length)
                return;
            AltTab.items = [];
            report("alttab-styles", altTabSeen.every(x => x.indexOf("FAIL") < 0), altTabSeen.join(", "));
            // its layer-shell window cannot open here, but it must compile
            const host = Qt.createComponent(Quickshell.shellDir + "/modules/alttab/AltTabHost.qml");
            const hostErr = host.status === Component.Ready ? "" : host.errorString();
            // offscreen has no layer shell: that one error is expected, anything else is not
            report("alttab-host", !hostErr || /No PanelWindow backend/.test(hostErr) && hostErr.trim().split("\n").length === 1, hostErr ? hostErr.trim().split("\n")[0].replace(/^.*AltTabHost\.qml:/, "") : "compiles");
            console.log("TEST-PAGE bar-widgets");
            barStage.active = true;
            phase = "bar";
            started = Date.now();
            return;
        }
        if (phase === "bar") {
            if (barStage.status === Loader.Loading && Date.now() - started < 4000)
                return;
            const b = barStage.item;
            const ok = barStage.status === Loader.Ready && !!b && b.wifi.width > 0 && b.bt.width > 0 && b.wired.width > 0;
            // every tray density lays out; the sprites switch
            for (const d of ["compact", "airy", "spacious", "normal"])
                Config.bar.trayDensity = d;
            for (const sp of ["star", "cd", "heart"])
                Config.workspaces.sprite = sp;
            report("bar-widgets", ok, ok ? "wifi, bluetooth, wired, tray, workspaces" : "status " + barStage.status);
            barStage.active = false;
            console.log("TEST-PAGE toggle-wrap");
            wrapStage.active = true;
            phase = "wrap";
            return;
        }
        if (phase === "wrap") {
            // PxToggle wraps a long label inside PxGroup / SettingRow, keeps short and free ones on one line
            const w = wrapStage.item;
            const fits = (t, box) => t.mapToItem(box, t.width, 0).x <= box.width + 0.5;
            const wrapped = t => t.height > w.short.height + 1;
            const checks = [
                ["group", fits(w.direct, w.group) && wrapped(w.direct)],
                ["row", fits(w.inRow, w.row) && wrapped(w.inRow)],
                ["column", fits(w.inColumn, w.row2) && wrapped(w.inColumn)],
                ["short", w.short.width === w.short.implicitWidth && !wrapped(w.short)],
                ["free", w.free.width === w.free.implicitWidth && !wrapped(w.free)]
            ];
            const bad = checks.filter(c => !c[1]).map(c => c[0]);
            report("toggle-wrap", bad.length === 0, bad.length ? "overflow/one line: " + bad.join(", ") : "long labels wrap in " + Math.round(w.direct.width) + " px, short and free stay " + Math.round(w.short.height) + " px tall");
            wrapStage.active = false;
            console.log("TEST-PAGE start-styles");
            startStyles = ["classic", "win11", "fullscreen", "xmb", "windose", "wii", "spotlight"];
            startSeen = [];
            phase = "start";
            return;
        }
        if (phase === "start") {
            // one look per tick: load it, then search, walk, clear and close it with keys
            if (!startStage.style) {
                startStage.style = startStyles[startSeen.length];
                startTried = false;
                started = Date.now();
                return;
            }
            // a tick after the keys: callLater work (focus) is done, unload it
            if (startTried) {
                startStage.style = "";
                if (startSeen.length < startStyles.length)
                    return;
                report("start-styles", startSeen.every(x => x.indexOf("FAIL") < 0), startSeen.join(", "));
                console.log("TEST-PAGE hell-widgets");
                hellSteps = [];
                for (const k of ["Clock", "Sysmon", "Cava", "NowPlaying", "Hellwheel", "frame"])
                    for (const r of ["heaven", "hell"])
                        hellSteps.push([k, r]);
                hellSeen = [];
                phase = "heaven-menus";
                return;
            }
            const it = startStage.item;
            const ok = startStage.status === Loader.Ready && !!it && it.width > 0 && it.height > 0;
            // ANGELOS_TEST_SHOTS=<dir>: a picture of each look as it opens
            if (ok && shots && !startShot) {
                startShot = "wait";
                const name = shots + "/start-" + startStage.style + ".png";
                it.grabToImage(r => {
                    r.saveToFile(name);
                    root.startShot = "done";
                });
                return;
            }
            if (startShot === "wait" && Date.now() - started < 3000)
                return;
            startShot = "";
            startTried = true;
            let closed = 0;
            if (ok) {
                const onClose = () => closed++;
                it.closeRequested.connect(onClose);
                const press = (k, text) => {
                    const e = {
                        "key": k,
                        "text": text || "",
                        "modifiers": Qt.NoModifier,
                        "accepted": false
                    };
                    it.key(e);
                };
                if (it.reset)
                    it.reset();
                for (const k of [Qt.Key_Down, Qt.Key_Down, Qt.Key_Right, Qt.Key_Up, Qt.Key_Left, Qt.Key_PageDown, Qt.Key_PageUp])
                    press(k);
                if (it.setQuery)
                    it.setQuery("set");
                press(0, "t");
                press(Qt.Key_Down);
                press(Qt.Key_Escape);         // clears the search (or closes the classic one)
                press(Qt.Key_Escape);         // closes
                it.closeRequested.disconnect(onClose);
            }
            startSeen.push(startStage.style + (ok && closed > 0 ? " " + Math.round(it.width) + "×" + Math.round(it.height) : " FAIL" + (ok ? " (Esc did not close)" : "")));
            return;
        }
        if (phase === "heaven-menus") {
            // heaven's own right-click menus (DeskMenu.heavenly: wings, harp): each builds round
            // a pointer; with 16 entries and names, at every menu size, on 1920×1080 at scale 1,
            // 1.25, 1.5 and 2 and on the portrait 1080×1920 at 1 and 2, opened in the middle
            // and pushed into a corner, every icon and name stays on the screen and off the
            // others'; the ink of icons and names reads on what it stands on (4.5:1) in every
            // heaven palette, light and dark
            const heavenBad = [];
            const heavenT0 = Date.now();
            const cap = id => id.charAt(0).toUpperCase() + id.slice(1);
            const sixteen = DeskMenu.catalog.filter(id => id !== "sep").slice(0, 16);
            const fake = (cx, cy, k) => ({
                    "k": k,
                    "slots": sixteen,
                    "labels": true,
                    "cx": cx,
                    "cy": cy,
                    "reveal": 1,
                    "current": -1,
                    "fly": "",
                    "flyIndex": -1,
                    "subCurrent": -1,
                    "flyItems": [],
                    "hoveredEntry": null,
                    "clamp": (v, lo, hi) => Math.max(lo, Math.min(hi, v)),
                    "hoverEntry": i => {},
                    "activate": i => {},
                    "activateSub": j => {},
                    "walk": e => false,
                    "close": () => {}
                });
            // what an entry takes on screen: itself (an icon's plate, a string) and its name
            const rectsOf = look => {
                const out = [];
                for (const c of look.children) {
                    if (typeof c.hot !== "boolean" || c.label === undefined)
                        continue;
                    const p = c.mapToItem(look, 0, 0);
                    out.push([c.index, p.x, p.y, c.width, c.height]);
                    for (const t of c.children) {
                        if (t.text === c.label && c.label !== "") {
                            const q = t.mapToItem(look, 0, 0);
                            out.push([c.index, q.x, q.y, t.width, t.height]);
                        }
                    }
                }
                return out;
            };
            const stage = Qt.createQmlObject("import QtQuick; Item {}", win.contentItem);
            const screens = [[1920, 1080], [1536, 864], [1280, 720], [960, 540], [1080, 1920], [540, 960]];
            const built = {};
            for (const id of DeskMenu.heavenly) {
                const c = Qt.createComponent(Quickshell.shellDir + "/modules/background/" + cap(id) + "Look.qml");
                if (c.status !== Component.Ready) {
                    heavenBad.push(id + ": " + c.errorString().trim().split("\n")[0]);
                    continue;
                }
                built[id] = c;
                let worst = "";
                for (const [w, h] of screens) {
                    stage.width = w;
                    stage.height = h;
                    for (const k of [0.85, 1, 1.25]) {
                        for (const corner of [false, true]) {
                            let o = c.createObject(stage, {
                                "menu": fake(w / 2, h / 2, k)
                            });
                            if (corner) {
                                // where RadialMenu.openAt puts a right click into the corner
                                const mx = o.reachX, my = o.reachY;
                                o.destroy();
                                o = c.createObject(stage, {
                                    "menu": fake(Math.max(Math.min(mx, w / 2), Math.min(Math.max(w - mx, w / 2), w - 1)), Math.max(Math.min(my, h / 2), Math.min(Math.max(h - my, h / 2), h - 1)), k)
                                });
                            }
                            const where = w + "×" + h + " k" + k + (corner ? " corner" : "");
                            const rs = rectsOf(o);
                            if (!(o.reach > 0) || rs.length < sixteen.length)
                                worst = worst || where + ": lays out " + rs.length + " pieces";
                            for (const r of rs) {
                                if (r[1] < -1 || r[2] < -1 || r[1] + r[3] > w + 1 || r[2] + r[4] > h + 1)
                                    worst = worst || where + ": entry " + (r[0] + 1) + " off the screen at " + Math.round(r[1]) + "," + Math.round(r[2]);
                            }
                            for (let i = 0; i < rs.length && !worst; i++) {
                                for (let j = i + 1; j < rs.length; j++) {
                                    const a = rs[i], b = rs[j];
                                    if (a[0] === b[0])
                                        continue;
                                    const ox = Math.min(a[1] + a[3], b[1] + b[3]) - Math.max(a[1], b[1]), oy = Math.min(a[2] + a[4], b[2] + b[4]) - Math.max(a[2], b[2]);
                                    if (ox > 1 && oy > 1) {
                                        worst = where + ": entries " + (a[0] + 1) + " and " + (b[0] + 1) + " overlap";
                                        break;
                                    }
                                }
                            }
                            o.destroy();
                        }
                    }
                }
                if (worst)
                    heavenBad.push(id + " " + worst);
            }
            const layoutMs = Date.now() - heavenT0;
            // every palette, light and dark, read through the looks' own colours (coloursFor:
            // switching the shell's palette 24 times re-inks everything loaded and takes ~40 s);
            // the palette as Theme builds it — the one on screen must come out the same
            const keepMode = Config.appearance.mode;
            const looks = Object.keys(built).map(id => [id, built[id].createObject(stage, {
                        "menu": fake(960, 540, 1)
                    })]);
            const paletteOf = (f, m) => {
                const fl = Theme.flavors[f][m];
                const b = fl.desk ? Object.assign({}, Theme.legacyBase, fl) : Theme.legacyBase;
                return {
                    "dark": m === "dark",
                    "face": b.face,
                    "text": b.text,
                    "accent": fl.accent,
                    "surface": Theme.mix(b.face, fl.accent, m === "dark" ? 0.08 : 0.04)
                };
            };
            let palettes = 0;
            for (const m of ["light", "dark"]) {
                Config.appearance.mode = m;
                const here = paletteOf(Config.appearance.flavor in Theme.flavors ? Config.appearance.flavor : "overdose", m);
                const hexes = pairs => pairs.map(p => p.map(c => Theme.hex(Qt.color(c))).join("/")).join(" ");
                if (Theme.hex(Qt.color(here.surface)) !== Theme.hex(Theme.menuSurface) || Theme.hex(Qt.color(here.text)) !== Theme.hex(Theme.text))
                    heavenBad.push("palette read apart from Theme (" + m + "): " + here.surface + " vs " + Theme.menuSurface);
                for (const [id, o] of looks)
                    if (hexes(o.coloursFor(here).pairs) !== hexes(o.pairs))
                        heavenBad.push(id + " (" + m + "): its colours on screen are not coloursFor's");
                for (const f of Object.keys(Theme.flavors)) {
                    palettes++;
                    for (const [id, o] of looks) {
                        for (const [fg, bg] of o.coloursFor(paletteOf(f, m)).pairs) {
                            const c = HellLook.contrast(fg, bg);
                            if (c < 4.5)
                                heavenBad.push(id + " " + f + "/" + m + ": " + fg + " on " + bg + " " + c.toFixed(2));
                        }
                    }
                }
            }
            Config.appearance.mode = keepMode;
            for (const [id, o] of looks)
                o.destroy();
            stage.destroy();
            report("heaven-menus", heavenBad.length === 0 && Object.keys(built).length === DeskMenu.heavenly.length, heavenBad.slice(0, 6).join("; ") || DeskMenu.heavenly.join(", ") + ": 16 entries fit and stay apart on " + screens.length + " screens × 3 sizes × middle/corner; ink ≥ 4.5:1 in " + palettes + " palettes (" + layoutMs + " + " + (Date.now() - heavenT0 - layoutMs) + " ms)");
            phase = "hell";
            return;
        }
        if (phase === "hell") {
            // one widget and realm per tick: load it, next tick measure it
            const st = hellSteps[hellSeen.length];
            if (!hellLoaded) {
                Theme.realm = st[1];
                hellStage.kind = st[0];
                hellLoaded = true;
                return;
            }
            const stage = st[0] === "frame" ? frameStage : hellStage;
            const it = stage.item;
            hellSeen.push(st[0] + "/" + st[1] + (stage.status === Loader.Ready && it && (it.implicitWidth > 0 || it.width > 0) ? "" : " FAIL"));
            hellStage.kind = "";
            hellLoaded = false;
            if (hellSeen.length < hellSteps.length)
                return;
            Theme.realm = "heaven";
            report("hell-widgets", hellSeen.every(x => x.indexOf("FAIL") < 0), hellSeen.filter(x => x.indexOf("FAIL") >= 0).join(", ") || hellSeen.length + " loads");
            // every look of hell (story/circles.json): what the hell bar draws, on what it draws it
            // (HellLook.barRoles) — text, dim text, the icons and the accent on the plate and on the
            // hover plate, the accent (an open or switched-on widget) and the text on the active
            // plate: WCAG 4.5:1; a sprite's body and its lighter parts (the Cerberus, app icons'
            // darks through HellBarTint) on the plate: 3:1, so nothing sinks into it
            const lookIds = HellLook.ids.length ? HellLook.ids : ["base"];
            const weak = [];
            for (const id of lookIds) {
                const pal = HellLook.merged(HellLook.fallback, HellLook.looks.base, id !== "base" ? HellLook.looks[id] : null).palette;
                const r = HellLook.barRoles(pal);
                const pairs = [["text", pal.text, "plate", pal.plate, 4.5], ["textDim", pal.textDim, "plate", pal.plate, 4.5], ["accent", pal.accent, "plate", pal.plate, 4.5], ["barIcon", r.barIcon, "plate", pal.plate, 4.5], ["text", pal.text, "barHover", r.barHover, 4.5], ["textDim", pal.textDim, "barHover", r.barHover, 4.5], ["barIcon", r.barIcon, "barHover", r.barHover, 4.5], ["accent", pal.accent, "barActive", r.barActive, 4.5], ["text", pal.text, "barActive", r.barActive, 4.5], ["sprite", r.sprite, "plate", pal.plate, 3], ["spriteHi", r.spriteHi, "plate", pal.plate, 3]];
                for (const [what, c1, gname, ground, need] of pairs) {
                    const c = HellLook.contrast(c1, ground);
                    if (c < need)
                        weak.push(id + ": " + what + " on " + gname + " " + c.toFixed(2));
                }
            }
            report("hell-contrast", HellLook.ids.length > 0 && weak.length === 0, weak.join(", ") || lookIds.length + " looks: text, dim, icons and the accent on the plates ≥ 4.5:1, sprites ≥ 3:1");
            // each circle's dress (item 13, story/circles.json → dress): its own Settings and
            // right-click menu, all nine different; every menu look lays out round a pointer,
            // every dress builds and its page reads (ink ≥ 7:1, red ink ≥ 4.5:1 on its paper);
            // "circle" follows the circle, a pick of one look stays
            const dressBad = [];
            const circleIds = HellLook.ids.filter(c => c !== "base");
            const dressOf = c => HellLook.looks[c].dress || {};
            const settingsSet = circleIds.map(c => dressOf(c).settings), menuSet = circleIds.map(c => dressOf(c).menu);
            if (new Set(settingsSet).size !== circleIds.length || settingsSet.some(d => !HellLook.dressSettingsIds.includes(d)))
                dressBad.push("settings " + settingsSet.join(" "));
            if (new Set(menuSet).size !== circleIds.length || menuSet.some(d => !HellLook.dressMenuIds.includes(d)))
                dressBad.push("menus " + menuSet.join(" "));
            const cap = id => id.charAt(0).toUpperCase() + id.slice(1);
            const fakeMenu = {
                "k": 1,
                "slots": ["terminal", "files", "monitor", "wallpaperPick", "settings", "view", "new", "open", "wallpaper", "more", "lock"],
                "labels": true,
                "cx": 400,
                "cy": 300,
                "reveal": 1,
                "current": 2,
                "fly": "",
                "flyIndex": -1,
                "subCurrent": -1,
                "flyItems": [],
                "hoveredEntry": null,
                "clamp": (v, lo, hi) => Math.max(lo, Math.min(hi, v)),
                "hoverEntry": i => {},
                "activate": i => {},
                "activateSub": j => {},
                "walk": e => false,
                "close": () => {}
            };
            for (const id of HellLook.dressMenuIds) {
                const c = Qt.createComponent(Quickshell.shellDir + "/modules/background/circles/" + cap(id) + "Look.qml");
                const o = c.status === Component.Ready ? c.createObject(win.contentItem, {
                    "menu": fakeMenu
                }) : null;
                if (!o || !(o.reach > 0))
                    dressBad.push(id + (c.status !== Component.Ready ? ": " + c.errorString().trim().split("\n")[0] : " lays out nothing"));
                if (o)
                    o.destroy();
            }
            for (const id of HellLook.dressSettingsIds) {
                const c = Qt.createComponent(Quickshell.shellDir + "/modules/settings/dresses/" + cap(id) + "Dress.qml");
                const o = c.status === Component.Ready ? c.createObject(win.contentItem, {
                    "view": {
                        "hostWindow": null
                    },
                    "width": 900,
                    "height": 640
                }) : null;
                if (!o || !o.viewSlot || o.viewSlot.width <= 0)
                    dressBad.push(id + (c.status !== Component.Ready ? ": " + c.errorString().trim().split("\n")[0] : " has no page"));
                else if (HellLook.contrast(o.ink, o.paper) < 7 || HellLook.contrast(o.redInk, o.paper) < 4.5)
                    dressBad.push(id + " ink " + HellLook.contrast(o.ink, o.paper).toFixed(2) + " red " + HellLook.contrast(o.redInk, o.paper).toFixed(2));
                if (o)
                    o.destroy();
            }
            const keepCircle = HellLook.circle, keepMenu = Config.y2k.hellMenu, keepSettings = Config.y2k.hellSettings;
            HellLook.circle = "greed";
            Config.y2k.hellMenu = "circle";
            Config.y2k.hellSettings = "circle";
            const follows = HellLook.dressMenu === "roulette" && HellLook.settingsPick === "ledger";
            Config.y2k.hellSettings = "ice";
            const picked = HellLook.settingsPick === "ice";
            Config.y2k.hellSettings = "";
            const usual = HellLook.settingsPick === "";
            HellLook.circle = "base";
            Config.y2k.hellSettings = "circle";
            const before = HellLook.settingsPick === "grimoire" && HellLook.dressMenu === "pentagram";
            HellLook.circle = keepCircle;
            Config.y2k.hellMenu = keepMenu;
            Config.y2k.hellSettings = keepSettings;
            if (!follows || !picked || !usual || !before)
                dressBad.push("pick: circle " + follows + ", one look " + picked + ", usual " + usual + ", before a circle " + before);
            report("circle-dress", dressBad.length === 0, dressBad.join("; ") || circleIds.length + " circles: " + HellLook.dressSettingsIds.length + " Settings dresses, " + HellLook.dressMenuIds.length + " menus, distinct, built, readable");
            // a burn there and back (DesktopWidgets.burnPreview) must land in heaven again
            DesktopWidgets.burnPreview("hell");
            started = Date.now();
            phase = "hell-burn";
            return;
        }
        if (phase === "hell-burn") {
            if ((DesktopWidgets.burning || Theme.realm !== "heaven") && Date.now() - started < DesktopWidgets.burnMs * 2 + 2500)
                return;
            // six hell cursors and one for each circle (story/circles.json → cursor), their mood
            // variations hidden from the lists
            const hellCursors = Cursors.hellish.length;
            const circleCursors = Cursors.catalog.filter(c => !!c.circle && !c.hidden).length;
            const moods = Cursors.catalog.filter(c => !!c.circle && c.hidden).length;
            report("hell-burn", !DesktopWidgets.burning && Theme.realm === "heaven" && hellCursors === 6 + circleCursors && circleCursors === 9 && moods === 18, "burnt over and back in " + (Date.now() - started) + " ms, " + hellCursors + " hell cursors (" + circleCursors + " circles', " + moods + " mood variations)");
            phase = "game";
            started = Date.now();
            return;
        }
        if (phase === "game") {
            if (!Novel.loaded && Date.now() - started < 8000)
                return;
            report("game-save", Story.ready && Story.player.character === "angel" && Story.enabled, "save " + Story.file + (Story.ready ? "" : " not loaded"));
            const missing = Story.order.filter(id => !HellLook.looks[id] || HellLook.looks[id].n !== Story.order.indexOf(id) + 1);
            report("game-circles", Story.order.length === 9 && missing.length === 0, missing.length ? "missing or misnumbered: " + missing.join(", ") : "9 circles in order");
            const bad = [];
            for (const id of Object.keys(Novel.scenes))
                for (const v of Core.validate(Novel.scenes[id]))
                    if (v.level === "error")
                        bad.push(id + "/" + v.node + ": " + v.text);
            report("game-scenes", Object.keys(Novel.scenes).length > 0 && bad.length === 0, bad.join("; ") || Object.keys(Novel.scenes).length + " scenes valid");
            const noTrial = Story.order.filter(id => !Object.keys(Novel.scenes).some(sid => {
                    const ev = Novel.eventOf(Novel.scenes[sid]);
                    return ev && ev.trigger === "trial" && Core.evalCond(ev.cond, Object.assign(Story.ctxVars(), {
                        "circle": id
                    }), []);
                }));
            report("game-trials", noTrial.length === 0, noTrial.length ? "no trial in " + noTrial.join(", ") : "every circle has its trial");
            // a fall lands on the heaviest sin among the circles no fall began in
            Story.applySet({
                "greed": "+2",
                "wrath": "+1"
            });
            const first = Story.circleForFall();
            Story.hell.fallCircles = ["greed"];
            const second = Story.circleForFall();
            Story.hell.fallCircles = [];
            report("game-fall", first === "greed" && second === "wrath", "greed 2, wrath 1 → " + first + ", then " + second);
            // into hell without the show: greed, then a circle deeper, then the pact
            Story.player.character = "demon";
            Story.fell("greed");
            const inGreed = Story.circle === "greed" && HellLook.circle === "greed" && Theme.hellAccent.toString() === Qt.color(HellLook.looks.greed.palette.accent).toString();
            Story.deeper();
            report("game-deeper", inGreed && Story.circle === "wrath" && Story.depth === 2, "greed (" + inGreed + ") → " + Story.circle + ", path " + JSON.stringify(Story.hell.path));
            Story.outcome("pact");
            started = Date.now();
            phase = "game-out";
            return;
        }
        if (phase === "game-out") {
            if ((Story.inHell || Angel.transition) && Date.now() - started < 12000)
                return;
            report("game-pact", !Story.inHell && Story.marked && Story.circle === "" && HellLook.circle === "base" && Story.hell.outcomes.length === 1, "out by " + (Story.hell.outcomes[0] || {}).kind + " in " + (Date.now() - started) + " ms, marked " + Story.marked);
            Story.setEnabled(false);
            const off = !Story.enabled && !Angel.demon && !Angel.shown && !Novel.enabled;
            Story.setEnabled(true);
            report("game-off", off && Story.enabled, "off: no angel, demon or novel; on again");
            Story.reset();
            report("game-reset", Object.keys(Story.vars).length === 0 && !Story.hell.pact && (Story.hell.outcomes || []).length === 0 && Story.chill === 0 && !Story.player.coldRoute, "the save starts over");
            // the angel's warmth (item 11): a throw cools her a step, a day without one warms
            // her back a step, the cold route stays; her step's words replace the warm ones
            const steps = [Story.angelStep];
            Story.act("throw.fling");
            steps.push(Story.angelStep);
            const reservedLine = Story.angelLine("back");
            Story.player.lastThrow = Story.now() - 25 * 3600000;
            Story.player.thawAt = 0;
            Story.thaw();
            steps.push(Story.angelStep);
            Story.act("throw.fling");
            Story.act("throw.push");
            Story.act("throw.fling");
            steps.push(Story.angelStep);
            Story.player.lastThrow = Story.now() - 72 * 3600000;
            Story.thaw();
            steps.push(Story.angelStep);
            const coldLine = Story.angelLine("love");
            const heartless = (() => {
                Angel.say("тест ♡");
                const t = Angel.text;
                Angel.hush();
                return t.indexOf("♡") < 0;
            })();
            report("angel-chill", JSON.stringify(steps) === "[0,1,0,3,3]" && !!reservedLine && !!coldLine && Story.player.coldRoute && heartless, "steps " + JSON.stringify(steps) + " (warm → a throw → a day → three more → three days), lines " + !!reservedLine + "/" + !!coldLine + ", no hearts when cold " + heartless);
            // past cold (story/game.json → angel.fallen): the fall the cold route's own throw
            // starts doesn't change her; the next trip down does, by the return — a return that
            // counts (the game switched off is none); more than five betrayals, then a trip
            // down, too. She then shows as the story's look whatever is picked (the pick kept),
            // her lines never twice running; a reset undoes it all
            const ride = () => {
                Story.player.character = "demon";
                Story.fell("limbo");
                const due = !!Story.player.fallenDue;
                Story.player.character = "angel";
                Story.rose();
                return due;
            };
            Story.reset();
            const picked = Config.y2k.angelLook;
            Story.act("throw.fling");
            Story.act("throw.fling");
            Story.act("throw.fling");
            const coldTrip = ride();
            const coldStill = Story.angelStep === 3 && !Story.angelFallen && Angel.angelLook !== Story.fallenLook;
            Story.player.character = "demon";
            Story.fell("lust");
            const offTrip = !!Story.player.fallenDue;
            Story.player.character = "angel";
            Story.rose(false);
            const waits = !Story.angelFallen && Story.player.fallenDue;
            Story.rose();
            const changed = Story.angelFallen && Story.angelStep === 4 && Story.angelStepName === "fallen" && Angel.angelLook === Story.fallenLook && Config.y2k.angelLook === picked;
            const said = [];
            for (let i = 0; i < 12; i++)
                said.push(Story.angelLine("chatter"));
            const repeats = said.some((l, i) => i > 0 && l === said[i - 1]);
            const first = Story.angelLine("first");
            Story.reset();
            const undone = !Story.angelFallen && !Story.player.fallenDue && (Story.player.betrayals || 0) === 0;
            for (let i = 0; i < 6; i++) {
                Story.player.chill = 0;
                Story.act(i % 2 ? "throw.push" : "throw.fling");
            }
            const sixthTrip = ride();
            Story.player.chill = 0;
            const seventhTrip = ride();
            const betrayed = Story.angelFallen && !Story.player.coldRoute && Story.player.betrayals === 6;
            report("angel-fallen", !coldTrip && coldStill && offTrip && waits && changed && !repeats && !!first && !!said[0] && undone && !sixthTrip && seventhTrip && betrayed, "the cold route's own trip " + coldTrip + ", cold " + coldStill + "; next trip marked " + offTrip + ", waits for a counted return " + waits + ", changed " + changed + " (look " + Angel.angelLook + ", pick kept), chatter twice running " + repeats + "; reset " + undone + "; 6th betrayal's trip " + sixthTrip + ", the next " + seventhTrip + " → changed " + betrayed);
            Story.reset();
            phase = "game-exit";
            return;
        }
        if (phase === "game-exit") {
            // in hell without the show; the clock is moved, never waited for
            Story.player.character = "demon";
            Story.fell("limbo");
            // the circle's demon and the player (item 12): a word, then too soon; a gift
            // (+2 and her sin) makes them acquainted and has its scene; staying puts the next
            // try off; your own, she has her words and the cursor its animation
            const sinBefore = Story.vars.limbo || 0;
            const talk = Story.demonAct("talk");
            const again = Story.demonAct("talk");
            const gift = Story.demonAct("gift");
            const stepScene = Novel.sceneFor("close");
            Story.player.lastPlea = 0;
            const stay = Story.demonAct("stay");
            const putOff = Story.nextTry > Story.now();
            Story.hell.close = {
                "limbo": {
                    "points": 15
                }
            };
            const own = Story.demonStep === 3 && Cursors.mood === "alive";
            const ownLine = Story.demonLine("talk", 3);
            Story.hell.close = ({});
            report("demon-close", talk.ok && talk.step === 0 && !again.ok && again.wait === 30 && gift.stepUp && gift.step === 1 && stepScene === "close-limbo-1" && stay.ok && putOff && own && !!ownLine && (Story.vars.limbo || 0) === sinBefore + 1, "talk " + JSON.stringify(talk) + ", again " + JSON.stringify(again) + ", gift " + JSON.stringify(gift) + " → " + stepScene + ", stay puts the try off " + putOff + ", your own " + own + " (mood " + Cursors.mood + ")");
            Story.player.lastPlea = Story.now();
            const early = Story.attempt(false);
            Story.clockShift += 11 * 60000;
            const later = Story.attempt(false);
            const asked = Novel.sceneBusy;
            const twice = Story.attempt(false);
            Novel.stopScene();
            report("exit-wait", early === "wait" && later === "trial" && asked && twice === "busy", "too early → " + early + ", 11 min later → " + later + ", again while it waits → " + twice);
            // the clock went back: the last try is "in the future"
            Story.player.lastPlea = Story.now() + 3 * 3600000;
            const future = Story.attempt(false);
            Novel.stopScene();
            report("exit-future", future === "trial" && Story.player.lastPlea <= Story.now(), "a try saved 3 h ahead → " + future);
            // the save points at a scene an update renamed
            Story.clockShift += 11 * 60000;
            Novel.state = Object.assign({}, Novel.state, {
                "game": {
                    "scene": "trial-renamed",
                    "node": "ask",
                    "wait": "show"
                }
            });
            const stale = Story.attempt(false);
            Novel.stopScene();
            report("exit-stale", stale === "trial", "a scene that is gone → " + stale);
            // any wording of "let me out", typos and the wrong keyboard layout too
            const pleas = ["верни ангела", "как вернуться", "хочу в рай", "отпусти меня", "умоляю", "привет, верни ангела", "как отсюда выбраться", "вирни ангила", "dthyb fyutkf", "хочу домой", "let me out", "bring the angel back", "I want to go back to heaven", "please"];
            const notPleas = ["расскажи шутку", "как сделать крупнее", "это верно", "поменяй обои"];
            const missed = pleas.filter(s => !Intents.weak(s, "plea")).concat(notPleas.filter(s => Intents.weak(s, "plea")).map(s => "not: " + s));
            Story.clockShift += 11 * 60000;
            Angel.answer("привет, верни ангела");
            const typed = Novel.sceneBusy;
            Novel.stopScene();
            report("exit-words", missed.length === 0 && typed, missed.length ? "misread: " + missed.join("; ") : pleas.length + " pleas and " + notPleas.length + " other questions read right; typed → the trial " + typed);
            // D2: "What did I sign?" in any wording; the paper with the way out in numbers; a
            // signed pact on it; a plea that mentions signing stays a plea
            const asks = ["что я подписал", "Что я подписала?", "покажи договор", "какие условия выхода", "на что я согласился", "what did I sign", "show me the contract", "what are the terms", "покожи договр", "xnj z gjlgbcfk", "покажи договор с ангелом"];
            const notAsks = ["расскажи шутку", "сделай громче", "как сделать обои", "sing me a song", "подписка на youtube", "верни ангела, я ничего не подписывал", "отпусти, я не подписывал"];
            const misreadSign = asks.filter(s => !Intents.stronger(s, "signed", "plea")).concat(notAsks.filter(s => Intents.stronger(s, "signed", "plea")).map(s => "not: " + s));
            Novel.stopScene();
            Angel.answer("Что я подписал?");
            const p0 = Novel.paper;
            const terms = !!p0 && Novel.noteOpen && p0.text.indexOf(I18n.t("Условия выхода", "The way out")) >= 0 && p0.text.indexOf(Story.circleName(Story.circle)) >= 0 && Story.pactState() === "none";
            Novel.noteRead();
            Story.hell.outcomes = (Story.hell.outcomes || []).concat([{
                        "kind": "pact",
                        "circle": "greed",
                        "at": Story.now()
                    }]);
            Story.hell.pact = true;
            Angel.answer("what did i sign");
            const p1 = Novel.paper;
            const signedPaper = !!p1 && p1.text.indexOf(Story.circleName("greed")) >= 0 && p1.text.indexOf(Story.dateText(Story.now())) >= 0;
            Novel.noteRead();
            Story.hell.pact = false;
            Story.hell.outcomes = Story.hell.outcomes.filter(o => o.kind !== "pact");
            Story.clockShift += 11 * 60000;
            Angel.answer("отпусти, я не подписывал");
            const stillPlea = Novel.sceneBusy && !Novel.paper;
            Novel.stopScene();
            report("contract", misreadSign.length === 0 && terms && signedPaper && stillPlea, misreadSign.length ? "misread: " + misreadSign.join("; ") : asks.length + " questions and " + notAsks.length + " others read right; the paper with the way out " + terms + ", a signed pact with its circle and date " + signedPaper + ", a plea about signing stays a plea " + stillPlea);
            // limbo across a restart: the angel finds the player once enough time has passed
            Story.outcome("limbo");
            Story.hell.limboSince = Story.now() - 11 * 60000;
            Story.freeIfDue(true);
            started = Date.now();
            phase = "exit-limbo";
            return;
        }
        if (phase === "exit-limbo") {
            if ((Story.inHell || Angel.transition) && Date.now() - started < 12000)
                return;
            report("exit-limbo", !Story.inHell && !Story.hell.limbo, "limbo of 11 min at a start → " + (Story.inHell ? "still in hell" : "out") + " in " + (Date.now() - started) + " ms");
            // a player stuck under the old rules: settings.json's y2k with a broken counter
            Story.reset();
            Story.migrateFrom({
                "character": "demon",
                "pleas": "garbage",
                "lastPlea": 99999999999999,
                "returns": "x"
            }, null);
            Story.repairClock();
            const stuck = Story.inHell && Story.hell.amnesty && Story.player.lastPlea === 0;
            Story.freeIfDue(true);
            started = Date.now();
            phase = "exit-amnesty";
            report("exit-migrate", stuck, "old save in hell: amnesty " + Story.hell.amnesty + ", last try " + Story.player.lastPlea);
            return;
        }
        if (phase === "exit-amnesty") {
            if ((Story.inHell || Angel.transition) && Date.now() - started < 14000)
                return;
            report("exit-amnesty", !Story.inHell && !Story.hell.amnesty && Story.player.returns === 1 && (Story.hell.outcomes || []).some(o => o.kind === "amnesty"), "let out in " + (Date.now() - started) + " ms, returns " + Story.player.returns);
            Story.clockShift = 0;
            Story.reset();
            phase = "debug";
            return;
        }
        if (phase === "debug") {
            // the game's debug panel (GameDebug): each tab builds from the data, its writes
            // land in the save, its overrides (a circle's look, a kind of breakage) take
            const bad = [];
            for (const t of ["DebugStateTab", "DebugAngelTab", "DebugDemonsTab", "DebugScenesTab", "DebugFxTab", "DebugLooksTab", "DebugSoundsTab", "DebugSystemTab"]) {
                const c = Qt.createComponent(Qt.resolvedUrl("../../modules/debug/" + t + ".qml"));
                const o = c.status === Component.Ready ? c.createObject(win.contentItem, {
                    "width": 800
                }) : null;
                if (!o || !o.children.length)
                    bad.push(t + (c.status === Component.Error ? ": " + c.errorString() : ""));
                if (o)
                    o.destroy();
            }
            GameDebug.setSin("wrath", 7);
            GameDebug.setClose("lust", 9);
            const wrote = Story.vars.wrath === 7 && Story.closePoints("lust") === 9 && Story.closeStepOf(Story.closePoints("lust")) === 2;
            GameDebug.lookCircle("treachery");
            const looked = HellLook.circle === "treachery" && GameDebug.lookOverridden;
            GameDebug.lookAsStory();
            GameDebug.punch("frost");
            const punched = Cracks.on && Cracks.kind === "frost" && Cracks.forceKind === "";
            Cracks.on = false;
            report("debug-panel", GameDebug.allowed && bad.length === 0 && wrote && looked && HellLook.circle === "base" && punched, (bad.length ? "tabs failed: " + bad.join("; ") : "8 tabs build") + ", writes " + wrote + ", a circle's look " + looked + ", frost on demand " + punched);
            Story.reset();
            // C1: into hell through the portal, with the show and the circle's splash
            paceRuns = CircleFx.runs;
            Angel.lastSwitchAt = 0;
            Angel._portal = true;
            Angel.startSwap("toHell");
            started = Date.now();
            phase = "pace";
            return;
        }
        if (phase === "pace") {
            // the shows take longer on a slow machine (GitHub's): wait for them, not a clock
            if (Angel.transition && Date.now() - started < 25000)
                return;
            const shown = Angel.demon && CircleFx.runs === paceRuns + 1;
            // back and forth right after: at once, no splash, no burn
            Angel.startSwap("ascend");
            const out = !Angel.demon && !Angel.transition;
            Angel.startSwap("toHell");
            const back = Angel.demon && !Angel.transition && CircleFx.runs === paceRuns + 1;
            report("pace-quick", shown && out && back, "portal → the circle's splash " + shown + "; out and in again within " + Story.quickSwitchMs / 1000 + " s: at once " + (out && back) + ", splashes " + (CircleFx.runs - paceRuns));
            // later than the threshold: the whole show again
            Angel.lastSwitchAt = Date.now() - Story.quickSwitchMs - 1000;
            Angel.startSwap("ascend");
            paceSlow = Angel.transition === "ascend";
            started = Date.now();
            phase = "pace-slow";
            return;
        }
        if (phase === "pace-slow") {
            if ((Angel.transition || DesktopWidgets.burning) && Date.now() - started < 25000)
                return;
            report("pace-slow", paceSlow && !Angel.demon && Theme.realm === "heaven", "a switch " + (Story.quickSwitchMs / 1000 + 1) + " s after the last: the full show " + paceSlow + ", heaven again " + (Theme.realm === "heaven"));
            // D2 in heaven: the angel shows the paper, no way out to list
            Angel.answer("покажи договор");
            const hp = Novel.paper;
            report("contract-heaven", !!hp && Novel.noteOpen && hp.text.indexOf(I18n.t("Условия выхода", "The way out")) < 0 && Story.exitTerms().length === 0, "the angel's paper: " + (hp ? hp.title : "none"));
            Novel.noteRead();
            // D3: the other icon styles — only names of ours, whole families, theirs in the
            // box of ours (a third larger at most), ours when the box is too small for them
            const own = Icons.names();
            const strays = [], broken = [];
            for (const st of ["pixelarticons", "hackernoon"]) {
                for (const n of Object.keys(IconSets.sets[st]))
                    if (own.indexOf(n) < 0)
                        strays.push(st + ":" + n);
                for (const fam of [["wifi", "wifiOff", "wifi1", "wifi2"], ["play", "pause", "next", "prev"], ["mic", "micMute"], ["speaker", "speakerMute"], ["bell", "bellOff"]]) {
                    const have = fam.filter(n => !!IconSets.get(st, n)).length;
                    if (have !== 0 && have !== fam.length)
                        broken.push(st + ":" + fam.join("/"));
                }
            }
            const probe = Qt.createQmlObject("import QtQuick; import qs.widgets; PxIcon { name: \"gear\"; iconStyle: \"hackernoon\" }", root);
            const big = !!probe._alt && probe.width > 0 && probe.width <= 9 * Theme.u * 1.35 + 1;
            probe.pixel = 1;
            const small = !probe._alt;
            probe.iconStyle = "pixelarticons";
            probe.pixel = Theme.u;
            const pa = !!probe._alt;
            probe.name = "heartHorns";
            const kept = !probe._alt;
            probe.destroy();
            report("icon-styles", !strays.length && !broken.length && big && small && pa && kept, (strays.length ? "not ours: " + strays.join(", ") + "; " : "") + (broken.length ? "half a family: " + broken.join(", ") + "; " : "") + "hackernoon gear in the box " + big + ", too small → ours " + small + ", pixelarticons " + pa + ", the horns stay ours " + kept);
            Story.reset();
            phase = "walls";
            return;
        }
        // C2: heaven's wallpaper is never touched in hell; a pick in hell lasts for its circle
        if (phase === "walls") {
            const heaven = "/tmp/selftest-heaven.png", hellPic = "/tmp/selftest-hell.png", pickPic = "/tmp/selftest-pick.png";
            const keep = [Config.wallpaper.fallback, Config.wallpaper.outputs, Config.wallpaper.workspaces, Config.y2k.hellPicture, Config.appearance.customAccent];
            Wallpapers.setEverywhere(heaven);
            Config.y2k.hellPicture = hellPic;
            Story.player.character = "demon";
            Story.fell("greed");
            Angel.hellLook(true);
            const inHell = Wallpapers.resolve("S", 1) === hellPic && Config.wallpaper.fallback === heaven;
            Wallpapers.setForOutput("S", pickPic);
            const picked = Wallpapers.resolve("S", 1) === pickPic && Config.wallpaper.fallback === heaven && !(Config.wallpaper.outputs || {}).S;
            Story.setCircle("wrath");
            const nextCircle = Wallpapers.resolve("S", 1) === hellPic;
            const accent0 = Config.appearance.customAccent;
            PaletteGenerator.apply("#123456", false);
            const accents = Config.appearance.customAccent === accent0 && Config.appearance.customAccentHell === "#123456";
            Angel.hellLook(false);
            Story.player.character = "angel";
            const back = Wallpapers.resolve("S", 1) === heaven && !Story.player.hellWall;
            report("walls-apart", inHell && picked && nextCircle && back, "in hell " + inHell + ", a pick changes hell only " + picked + ", the next circle puts its own " + nextCircle + ", heaven's back " + back);
            report("walls-accent", accents, "hell's accent from its picture kept apart from heaven's " + accents);
            // an older save: hell sat in Config.wallpaper, heaven's in angelSaved
            Story.player.character = "demon";
            Story.player.angelSaved = {
                "fallback": heaven,
                "outputs": {},
                "workspaces": {},
                "mode": "light"
            };
            Config.wallpaper.fallback = "/tmp/selftest-old-hell.png";
            Angel.untangleWall();
            const untangled = Config.wallpaper.fallback === heaven && !!Story.player.hellWall && Story.player.hellWall.fallback === "/tmp/selftest-old-hell.png" && Story.player.angelSaved.mode === "light" && Story.player.angelSaved.fallback === undefined;
            report("walls-old-save", untangled, "heaven's wallpaper given back " + (Config.wallpaper.fallback === heaven) + ", the old hell kept as hell's " + !!Story.player.hellWall);
            Story.player.character = "angel";
            Story.player.hellWall = null;
            Story.player.angelSaved = null;
            Config.wallpaper.fallback = keep[0];
            Config.wallpaper.outputs = keep[1];
            Config.wallpaper.workspaces = keep[2];
            Config.y2k.hellPicture = keep[3];
            Config.appearance.customAccent = keep[4];
            Config.appearance.customAccentHell = "";
            Story.reset();
            phase = "motion";
            return;
        }
        // C4: one motion setting; off = no animations (heaven ⇄ hell at once, no splash, no burn)
        if (phase === "motion") {
            Motion.set("off");
            const zero = Motion.still && Motion.calm && Motion.ms(300) === 0;
            // D4: previews hold one still frame — the result — while nothing may move
            preview.scene = "CircleFx";
            preview.variant = "full";
            preview.frame = 3;
            const stillPreview = preview.still && preview.t === 1;
            const runs = CircleFx.runs;
            Angel.lastSwitchAt = 0;
            Angel.startSwap("toHell");
            const atOnce = Angel.demon && !Angel.transition && !CircleFx.active && !DesktopWidgets.burning;
            // heaven's own menus (wings, harp) never come down: chosen as the usual menu, or even
            // written in as hell's by hand, hell puts its own look in their place
            const keepStyle = Config.desktop.menuStyle, keepHellMenu = Config.y2k.hellMenu;
            // heaven's own are earned (services/Heaven): earned here, so heaven has them to give back
            Achievements.grant("love", true);
            Achievements.grant("faithful", true);
            const apart = [];
            for (const h of DeskMenu.heavenly) {
                Config.desktop.menuStyle = h;
                Config.y2k.hellMenu = "";
                const usual = DeskMenu.style;
                Config.y2k.hellMenu = h;
                const forced = DeskMenu.style;
                if (!DeskMenu.hellish || DeskMenu.heavenly.includes(usual) || DeskMenu.heavenly.includes(forced))
                    apart.push(h + " → " + usual + " / " + forced);
            }
            Angel.startSwap("ascend");
            const back = !Angel.demon && !Angel.transition;
            Config.y2k.hellMenu = keepHellMenu;
            for (const h of DeskMenu.heavenly) {
                Config.desktop.menuStyle = h;
                if (DeskMenu.style !== h || DeskMenu.overlayLook !== h || !DeskMenu.overlay)
                    apart.push("heaven lost " + h + " (" + DeskMenu.style + ")");
            }
            Config.desktop.menuStyle = keepStyle;
            report("heaven-apart", apart.length === 0, apart.join("; ") || "in hell " + DeskMenu.heavenly.join(" and ") + " give way to hell's own (as the usual menu or set as hell's), in heaven they are back");
            Motion.set("calm");
            const calm = Story.calm && !Motion.still && Motion.ms(300) === 300;
            Motion.set("full");
            // the game's old calm toggle becomes the calm level, once
            Config.game.calm = true;
            Motion.migrate();
            const migrated = Motion.level === "calm" && !Config.game.calm;
            Motion.set("full");
            const movingAgain = !preview.still && preview.t < 1;
            preview.scene = "";
            report("motion-off", zero && atOnce && back && stillPreview && movingAgain, "off: durations 0 " + zero + ", into hell and out at once " + (atOnce && back) + " (splashes asked " + (CircleFx.runs - runs) + ", none shown), a preview is one still frame " + stillPreview + " and moves again after " + movingAgain);
            report("motion-calm", calm && migrated, "calm: the game's calm " + calm + "; the old game.calm became motion calm " + migrated);
            Story.reset();
            phase = "achievements";
            return;
        }
        // the achievements and heaven's things (services/Achievements, services/Heaven): the list
        // is valid, every thing has its achievement; the game off opens all of heaven and counts
        // nothing; on again, all that isn't earned is locked again (a locked pick is kept, the
        // usual shows); an earned one opens its thing, taken back it locks; the demon's pranks
        // count for nothing
        if (phase === "achievements") {
            const bad = Achievements.problems(Achievements.doc);
            report("ach-data", Achievements.loaded && !Achievements.loadError && Achievements.own.length >= 20 && bad.length === 0, Achievements.loadError || bad.join("; ") || Achievements.own.length + " achievements in " + Achievements.tiers.length + " tiers, valid");
            const noGiver = Heaven.ids.filter(i => !Achievements.giverOf(i));
            report("ach-heaven", noGiver.length === 0 && Heaven.ids.includes("menu.harp"), noGiver.length ? "nothing gives " + noGiver.join(", ") : Heaven.ids.length + " heaven things, each with its achievement");
            const keepStyle = Config.desktop.menuStyle, keepLook = Config.y2k.angelLook, keepGame = Config.game.enabled;
            Story.setEnabled(true);
            Story.reset();
            Config.desktop.menuStyle = "harp";
            Config.y2k.angelLook = "adult";
            const locked = !Heaven.has("menu.harp") && !Heaven.has("look.adult") && DeskMenu.chosen === "list" && Angel.angelLook === "glitch" && Config.desktop.menuStyle === "harp";
            // the game off: all of heaven, nothing counted
            Story.setEnabled(false);
            const before = Achievements.count("settings.open");
            Achievements.note("settings.open");
            Achievements.check();
            const allOpen = Heaven.ids.every(i => Heaven.has(i)) && DeskMenu.chosen === "harp" && Angel.angelLook === "adult" && Achievements.count("settings.open") === before && Achievements.earned === 0 && !Achievements.current;
            // on again: locked again
            Story.setEnabled(true);
            const relocked = !Heaven.has("menu.harp") && DeskMenu.chosen === "list" && Angel.angelLook === "glitch";
            report("ach-no-game", locked && allOpen && relocked, "game on, fresh save: harp and adult locked, the usual shows " + locked + "; game off: all open, nothing counted " + allOpen + "; on again: locked again " + relocked);
            // earning: Settings opened → its achievement and the mini look
            Achievements.note("settings.open");
            Achievements.check();
            const earned = Achievements.has("settings") && Heaven.has("look.mini") && !!Achievements.current;
            Achievements.queue = [];
            Achievements.current = null;
            Achievements.grant("faithful", true);
            const harp = Heaven.has("menu.harp") && DeskMenu.chosen === "harp";
            Achievements.revoke("faithful");
            const harpGone = !Heaven.has("menu.harp") && DeskMenu.chosen === "list";
            // counted: ten jokes make "More! More!", the progress shows
            for (let i = 0; i < 9; i++)
                Achievements.note("act:joke.more");
            const nine = Achievements.progress(Achievements.find("jokes"));
            Achievements.note("act:joke.more");
            Achievements.check();
            const jokes = !!nine && nine.n === 9 && nine.of === 10 && Achievements.has("jokes") && Heaven.has("look.chibi");
            // kinds: seven different Start looks
            for (const st of ["classic", "win11", "fullscreen", "xmb", "windose", "wii"])
                Achievements.note("start.open", st);
            Achievements.check();
            const six = !Achievements.has("all-starts");
            Achievements.note("start.open", "spotlight");
            Achievements.check();
            const seven = six && Achievements.has("all-starts");
            // the demon's pranks: muted
            const w = Achievements.count("widget.add");
            Achievements.mute++;
            Achievements.note("widget.add", "clock");
            Achievements.mute--;
            const muted = Achievements.count("widget.add") === w;
            // every condition reads
            const condBad = Achievements.own.filter(a => a.cond && Achievements.condError(a.cond)).map(a => a.id + ": " + Achievements.condError(a.cond));
            Achievements.queue = [];
            Achievements.current = null;
            // in a row: six windows ≤ 10 s apart leave the diary key in the card; a pause breaks the run
            Achievements._times = ({});
            for (let i = 0; i < 5; i++)
                Achievements.note("window.open");
            Achievements.check();
            const fiveNot = !Achievements.has("six-windows") && Achievements.streak("window.open", 10) === 5;
            const t0 = Date.now();
            Achievements._times["window.open"] = [t0 - 60000, t0 - 45000, t0 - 30000, t0 - 15000, t0 - 100];
            const broken = Achievements.streak("window.open", 10) === 1;
            Achievements._times = ({});
            for (let i = 0; i < 6; i++)
                Achievements.note("window.open");
            Achievements.check();
            const card = Achievements.current && Achievements.current.id === "six-windows" ? Achievements.current : Achievements.queue.find(c => c.id === "six-windows");
            const key = Achievements.has("six-windows") && Heaven.has("item.diary-key") && Diary.owned && !!card && card.thing === "item.diary-key" && !!card.texture && card.texture.rows.length > 4;
            report("ach-streak", fiveNot && broken && key, "five in a row: not yet " + fiveNot + "; a 15 s pause breaks the run " + broken + "; six: the key lies in the card, the diary is had " + key);
            // the diary: valid, its first page written, a secret one hidden, read marks kept, it opens
            const dBad = Diary.problems(Diary.doc);
            Diary.tick++;
            const first = Diary.isOpen("found") && Diary.isOpen("hood");
            const secretHidden = !Diary.isOpen("fall") && !Diary.shown.some(x => x.id === "fall");
            Diary.markRead("found");
            const read = !!Diary.readMarks["found"] && Achievements.kinds("diary.page") === 1;
            // her diary: read while she is away
            Diary.leave(1);
            const awayNow = Angel.away && !Diary.watching;
            const opened = Diary.open("found") && Shell.diaryOpen && Diary.startAt === "found" && Achievements.count("diary.open") === 1 && Achievements.count("diary.sneak") === 1;
            Diary.close();
            Angel.awayUntil = 0;
            const backFine = !Angel.away && Diary.watching && Diary.caughtTimes === 0;
            const sideOk = Diary.side === "right";
            Config.game.diarySide = "left";
            const sideLeft = Diary.side === "left";
            Config.game.diarySide = "";
            report("diary", Diary.loaded && dBad.length === 0 && Diary.pages.length >= 10 && first && secretHidden && read && awayNow && opened && backFine && sideOk && sideLeft && !Shell.diaryOpen, (dBad.join("; ") || Diary.pages.length + " pages, valid") + "; written from the start " + first + ", a secret page hidden " + secretHidden + ", read marks " + read + ", she walks off " + awayNow + ", opens at a page while she's away " + opened + ", back to a shut book: nothing " + backFine + ", side right → left " + (sideOk && sideLeft));
            // caught: in front of her the first time she takes it and hides it (trust −1); then it
            // opens but costs −2; open when she comes back: shut, −3, the mark 6 crossed chills her
            const chill0 = Story.chill;
            const firstTry = !Diary.open() && !Shell.diaryOpen && Diary.hidden && Diary.trust === 9 && Diary.caughtTimes === 1;
            const againTry = Diary.open() && Shell.diaryOpen && Diary.trust === 7 && Diary.caughtTimes === 2;
            Diary.close();
            Diary.leave(1);
            Diary.open();
            const sneaking = Shell.diaryOpen && Diary.trust === 7;
            Angel.awayUntil = 0;
            const backCaught = !Shell.diaryOpen && Diary.trust === 4 && Diary.caughtTimes === 3 && Story.chill === chill0 + 1 && Diary.isOpen("caught") === true;
            const backWhy = "away " + Angel.away + " watching " + Diary.watching + " open " + Shell.diaryOpen + " trust " + Diary.trust + " caught " + Diary.caughtTimes + " chill " + chill0 + "→" + Story.chill + " page " + Diary.isOpen("caught");
            Diary.resetTrust();
            Story.player.chill = chill0;
            const reset = Diary.trust === Diary.trustStart && !Diary.hidden;
            report("diary-caught", firstTry && againTry && sneaking && backCaught && reset, "in front of her: taken and hidden, trust 9 " + firstTry + "; again: opens, trust 7 " + againTry + "; while she's away: free " + sneaking + "; open when she's back: shut, trust 4, chilled, her page about it " + backCaught + (backCaught ? "" : " (" + backWhy + ")") + "; reset " + reset);
            // hell's card: an achievement marked hell, or any card asked so
            Achievements.queue = [];
            Achievements.current = null;
            Achievements.announce(Achievements.find("fall"), null);
            const hellCard = !!Achievements.current && Achievements.current.hell === true;
            Achievements.queue = [];
            Achievements.current = null;
            Achievements.announce(Achievements.find("start"), true);
            const askedHell = !!Achievements.current && Achievements.current.hell === true;
            Achievements.queue = [];
            Achievements.current = null;
            Achievements.announceDiary([Diary.page("found")], null);
            const diaryCard = !!Achievements.current && Achievements.current.kind === "diary" && Achievements.current.page === "found";
            Achievements.queue = [];
            Achievements.current = null;
            // the owner's tests: an event as if seen, reset
            Achievements.mute++;
            const sim = Achievements.simulate("lock") && Achievements.count("lock") === 1;
            Achievements.mute--;
            Achievements.check();
            const lockGot = Achievements.has("lock");
            Achievements.resetCounts();
            const countsGone = Achievements.count("lock") === 0 && Achievements.has("lock");
            Achievements.resetAll();
            const allGone = Achievements.earned === 0 && !Heaven.has("item.diary-key") && Object.keys(Diary.readMarks).length === 0;
            report("ach-hell-test", hellCard && askedHell && diaryCard && sim && lockGot && countsGone && allGone, "hell's card for «fall» " + hellCard + ", asked " + askedHell + "; a diary card " + diaryCard + "; simulate past the mute " + sim + " → «lock» " + lockGot + "; reset counts " + countsGone + ", reset all " + allGone);
            report("ach-earn", earned && harp && harpGone && jokes && seven && muted && condBad.length === 0, "Settings → «settings» + mini " + earned + "; harp granted " + harp + ", taken back " + harpGone + "; 9/10 jokes then «jokes» + chibi " + jokes + "; seven Start looks " + seven + "; pranks muted " + muted + (condBad.length ? "; bad conditions: " + condBad.join(", ") : ""));
            Story.reset();
            Config.desktop.menuStyle = keepStyle;
            Config.y2k.angelLook = keepLook;
            Config.game.enabled = keepGame;
            cavaStage.active = true;
            started = Date.now();
            phase = "cava";
            return;
        }
        // B4: cava started, hidden (the lock, sleep, a fullscreen game), shown again with the
        // same config — it must start again and print frames
        if (phase === "cava") {
            const w = cavaStage.item;
            if ((!w || w.starts < 1 || Date.now() - w.lastFrame > 500) && Date.now() - started < 8000)
                return;
            if (!w) {
                report("cava-back", false, "the cava widget did not load");
                phase = "rmb";
                return;
            }
            cavaFirst = w.starts;
            w.visible = false;
            started = Date.now();
            phase = "cava-hidden";
            return;
        }
        if (phase === "cava-hidden") {
            if (Date.now() - started < 600)
                return;
            cavaStage.item.visible = true;
            started = Date.now();
            phase = "cava-back";
            return;
        }
        if (phase === "cava-back") {
            const w = cavaStage.item;
            const back = w.starts > cavaFirst && Date.now() - w.lastFrame < 500;
            if (!back && Date.now() - started < 6000)
                return;
            report("cava-back", back && !w.missing, "started " + cavaFirst + "×, hidden and shown → " + w.starts + "×, frames " + (back ? "again" : "stopped") + " after " + (Date.now() - started) + " ms" + (w.missing ? " (cava missing)" : ""));
            cavaStage.active = false;
            phase = "rmb";
            return;
        }
        if (phase === "rmb") {
            // B2: with a menu open, Qt on Wayland reports the release relative to that
            // popup — the menu must open where the button went down
            ctxClick.got = null;
            ctxClick.visible = true;
            sim.mousePress(ctxClick, 50, 60, Qt.RightButton, Qt.NoModifier, -1);
            sim.mouseRelease(ctxClick, 300, 200, Qt.RightButton, Qt.NoModifier, -1);
            ctxClick.visible = false;
            const at = ctxClick.got;
            report("menu-at-press", !!at && at.x === 50 && at.y === 60, "down at 50,60, up at 300,200 → menu at " + (at ? at.x + "," + at.y : "none"));
            bare.visible = true;
            phase = "rmb-focus";
            return;
        }
        if (phase === "rmb-focus") {
            focusThief.visible = true;
            focusThief.requestActivate();
            phase = "rmb-click";
            started = Date.now();
            return;
        }
        if (phase === "rmb-click") {
            if (bare.activeFocusItem !== null && Date.now() - started < 1500)
                return;
            // Qt 6.11 dies on a right click into pixel (0,0) nobody accepts while
            // the window has no focus item (tests/qt/tst_rightclick_origin.qml);
            // widgets/RightClickGuard takes it
            sim.mouseClick(bare.contentItem, 0, 0, Qt.RightButton, Qt.NoModifier, -1);
            sim.mouseClick(win.contentItem, 0, 0, Qt.RightButton, Qt.NoModifier, -1);
            phase = "rmb-alive";
            return;
        }
        if (phase === "rmb-alive") {
            report("rmb-corner", true, "still alive (focus item: " + bare.activeFocusItem + ")");
            phase = "setup";
            return;
        }
        // the first run holds the desktop until the wizard is done or skipped
        if (phase === "setup") {
            Config.setup.complete = false;
            Shell.setupFirstRun = true;
            Shell.setupOpen = true;
            const held = Shell.setupLocked && !Shell.settingsOpen;
            Shell.launcherOpen = true;
            Shell.clipboardOpen = true;
            Shell.sessionOpen = true;
            Shell.openStart("test");
            Shell.openSettings("theme");
            AltTab.step(1);
            const quiet = !Shell.launcherOpen && !Shell.clipboardOpen && !Shell.sessionOpen && Shell.startScreen === "" && !Shell.settingsOpen && !AltTab.active;
            report("setup-lock", held && quiet && Shell.hiddenScreen("test"), "held " + held + "; launcher, clipboard, session, Start, Settings, Alt+Tab stay shut " + quiet + "; screens unseen " + Shell.hiddenScreen("test"));
            // `angelos setup skip` (the IPC half; tests/setup covers the marker)
            Shell.setupSkipRequested();
            const out = !Shell.setupOpen && !Shell.setupLocked && Config.setup.complete;
            Shell.launcherOpen = true;
            const free = Shell.launcherOpen;
            Shell.launcherOpen = false;
            Shell.settingsOpen = true;
            report("setup-skip", out && free && Shell.settingsOpen, "out " + out + ", the launcher opens again " + free);
            // again from Settings: a window, nothing held
            wizard.go(0);
            Shell.setupOpen = true;
            setupSeen = [];
            setupBack = -1;
            started = Date.now();
            phase = "setup-walk";
            return;
        }
        if (phase === "setup-walk") {
            const a = wizard.assistant;
            const cur = wizard.cur;
            const ready = !!a && !!a.shown && a.shown.id === cur.id && !!a.answer && !!a.answer.item;
            if (!ready && Date.now() - started < 4000)
                return;
            let ok = ready && !Shell.setupLocked;
            if (ready && cur.blocks)
                for (const b of cur.blocks) {
                    const g = named(a.answer.item, b.split("/")[1]);
                    ok = ok && !!g && g.visible && SettingsTree.blockPart(b).page !== "";
                }
            setupSeen.push(cur.id + (ok ? "" : "✕"));
            // Back once, from the second question
            if (ok && wizard.step === 1 && setupBack < 0) {
                setupBack = 1;
                wizard.back();
                started = Date.now();
                return;
            }
            if (setupBack === 1 && wizard.step === 0)
                setupBack = 2;
            if (!ok || wizard.step >= wizard.last) {
                wizard.tipsAfter = false;
                wizard.next();
                const done = !Shell.setupOpen && Config.setup.complete;
                report("setup-again", ok && done && setupBack === 2 && setupSeen.every(s => !s.endsWith("✕")), setupSeen.join(" → ") + "; back works " + (setupBack === 2) + "; finished " + done);
                finish();
                return;
            }
            wizard.next();
            started = Date.now();
        }
    }
}
