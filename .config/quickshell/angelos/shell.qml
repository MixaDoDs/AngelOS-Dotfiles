//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
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
import qs.modules.tour
import qs.modules.voxtype
import qs.modules.idle
import qs.modules.sidebar
import qs.modules.y2k
import qs.modules.alttab
import qs.modules.cursor
import qs.modules.lens
import qs.modules.decor
import qs.modules.novel
import qs.modules.debug
import qs.modules.mac
import qs.widgets

// angelOS — pixel pink shell for niri.
ShellRoot {
    // no hot reload on save: edits land via `angelos reload` once they are checked
    settings.watchFiles: Quickshell.env("ANGELOS_DEV") === "1"

    Background {}
    Bar {}
    MacDesktop {}
    StartOverlay {}
    SidebarHost {}
    WorkspaceFx {}
    NotificationPopups {}
    Osd {}
    VoxIndicator {}
    Launcher {}
    ClipboardPanel {}
    SessionMenu {}
    IdleScreen {}
    Lock {}
    PolkitDialog {}
    SettingsWindow {}
    UpdatePrompt {}
    SetupWizard {}
    TourOverlay {}
    PluginHost {}
    AngelHelper {}
    NovelHost {}
    HeavenRays {}
    ScreenQuake {}
    HellFxOverlay {}
    CircleTransition {}
    BootScreen {}
    AltTabHost {}
    ShakeCursor {}
    LensOverlay {}
    WindowDecor {}
    GameDebugWindow {}
    Ipc {}

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

    Component.onCompleted: {
        ThemeExport.signature; // wake the template exporter
        PaletteGenerator.auto; // follow wallpaper colours from startup
        Fonts.files; // register fonts installed into ~/.local/share/fonts/angelos
        MetaTap.status; // Meta tap → Start menu
        Idle.active; // idle-minutes watcher
        NautilusSetup.status; // first run: Nautilus defaults + mediafix
        PluginStudio.loaded; // make the worker available to dynamically loaded pages
        Updates.state; // daily update check (Settings → Updates)
        WorkspaceAnim.current; // control socket for `angelos ws`
        Sounds.ready; // Y2K sound pack (generated on first use)
        StreamMode.active; // OBS watcher: stream mode while live
        Angel.demon; // the corner helper's schedule (tips, the demon's pranks)
        AltTab.ours; // Alt+Tab: windows in MRU order, niri's binds follow the chosen style
        InputConfig.numlock; // NumLock on login: checked once per login (scripts/numlock.py)
        FastfetchLogo.signature; // fastfetch draws the chosen emblem (Settings → Bar → Logo)
        CursorShake.status; // shake the mouse to find the pointer (Settings → Cursor)
        Novel.loaded; // the novel (~/AngelOs-Nov): chapters, the notes, her questions
    }
}
