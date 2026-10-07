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
    signal setupStepRequested(int step)
    signal setupSkipRequested()       // `angelos setup skip`: out of the wizard at once
    // The setup wizard (modules/settings/SetupWizard) covers every screen and the desktop
    // waits — Start, the launcher, Settings, the menus, the shell's hotkeys and niri's do
    // nothing. The first run lets go only when it is done (or `angelos setup skip`); opened
    // again from Settings (or `angelos setup`) it has "Close", and Settings come back after.
    property bool setupFirstRun: false
    readonly property bool setupLocked: setupOpen
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
    property bool bootOpen: false            // Y2K loading screen (modules/y2k/BootScreen)
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
    property bool locked: false
    property bool lockPreview: false         // the lock screen in a normal overlay, nothing is checked
    property var lockPreviewTry: null        // (text) → plays the preview's reaction; never touches PAM
    property string lockPreviewDemo: ""      // the preview types this in by itself a moment after it opens
    property var polkitReregister: null
    property bool polkitRegistered: false
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
    // portrait side screens. The lock keeps its password box where the focus is: that
    // is where niri sends the keys.
    readonly property var widestScreen: screens.reduce((best, s) => !best || s.width > best.width ? s : best, null)
    readonly property var primaryScreen: screenByName(Config.system.primaryScreen) || widestScreen
    readonly property string primaryName: primaryScreen ? primaryScreen.name : ""

    function screenByName(name) {
        return screens.find(s => s.name === name) || null;
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
    // nobody looks at this screen: locked, the first-run wizard over it, or a fullscreen
    // window on top. Timers that only animate things (angel, cava, clocks) pause then.
    function hiddenScreen(name) {
        return locked || setupLocked || fullscreenOn(name);
    }

    // with no page given Settings open on Home (a window already open stays where it is)
    function openSettings(page, sub) {
        // an old page id leads to its page in the tree (SettingsTree.resolve: "bar" → taskbar…);
        // the views with a home of their own (a folder of icons, the tiles) open there
        if (page)
            settingsPage = SettingsTree.resolve(page).page;
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
            "page": page ? SettingsTree.resolve(page).page : "home",
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
        nav.settingsPage = SettingsTree.resolve(page).page;
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
    function terminal(cmd) {
        exec(terminalArgv(cmd ? ["sh", "-c", cmd] : []));
    }
    function openPath(path) {
        exec(["xdg-open", Config.expand(path)]);
    }
}
