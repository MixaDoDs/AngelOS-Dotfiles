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
    property bool gameOpen: false            // osu!mini window (plugin osu-mini)
    property bool locked: false
    property bool lockPreview: false         // the lock screen in a normal overlay, nothing is checked
    property var lockPreviewTry: null        // (text) → plays the preview's reaction; never touches PAM
    property var polkitReregister: null
    property bool polkitRegistered: false
    readonly property bool dev: Quickshell.env("ANGELOS_DEV") === "1"
    // niri sends "angelOS [dev]" windows to the non-stream monitor (cfg/rules.kdl)
    readonly property string appTitle: dev ? "angelOS [dev]" : "angelOS"
    // demo/recording mode: popups open from IPC without an input grab
    readonly property bool demo: Quickshell.env("ANGELOS_DEMO") === "1"
    property var desktopMenus: ({})   // screen name -> DesktopMenu
    property var decor: ({})          // screen name -> the angelOS title bars it shows (modules/decor; `angelos decor`)
    signal decorDrag(int id, real dx, real dy, int ms)   // dev/owner: a drag on a title bar, replayed (tests)
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
    onLauncherOpenChanged: if (launcherOpen)
        closeTransient("launcher")
    onClipboardOpenChanged: if (clipboardOpen)
        closeTransient("clipboard")
    onSessionOpenChanged: if (sessionOpen)
        closeTransient("session")

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
        if (!screen || locked)
            return;
        launcherOpen = false;
        startScreen = screen;
    }
    function closeStart() {
        startScreen = "";
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
    // nobody looks at this screen: locked, or a fullscreen window on top.
    // Timers that only animate things (angel, cava, clocks) pause then.
    function hiddenScreen(name) {
        return locked || fullscreenOn(name);
    }

    // with no page given Settings open where they were left, like macOS
    function openSettings(page, sub) {
        // an old page id leads to its page in the tree (SettingsTree.resolve: "bar" → taskbar…);
        // the views with a home of their own (a folder of icons, the tiles) open there
        if (page)
            settingsPage = SettingsTree.resolve(page).page;
        else if (!settingsOpen && ["controlpanel", "tiles"].includes(Config.settingsUi.view))
            settingsPage = "home";
        if (sub)
            settingsSub = sub;
        settingsOpen = true;
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
        if (Config.appearance.qtStyle)
            e.QT_QPA_PLATFORMTHEME = "qt6ct";
        e.ANGELOS_PRE_QT_QPA_PLATFORMTHEME = null;
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
    function exec(cmd, workingDirectory) {
        const ctx = {
            "command": scoped(cmd),
            "environment": childEnv
        };
        if (workingDirectory)
            ctx.workingDirectory = workingDirectory;
        Quickshell.execDetached(ctx);
    }
    function sh(script) {
        exec(["sh", "-c", script]);
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
