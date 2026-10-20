pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// UI state shared by modules + small helpers.
Singleton {
    id: root

    property var settingsView: null
    property var barViews: ({})
    property bool setupOpen: false
    property int setupCovers: 0              // the wizard's screen covers still there (modules/settings/SetupWizard)
    signal setupStepRequested(int step)
    signal setupSkipRequested()       // `angelos setup skip`: out of the wizard at once
    // The setup wizard (modules/settings/SetupWizard) covers every screen and the desktop
    // waits — Start, the launcher, Settings, the menus, the shell's hotkeys and niri's do
    // nothing. The first run lets go only when it is done (or `angelos setup skip`); opened
    // again from Settings (or `angelos setup`) it has "Close", and Settings come back after.
    property bool setupFirstRun: false
    // the next opening plays the first run's intro too (Settings → Account, in debug mode)
    property bool setupIntroOnce: false
    // the first run's intro alone, over the desktop: once for everyone after an update brings a
    // new one (SetupIntro.version), or `angelos intro`; holds the desktop like the wizard
    property bool introOpen: false
    signal introRequested()
    readonly property bool setupLocked: setupOpen || introOpen
    property bool settingsAfterSetup: false
    onSetupLockedChanged: if (setupLocked) {
        settingsAfterSetup = settingsOpen && !setupFirstRun;
        closeTransient("");
        settingsOpen = false;
        settingsMore.clear();
    } else if (settingsAfterSetup) {
        settingsAfterSetup = false;
        settingsOpen = true;
    }
    onSettingsOpenChanged: if (settingsOpen && setupLocked)
        settingsOpen = false
    signal resumed()                  // the machine woke from sleep (Lock: logind PrepareForSleep false)
    property bool settingsOpen: false
    property string settingsPage: "appearance"
    // a sub-page of it: one of its "advanced" groups opened on its own (Settings: "Title ›")
    property string settingsSub: ""
    onSettingsPageChanged: settingsSub = ""
    property bool launcherOpen: false
    property string launcherPrefill: ""
    property bool sessionOpen: false
    property bool projectOpen: false         // the screens menu, Mod+P / the display key (modules/laptop/ProjectMenu)
    signal projectNext()                      // …the key again while it is open: the next choice
    property bool bootOpen: false            // Y2K loading screen (modules/y2k/BootScreen)
    property bool settingsWarm: false        // the main Settings window is built ahead, hidden, while it is likely to be opened (modules/LazyWindows)
    property bool bootCover: false           // …the black second before it, at login
    property bool bootCoverShown: false      // …its first frame is out
    // the wallpaper, bar and Dock wait for the cover's first frame, so they are never seen before it
    readonly property bool desktopHeld: bootCover && !bootCoverShown
    // where it shows: the screens picked (all when none), streamed ones skipped while stream mode is on
    readonly property var bootScreens: screens.filter(s => (!(Config.y2k.bootScreens || []).length || Config.y2k.bootScreens.includes(s.name)) && StreamMode.effectsOn(s.name))
    // the shell's own pid: its windows (settings, osu!mini…) share it, so
    // "End task" on them would kill angelOS itself
    property int pid: 0
    property Process pidProbe: Process {
        running: true
        command: ["sh", "-c", "echo $PPID"]
        stdout: StdioCollector {
            onStreamFinished: root.pid = parseInt(text) || 0
        }
    }
    property bool clipboardOpen: false
    property bool diaryOpen: false          // the Angel's diary (services/Diary, modules/diary/DiaryBook)
    property bool gameOpen: false            // osu!mini window (plugin osu-mini)
    property string gameAsk: ""              // "rhythm": the window opens on a round under the playing track
    property bool locked: false
    property bool lockPreview: false         // the lock screen in a normal overlay, nothing is checked
    property var lockPreviewTry: null        // (text) → plays the preview's reaction; never touches PAM
    property string lockPreviewDemo: ""      // the preview types this in by itself a moment after it opens
    property var polkitReregister: null
    property bool polkitRegistered: false
    // the shell's password dialog is up (modules/polkit/PolkitDialog): a full-screen layer that
    // holds the keyboard (the setup wizard) lets go while it asks — niri gives exclusive focus to
    // the oldest such layer, so the dialog on top would show but never get the keys (#62)
    property bool polkitAsking: false
    property var setupHost: null              // the screen the setup wizard asks on (SetupWizard)
    readonly property bool dev: Quickshell.env("ANGELOS_DEV") === "1"
    // niri sends "angelOS [dev]" windows to the non-stream monitor (cfg/rules.kdl)
    readonly property string appTitle: dev ? "angelOS [dev]" : "angelOS"
    // demo/recording mode: popups open from IPC without an input grab
    readonly property bool demo: Quickshell.env("ANGELOS_DEMO") === "1"
    property var desktopMenus: ({})   // screen name -> DesktopMenu
    property string launcherText: ""
    // plays the workspace heart animation on the bars without switching (settings preview, `angelos heartDemo`)
    signal heartDemo(int from, int to)

    function lock() {
        closeStart();
        locked = true;
    }

    // A window you type into (the launcher, clipboard history, the session menu)
    // first closes every menu and panel: a popup's input grab or another
    // exclusive overlay (Start) would otherwise keep the keyboard (issue #22).
    signal dismissMenus
    function closeTransient(keep) {
        dismissMenus();
        if (PopupManager.active)
            PopupManager.close(PopupManager.active);    // tray menus are not registered
        for (const p of PopupManager.registered)
            PopupManager.close(p);
        for (const k in desktopMenus)
            if (desktopMenus[k] && desktopMenus[k].close)
                desktopMenus[k].close();
        if (keep !== "start")
            closeStart();
        if (keep !== "launcher")
            launcherOpen = false;
        if (keep !== "clipboard")
            clipboardOpen = false;
        if (keep !== "session")
            sessionOpen = false;
        // anything else opening drops the question (no dialog under another, no yes left waiting)
        sessionConfirm = "";
    }
    onLauncherOpenChanged: {
        if (launcherOpen && setupLocked)
            launcherOpen = false;
        else if (launcherOpen)
            closeTransient("launcher");
    }
    onClipboardOpenChanged: {
        if (clipboardOpen && setupLocked)
            clipboardOpen = false;
        else if (clipboardOpen)
            closeTransient("clipboard");
    }
    onSessionOpenChanged: {
        if (sessionOpen && setupLocked)
            sessionOpen = false;
        else if (sessionOpen)
            closeTransient("session");
    }

    // ---- Start menu: a layer-shell overlay per screen (xdg popups opened without
    // a click are dismissed by the compositor, so Meta taps could not use them) ----
    property string startScreen: ""          // screen whose Start menu is open
    property string startPrefill: ""         // `angelos startText …`: typed into Start's search when it opens
    property var startButtons: ({})          // screen -> {item, window} of its Start button
    function registerStartButton(screen, item, window) {
        const m = Object.assign({}, startButtons);
        m[screen] = {
            "item": item,
            "window": window
        };
        startButtons = m;
    }
    function unregisterStartButton(screen, item) {
        if (!startButtons[screen] || startButtons[screen].item !== item)
            return;
        const m = Object.assign({}, startButtons);
        delete m[screen];
        startButtons = m;
    }
    function openStart(screen) {
        // nothing said where (a Meta tap, IPC): the look's "open on" (StartPrefs)
        screen = screen || StartPrefs.screenFor() || (focusedScreen ? focusedScreen.name : "");
        if (!screen || locked || setupLocked)
            return;
        launcherOpen = false;
        startScreen = screen;
    }
    function closeStart() {
        startScreen = "";
    }
    // the Golden Gate skin's Spotlight in a browsing mode ("apps": every app as a grid — the
    // Dock's Apps, macOS's successor of Launchpad); the look takes it when it opens
    property string startMode: ""
    function openApps(screen) {
        startMode = "apps";
        if (startScreen !== "")
            closeStart();
        openStart(screen);
    }
    function toggleStart(screen) {
        screen = screen || StartPrefs.screenFor() || (focusedScreen ? focusedScreen.name : "");
        if (startScreen === screen)
            closeStart();
        else
            openStart(screen);
    }

    // ANGELOS_SCREENS=HDMI-A-1,... limits the shell to some outputs (dev runs, streaming setups)
    readonly property var onlyScreens: (Quickshell.env("ANGELOS_SCREENS") || "").split(",").filter(s => s !== "")
    readonly property var screens: dev && onlyScreens.length ? Quickshell.screens.filter(s => onlyScreens.includes(s.name)) : Quickshell.screens
    readonly property var focusedScreen: screens.find(s => s.name === Niri.focusedOutput) || screens[0]
    // The main screen (Settings → Monitor → Main screen): the desktop widgets, the angel
    // and her cracks, rays and quake, the idle screen and the sidebar live there. Not
    // picked, or not connected: the widest screen — the main landscape monitor next to
    // portrait side screens. The lock's password box is there too (Config.lock.passwordOn
    // "main"; keys typed on another screen are handed over to it).
    readonly property var widestScreen: screens.reduce((best, s) => !best || s.width > best.width ? s : best, null)
    readonly property var primaryScreen: screenByName(Config.system.primaryScreen) || widestScreen
    readonly property string primaryName: primaryScreen ? primaryScreen.name : ""

    function screenByName(name) {
        return screens.find(s => s.name === name) || null;
    }
    // The screen for something shown once in front of the user, not asked for there (the tips
    // after the wizard): the one given (where the wizard was answered), else the main screen when
    // its bar has Start, a screen whose bar has Start, niri's focus, the first one. A streamed
    // screen never while stream mode is on (null when every screen is). niri's focus alone was
    // wrong: after the full-screen wizard closed it could be on any output, and screens[0] is no
    // main screen either (2026-10-08).
    function mainScreenFor(name) {
        const order = [screenByName(name || ""), startButtons[primaryName] ? primaryScreen : null].concat(Object.keys(startButtons).sort().map(screenByName), [focusedScreen], screens);
        return order.find(s => !!s && !StreamMode.onStream(s.name)) || null;
    }
    // a window covers the whole screen on its active workspace (a game, a video)
    function fullscreenOn(name) {
        const s = screenByName(name);
        const ws = Niri.activeWorkspace(name);
        if (!s || !ws || ws.active_window_id === null || ws.active_window_id === undefined)
            return false;
        const w = Niri.windows.find(x => x.id === ws.active_window_id);
        const size = w && w.layout ? w.layout.window_size : null;
        return !!size && size[0] >= s.width && size[1] >= s.height;
    }
    // nobody looks at this screen: locked, the first-run wizard over it, the idle screen over
    // it, or a fullscreen window on top. Timers that only animate things (angel, cava, clocks,
    // the live wallpaper) pause then.
    function hiddenScreen(name) {
        return locked || setupLocked || idleOver(name) || fullscreenOn(name);
    }
    // a game runs (niri-game-mode's $XDG_RUNTIME_DIR/niri-game-mode/state says "game"): what only
    // animates (the live wallpaper, the spectrum, hell's flames) stands still on every screen, the
    // other one too, so niri draws nothing but the game. The clocks and the readings go on.
    // Motion goes "off" for it too: the bar, the Halo, the menus without animations.
    property bool gaming: false
    onGamingChanged: Motion.gaming = gaming
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/niri-game-mode/state"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.gaming = text().trim() === "game"
        onLoadFailed: root.gaming = false
    }
    // Windows cover the screen (the wallpaper, spectrum and desktop widgets are not seen): the union of
    // the windows' rectangles on the screen's active workspace is >= 95% of the screen. Recomputed once
    // per change of Niri.windows/workspaces/screens into a name -> bool map, not per binding.
    // Windows' opacity/blur is unknown to niri's IPC, so the terminals (usually translucent) and
    // angelOS's own windows are not counted: better to keep the wallpaper running than to stop a seen one.
    readonly property var _coveredMap: {
        const res = {};
        const wins = Niri.windows;
        for (const s of screens) {
            const ws = Niri.activeWorkspace(s.name);
            if (!ws || !s.width || !s.height)
                continue;
            const rects = [];
            for (const w of wins) {
                if (w.workspace_id !== ws.id)
                    continue;
                const l = w.layout;
                const sz = l ? l.window_size : null;
                if (!sz || !(sz[0] > 0) || !(sz[1] > 0))
                    continue;
                if (/^(kitty|foot|alacritty|org\.wezfurlong\.wezterm|com\.mitchellh\.ghostty|konsole|org\.kde\.konsole|quickshell|angelos)/i.test(String(w.app_id || "")))
                    continue;
                // the position on the screen is known for tiles in view; a window without one only counts alone
                const pos = l.tile_pos_in_workspace_view;
                const x = pos ? pos[0] : 0, y = pos ? pos[1] : 0;
                const x1 = Math.max(0, x), y1 = Math.max(0, y);
                const x2 = Math.min(s.width, x + sz[0]), y2 = Math.min(s.height, y + sz[1]);
                if (x2 > x1 && y2 > y1)
                    rects.push({
                        "x1": x1, "y1": y1, "x2": x2, "y2": y2, "alone": !pos
                    });
            }
            const total = s.width * s.height;
            let area = 0;
            // no position: only a single such window covering the screen by size counts
            const lone = rects.filter(r => r.alone && (r.x2 - r.x1) * (r.y2 - r.y1) >= 0.95 * total);
            if (lone.length)
                area = total;
            else {
                const rs = rects.filter(r => !r.alone);
                const xset = new Set();
                for (const r of rs) {
                    xset.add(r.x1);
                    xset.add(r.x2);
                }
                const xs = [...xset].sort((a, b) => a - b);
                for (let i = 0; i + 1 < xs.length; i++) {
                    // union of the y-intervals of the rectangles spanning the strip xs[i]..xs[i+1]
                    const iv = rs.filter(r => r.x1 <= xs[i] && r.x2 >= xs[i + 1]).map(r => [r.y1, r.y2]).sort((a, b) => a[0] - b[0]);
                    let len = 0, end = -1;
                    for (const [a, b] of iv) {
                        const from = Math.max(a, end);
                        if (b > from)
                            len += b - from;
                        end = Math.max(end, b);
                    }
                    area += len * (xs[i + 1] - xs[i]);
                }
            }
            res[s.name] = area >= 0.95 * total;
        }
        return res;
    }
    function coveredScreen(name) {
        return _coveredMap[name] === true;
    }
    function stillScreen(name) {
        return gaming || hiddenScreen(name) || coveredScreen(name);
    }
    // the idle screen (modules/idle/IdleScreen) covers every screen, or the main one only
    function idleOver(name) {
        return Idle.active && (Config.idle.allScreens || name === primaryName || screens.length === 1);
    }

    // the page id to store: an old id that leads to a group stays as it is, SettingsView.redirect
    // resolves it and scrolls to the group (resolved here, the group would be lost)
    function settingsPageFor(id) {
        const r = SettingsTree.resolve(id);
        return r.to ? id : r.page;
    }
    // with no page given Settings open on Home (a window already open stays where it is)
    function openSettings(page, sub) {
        // an old page id leads to its page in the tree (SettingsTree.resolve: "bar" → taskbar…);
        // the views with a home of their own (a folder of icons, the tiles) open there
        if (page)
            settingsPage = settingsPageFor(page);
        else if (!settingsOpen) {
            // a fresh window always opens on Home
            settingsPage = "main";
            settingsSub = "";
        }
        if (sub)
            settingsSub = sub;
        settingsOpen = true;
    }
    // ---- more Settings windows than one (Ctrl+N, a middle click on a section, `angelos settingsNew`) ----
    // The main window keeps its place here (settingsPage, settingsSub, settingsOpen); each of the
    // others has its own SettingsNav with the same three names, so the views and the pages read
    // either one the same way: Shell.settingsNavFor(item) is the place of the window the item is in.
    // Start, the helper, IPC and the hotkeys keep to the main window.
    readonly property int settingsMoreMax: 8
    property ListModel settingsMore: ListModel {}   // { key, page, sub }: one per extra window
    property int settingsMoreKey: 0
    property var settingsActive: null               // the SettingsView whose window has the focus
    function newSettingsWindow(page, sub) {
        if (setupLocked || settingsMore.count >= settingsMoreMax)
            return false;
        settingsMore.append({
            "key": ++settingsMoreKey,
            "page": page ? settingsPageFor(page) : "home",
            "sub": sub || ""
        });
        return true;
    }
    function closeSettingsWindow(key) {
        for (let i = 0; i < settingsMore.count; i++)
            if (settingsMore.get(i).key === key)
                return settingsMore.remove(i);
    }
    // the SettingsView an item is in (the main one for anything outside Settings)
    function settingsViewFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.settingsNav !== undefined)
                return p;
        return settingsView;
    }
    function settingsNavFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.settingsNav !== undefined)
                return p.settingsNav || root;
        return root;
    }
    // a link inside Settings goes on in its own window; anywhere else it opens Settings
    function settingsGo(item, page, sub) {
        const nav = settingsNavFor(item);
        if (nav === root)
            return openSettings(page, sub);
        nav.settingsPage = settingsPageFor(page);
        if (sub)
            nav.settingsSub = sub;
    }
    function toggleSettings(page) {
        // an old id (Mod+S still says "appearance") closes its page in the tree too
        if (settingsOpen && (!page || SettingsTree.resolve(page).page === settingsPage))
            settingsOpen = false;
        else
            openSettings(page);
    }
    // Apps started from angelOS get the environment the shell itself started with:
    // the renderer variables bin/angelos set for the shell are put back, and the
    // cursor follows Settings → Cursor even before the next login.
    function _pre(name) {
        const v = Quickshell.env("ANGELOS_PRE_" + name);
        return v === null || v === undefined || v === "" ? null : v;
    }
    readonly property var childEnv: {
        const e = {};
        if (Quickshell.env("ANGELOS_PRE_QT_PLUGIN_PATH") != null)
            e.QT_PLUGIN_PATH = _pre("QT_PLUGIN_PATH");
        if (Quickshell.env("ANGELOS_PRE_QSG_RHI_BACKEND") != null)
            e.QSG_RHI_BACKEND = _pre("QSG_RHI_BACKEND");
        e.ANGELOS_PRE_QT_PLUGIN_PATH = null;
        e.ANGELOS_PRE_QSG_RHI_BACKEND = null;
        // the shell's jemalloc settings (bin/angelos) are for its own shape, not an app's
        if (Quickshell.env("ANGELOS_PRE_MALLOC_CONF") != null)
            e.MALLOC_CONF = _pre("MALLOC_CONF");
        e.ANGELOS_PRE_MALLOC_CONF = null;
        e.ANGELOS_SETTINGS_WARM = null;
        // Qt apps in angelOS's look (Settings → Appearance → Qt apps): qt6ct from now on,
        // not only after the next login (bin/angelos keeps the shell itself on gtk3)
        // off: what the session had — but never a GTK platform theme (GTK menus and dialogs in Qt
        // apps); the shell's own gtk3 (bin/angelos) never reaches an app
        if (Config.appearance.qtStyle) {
            e.QT_QPA_PLATFORMTHEME = "qt6ct";
        } else {
            const was = _pre("QT_QPA_PLATFORMTHEME") || Quickshell.env("QT_QPA_PLATFORMTHEME") || "";
            e.QT_QPA_PLATFORMTHEME = was && !/^gtk/.test(was) ? was : null;
        }
        e.ANGELOS_PRE_QT_QPA_PLATFORMTHEME = null;
        // Qt's own title bars: the shell keeps them off for itself (bin/angelos); the apps draw
        // theirs in Golden Gate (Adwaita's frame, the buttons in GTK's order — niri's
        // prefer-no-csd is off there, templates/niri-mac.kdl), not in the pixel skins
        if (GoldenGate.on) {
            e.QT_WAYLAND_DISABLE_WINDOWDECORATION = null;
            e.QT_WAYLAND_DECORATION = "adwaita";
        } else if (Quickshell.env("ANGELOS_PRE_QT_WAYLAND_DISABLE_WINDOWDECORATION") != null) {
            e.QT_WAYLAND_DISABLE_WINDOWDECORATION = _pre("QT_WAYLAND_DISABLE_WINDOWDECORATION");
        }
        e.ANGELOS_PRE_QT_WAYLAND_DISABLE_WINDOWDECORATION = null;
        // the systemd service's own variables are not the apps' business
        if (service) {
            for (const k of ["ANGELOS_SERVICE", "INVOCATION_ID", "JOURNAL_STREAM", "SYSTEMD_EXEC_PID", "MANAGERPID", "MANAGERPIDFDID", "MEMORY_PRESSURE_WATCH", "MEMORY_PRESSURE_WRITE"])
                e[k] = null;
        }
        if (Cursors.active) {
            e.XCURSOR_THEME = Cursors.active;
            e.XCURSOR_SIZE = String(Cursors.size);
        }
        return e;
    }
    // Running as the systemd user service (bin/angelos start): every app goes into
    // its own scope, so a shell restart (KillMode=process) or systemd-oomd acting on
    // the shell never takes the user's programs along.
    readonly property bool service: Quickshell.env("ANGELOS_SERVICE") === "1"
    property bool scopes: false
    property Process scopeProbe: Process {
        running: root.service
        command: ["systemd-run", "--user", "--scope", "--quiet", "--collect", "true"]
        onExited: code => root.scopes = code === 0
    }
    function scoped(cmd) {
        if (!scopes || !cmd || !cmd.length)
            return cmd;
        const name = String(cmd[0]).split("/").pop().replace(/[^A-Za-z0-9_.]/g, "_").slice(0, 40) || "app";
        return ["systemd-run", "--user", "--scope", "--quiet", "--collect", "--slice=app.slice", "--unit=app-angelos-" + name + "-" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36), "--"].concat(cmd);
    }
    // apps that draw their own title bar (Config.mac.ownFrameApps, by desktop id or app id —
    // Telegram and its forks): no Qt frame of Golden Gate's over it (QT_WAYLAND_DECORATION adwaita
    // put a GTK-looking header bar on top of Telegram)
    function ownFrame(appId) {
        const id = String(appId || "").toLowerCase();   // (org.telegram.desktop ends in ".desktop" itself)
        // (a plain array: the settings file's list arrives as a Qt sequence)
        const list = JSON.parse(JSON.stringify(Config.mac.ownFrameApps || []));
        return !!id && list.some(x => String(x).toLowerCase() === id);
    }
    function envFor(appId) {
        if (!GoldenGate.on || !ownFrame(appId))
            return childEnv;
        return Object.assign({}, childEnv, {
            "QT_WAYLAND_DECORATION": null,
            "QT_WAYLAND_DISABLE_WINDOWDECORATION": "1"
        });
    }
    function exec(cmd, workingDirectory, appId) {
        const ctx = {
            "command": scoped(cmd),
            "environment": envFor(appId)
        };
        if (workingDirectory)
            ctx.workingDirectory = workingDirectory;
        Quickshell.execDetached(ctx);
    }
    function sh(script) {
        exec(["sh", "-c", script]);
    }
    // a desktop file's action (New window, New private window…) in the apps' environment:
    // DesktopAction.execute() would hand it the shell's own
    function launchAction(action, appId) {
        if (!action)
            return;
        if (action.command && action.command.length)
            exec(action.command, "", appId);
        else
            action.execute();
    }
    // argv to run a command in the configured terminal (kitty/foot take the program directly);
    // appId names the terminal window so niri rules can match it (the task manager floats)
    function terminalArgv(argv, appId) {
        const t = Config.system.terminal || "kitty";
        const base = t.split("/").pop();
        let cls = [];
        if (appId)
            cls = base === "foot" ? ["--app-id=" + appId] : base === "ghostty" ? ["--class=" + appId] : base === "wezterm" ? ["--class", appId] : base === "kitty" || base === "alacritty" ? ["--class", appId] : [];
        if (!argv || argv.length === 0)
            return [t].concat(cls);
        if (base === "kitty" || base === "foot")
            return [t].concat(cls, argv);
        if (base === "wezterm")
            return [t, "start"].concat(cls, ["--"], argv);
        return [t].concat(cls, ["-e"], argv);
    }
    // How far a package transaction is, from one line of its output (pacman/paru without a
    // terminal, flatpak): 0…1, or -1 when the line says nothing. pacman prints its phases in
    // order — the downloads, the checks, "installing x..." per package, the hooks "(2/5) …" — so
    // the bar moves through them; `prev` is where it was (downloads creep towards the checks).
    function stepOf(line, prev) {
        const p = prev || 0;
        let m = /^\s*(?:Installing|Updating|Uninstalling)\s+(\d+)\/(\d+)/.exec(line);  // flatpak
        if (m)
            return Math.max(p, (Number(m[1]) - 1) / Math.max(1, Number(m[2])));
        if (/^:: Retrieving packages/.test(line))
            return Math.max(p, 0.05);
        if (/\bdownloading\.\.\.$|\bdownloaded\b/.test(line))
            return Math.max(p, p + (0.45 - p) * 0.18);
        if (/^checking keyring|^\(\d+\/\d+\) checking keys/.test(line))
            return Math.max(p, 0.5);
        if (/^checking package integrity|^loading package files|^checking for file conflicts|^checking available disk space/.test(line))
            return Math.max(p, 0.56);
        if (/^:: Processing package changes/.test(line))
            return Math.max(p, 0.6);
        if (/^(?:\(\s*\d+\/\d+\)\s+)?(?:installing|upgrading|reinstalling|downgrading|removing)\s+\S+/.test(line))
            return Math.max(p, p + (0.92 - p) * 0.25);
        if (/^:: Running post-transaction hooks/.test(line))
            return Math.max(p, 0.92);
        m = /^\(\s*(\d+)\/(\d+)\)\s/.exec(line);
        if (m && p >= 0.92)
            return Math.max(p, 0.92 + 0.08 * Number(m[1]) / Math.max(1, Number(m[2])));
        m = /(\d{1,3})%\s*$/.exec(line);
        if (m && p < 0.6)
            return Math.max(p, 0.05 + 0.4 * Math.min(100, Number(m[1])) / 100);
        return -1;
    }
    function terminal(cmd) {
        exec(terminalArgv(cmd ? ["sh", "-c", cmd] : []));
    }
    function openPath(path) {
        exec(["xdg-open", Config.expand(path)]);
    }

    // ---- the session's actions: one place for the session menu, Start's buttons (services/
    // StartItems) and the Golden Gate menus. lock | idle | suspend | logout | reboot | poweroff ----
    // Logging out, restarting and shutting down only ask (modules/session/SessionConfirm, one
    // dialog for every way in: a click, a letter, Enter, Start's buttons); the yes there does it.
    // One stray key used to switch the computer off (16.10)
    readonly property var sessionAsks: ["logout", "reboot", "poweroff"]
    property string sessionConfirm: ""       // the action the dialog asks about ("" = no dialog)
    function sessionAction(id) {
        if (sessionAsks.includes(id)) {
            if (locked || setupLocked || bye.running)
                return;
            closeTransient("");
            // a second ask takes the dialog's place, never a second dialog
            sessionConfirm = id;
            return;
        }
        sessionNow(id);
    }
    // the dialog's yes: what it asked about, read here (not from the dialog), and asked only once
    function sessionConfirmed() {
        const id = sessionConfirm;
        sessionConfirm = "";
        if (!sessionAsks.includes(id) || locked || bye.running)
            return;
        // let the Y2K goodbye chime play before the session goes away
        if (Sounds.enabled("shutdown")) {
            Sounds.play("shutdown");
            bye.action = id;
            bye.restart();
            return;
        }
        sessionNow(id);
    }
    onLockedChanged: if (locked)
        sessionConfirm = ""
    property Timer bye: Timer {
        property string action
        interval: 1300
        onTriggered: root.sessionNow(action)
    }
    // the UI tests (ANGELOS_TEST) never end the session: the action is only written down
    readonly property bool sessionFake: Quickshell.env("ANGELOS_TEST") === "1"
    property var sessionRan: []
    function sessionNow(id) {
        if (sessionFake && sessionAsks.includes(id)) {
            sessionRan = sessionRan.concat([id]);
            console.log("[test] session " + id + " skipped");
            return;
        }
        switch (id) {
        case "lock":
            lock();
            break;
        case "idle":
            Idle.start();
            break;
        case "suspend":
            suspend();
            break;
        case "logout":
            Niri.quit();
            break;
        case "reboot":
            exec(["systemctl", "reboot"]);
            break;
        case "poweroff":
            exec(["systemctl", "poweroff"]);
            break;
        }
    }

    // Sleep at once, no question (like Windows): the menus close, every screen goes out like a
    // CRT for ~0.3 s (modules/session/SleepFade), then systemd suspends. The cover goes on
    // waking (logind via Lock: resumed) or a few seconds after anyway — a failed suspend never
    // leaves a black screen; a click on it takes it away too. The dev stand never sleeps the
    // machine: it plays the fade and only logs.
    property bool sleepFx: false
    function suspend() {
        if (sleepFx)
            return;
        closeTransient("");
        sleepFx = true;
        sleepGo.restart();
    }
    property Timer sleepGo: Timer {
        interval: Motion.calm ? 80 : 340
        onTriggered: {
            if (root.dev)
                console.log("[dev] suspend skipped");
            else
                root.exec(["systemctl", "suspend"]);
            root.sleepOff.restart();
        }
    }
    property Timer sleepOff: Timer {
        interval: 4000
        onTriggered: root.sleepFx = false
    }
    onResumed: {
        sleepOff.stop();
        sleepFx = false;
    }
}
