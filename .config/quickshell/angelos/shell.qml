//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules
import qs.modules.background
import qs.modules.desktop
import qs.modules.clipboard
import qs.modules.bar
import qs.modules.launcher
import qs.modules.lock
import qs.modules.notifications
import qs.modules.osd
import qs.modules.polkit
import qs.modules.session
import qs.modules.settings
import qs.modules.workspace
import qs.modules.voxtype
import qs.modules.idle
import qs.modules.sidebar
import qs.modules.y2k
import qs.modules.alttab
import qs.modules.mission
import qs.modules.cursor
import qs.modules.cobweb
import qs.modules.lens
import qs.modules.circle
import qs.modules.capture
import qs.modules.quickshare
import qs.modules.quicklook
import qs.modules.convert
import qs.modules.island
import qs.modules.lenssearch
import qs.modules.streamchat
import qs.modules.halo
import qs.modules.novel
import qs.modules.diary
import qs.modules.mac
import qs.widgets

// angelOS — pixel pink shell for niri.
ShellRoot {
    // no hot reload on save: edits land via `angelos reload` once they are checked
    settings.watchFiles: Quickshell.env("ANGELOS_DEV") === "1"

    Background {}
    Bar {}
    HaloHost {}
    MacDesktop {}
    SidebarHost {}
    DiaryTab {}
    WorkspaceFx {}
    NotificationPopups {}
    Osd {}
    VoxIndicator {}
    IdleScreen {}
    AwakeKeeper {}
    Lock {}
    SleepFade {}
    PolkitDialog {}
    UpdatePrompt {}
    MainScreenPrompt {}
    TelemetryPrompt {}
    SettingsLookPrompt {}
    AppsSyncPrompt {}
    SetupWizard {}
    PluginHost {}
    AngelHelper {}
    StreamerCast {}
    PrivacyCast {}
    NovelHost {}
    HeavenRays {}
    AchievementToast {}
    ScreenQuake {}
    HellFxOverlay {}
    CircleTransition {}
    BootScreen {}
    AltTabHost {}
    MissionControl {}
    ShakeCursor {}
    CobwebOverlay {}
    LensOverlay {}
    ShotPreview {}
    ShareSheet {}
    LensWindow {}
    ChatRunners {}
    QuickLookWindow {}
    ConvertRing {}
    IslandProbe {}
    Ipc {}
    IpcEvents {}
    // Launcher, ClipboardPanel, SessionMenu, SettingsWindow, the author's GameDebugWindow: built on demand
    LazyWindows {}

    // Keep dynamically loaded settings pages visible to Quickshell's static
    // QML importer. Without these type anchors, pages loaded later through a
    // Loader report "PxPositionPicker/BarLayoutEditor is not a type" (same for
    // the simple view's tiles and the settings previews).
    Component {
        id: positionPickerTypeAnchor
        PxPositionPicker {}
    }
    Component {
        id: barLayoutEditorTypeAnchor
        BarLayoutEditor {}
    }
    Component {
        id: startTunerTypeAnchor
        StartTuner {}
    }
    Component {
        id: textAreaTypeAnchor
        PxTextArea {}
    }
    Component {
        id: tileTypeAnchor
        PxTile {}
    }
    Component {
        id: previewTypeAnchor
        PxPreview {}
    }
    Component {
        id: grimoirePhotoTypeAnchor
        GrimoirePhoto {}
    }
    Component {
        id: fastfetchPreviewTypeAnchor
        FastfetchPreview {}
    }
    // the setup wizard's gloss and effects (its questions are loaded from a file)
    Component {
        id: setupGlossTypeAnchor
        SetupGloss {}
    }
    Component {
        id: setupFxTypeAnchor
        SetupFx {}
    }

    Component.onCompleted: {
        ThemeExport.signature; // wake the template exporter
        PaletteGenerator.auto; // follow wallpaper colours from startup
        Fonts.files; // register fonts installed into ~/.local/share/fonts/angelos
        MetaTap.status; // Meta tap → Start menu
        Idle.active; // idle-minutes watcher
        NautilusSetup.status; // first run: Nautilus defaults + mediafix
        StrataSetup.status; // Strata (the file manager): angelOS's menu items + theme, once it is there
        Outputs.monitorFile; // monitors nobody picked a mode for: their full refresh rate, not niri's 60 Hz
        PluginStudio.loaded; // make the worker available to dynamically loaded pages
        Updates.state; // daily update check (Settings → Updates)
        AppsSync.count; // the author's new apps after an update: told once, installed only when asked
        WorkspaceAnim.current; // control socket for `angelos ws`
        Sounds.ready; // Y2K sound pack (generated on first use)
        StreamMode.active; // OBS watcher: stream mode while live
        QsVersion.state; // an outdated Quickshell: one notification per version (scripts/qs-version.sh)
        Angel.demon; // the corner helper's schedule (tips, the demon's pranks)
        Achievements.loaded; // the achievements: counting starts with the shell (the game on only)
        Diary.loaded; // the Angel's diary: a page written later comes as a card (the game on only)
        AltTab.ours; // Alt+Tab: windows in MRU order, niri's binds follow the chosen style
        InputConfig.numlock; // NumLock on login: checked once per login (scripts/numlock.py)
        FastfetchLogo.signature; // fastfetch draws the chosen emblem (Settings → Bar → Logo)
        CursorShake.status; // shake the mouse to find the pointer (Settings → Cursor)
        Novel.loaded; // the novel (~/AngelOs-Nov): chapters, the notes, her questions
        KeyProfile.want; // every theme its own niri keys, switched with the theme
        CommunityPlugins.entries; // the plugin catalog: a daily update check, the old store retired
        GoldenGate.wallTheme; // every theme its own wallpapers
        Power.percent; // a laptop's battery: alerts, eco mode, idle on battery (services/Power)
        Backlight.available; // the backlight keys and the dimming before idle
        Gestures.status; // the touchpad's own gestures (scripts/gesture-watch.py)
        Wellbeing.loaded; // screen time and the breaks the angel reminds of (Settings → Wellbeing)
        Timers.loaded; // timers and pomodoros: one that ended while the shell was off still rings
        Capture.sorting; // niri's screenshots into month folders (scripts/screenshot-sort.py)
        Cobweb.enabled; // cobwebs on windows nobody moved for a while (Settings → Windows → Cobwebs)
        AppSleep.wanted; // programs nobody sees go to sleep (scripts/app-sleep.py)
        Devices.holders; // the keyboard's lights follow the system's colour (no helper until needed)
        CircleHost.open; // the screenshot overlay's own process (scripts/circle-proc.sh), ready before the key
        Timelapse.on; // the day's timelapse: recording all day when on, glued at midnight (Settings → Screenshots)
        StreamChat.on; // the stream's chat on screen, from a chat bot's log (Settings → Stream)
    }
    // the shell going away (`angelos restart`/stop and the unit's ExecStop use `qs kill`, a reload):
    // what still waits in a save's debounce is written, else the next start reads the file from
    // before it (a singleton's own onDestruction never runs)
    Component.onDestruction: {
        Config.persist();
        Story.persist();
    }
}
