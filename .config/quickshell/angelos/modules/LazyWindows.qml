import QtQuick
import QtQml.Models
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import qs.modules.chest
import qs.modules.clipboard
import qs.modules.desktop
import qs.modules.diary
import qs.modules.gametune
import qs.modules.keycast
import qs.modules.launcher
import qs.modules.laptop
import qs.modules.reaper
import qs.modules.session
import qs.modules.settings
import qs.modules.tour

// Windows that are closed most of the time: each is built when it opens and kept a
// little after it closes (Linger: a quick reopen keeps its state), then it goes with
// everything it held. A closed launcher, clipboard, session menu or Settings holds no memory.
Scope {
    id: root

    Linger {
        id: launcherKeep
        when: Shell.launcherOpen
    }
    // …except where Settings is kept warm (16 GB or more: ANGELOS_SETTINGS_WARM): there the
    // launcher (~28 MB) is built in the background once the boot screen is gone and stays, so
    // Mod+Space shows it at once instead of building it first (~75 ms)
    readonly property bool launcherWarm: Quickshell.env("ANGELOS_SETTINGS_WARM") !== "0" && !Shell.bootOpen && !Shell.bootCover
    Connections {
        target: Shell
        function onLauncherOpenChanged() {
            if (Shell.launcherOpen)
                launcherLoader.active = true;
        }
    }
    LazyLoader {
        id: launcherLoader
        activeAsync: launcherKeep.alive || root.launcherWarm
        Launcher {}
    }

    // the Start menu: its windows (one per screen) exist while it is open and a little after
    // (the look's own Linger inside is 30 s)
    Linger {
        id: startKeep
        when: Shell.startScreen !== ""
        ms: 40000
    }
    LazyLoader {
        active: startKeep.alive
        StartOverlay {}
    }

    // heaven's chest (services/Chests): built when one opens
    Linger {
        id: chestKeep
        when: Chests.open
    }
    LazyLoader {
        active: chestKeep.alive
        ChestOverlay {}
    }

    // the people of the Discord call over the bar: only while there is a call to show
    LazyLoader {
        active: Config.discord.crew && DiscordVoice.state === "call"
        DiscordCrew {}
    }
    // the keys pressed on screen (Mod+Shift+K): only while it is on
    LazyLoader {
        active: KeyCast.on
        KeyCastOverlay {}
    }
    // a new Steam game's note (services/GameTune): only while one is open
    LazyLoader {
        active: !!GameTune.noteGame
        GameNote {}
    }

    Linger {
        id: clipboardKeep
        when: Shell.clipboardOpen
    }
    LazyLoader {
        active: clipboardKeep.alive
        ClipboardPanel {}
    }

    Linger {
        id: sessionKeep
        when: Shell.sessionOpen
    }
    LazyLoader {
        active: sessionKeep.alive
        SessionMenu {}
    }

    Linger {
        id: sessionConfirmKeep
        when: Shell.sessionConfirm !== ""
    }
    LazyLoader {
        active: sessionConfirmKeep.alive
        SessionConfirm {}
    }

    Linger {
        id: projectKeep
        when: Shell.projectOpen
    }
    LazyLoader {
        active: projectKeep.alive
        ProjectMenu {}
    }

    // the tour: ~800 objects that are only of use while it runs
    Linger {
        id: tourKeep
        when: Tour.running
        ms: 10000
    }
    LazyLoader {
        active: tourKeep.alive
        TourOverlay {}
    }

    // a minute: back/forward history lives in the window
    Linger {
        id: settingsKeep
        when: Shell.settingsOpen
        ms: 60000
    }
    // …and while it is likely to be opened it is built ahead, hidden — its frame, the
    // navigation, Home, the search with its index, the look in use — so it opens at once
    // (the pages one goes on to come and go: SettingsView). Likely: a way to it is open —
    // Start, the sidebar, the desktop's right-click menu (each has a Settings entry). Kept
    // always it was 11 700 of the shell's 25 500 objects and ~166 MB (the stand, 18.10), for
    // a window opened a few times a day; so it is built then, in the background (no second
    // of CPU in front of the menu just opened), and goes 3 min after the last such moment
    // with Settings closed. The Halo's card and the bar's buttons are not asked: their open /
    // hovered state lives in their own windows. Not during the boot screen, the first-run
    // wizard or a stream; not in the eco mode either (services/Power): it goes when eco
    // comes, and opens as any other window does. Only with 16 GB of memory or more:
    // bin/angelos starts the shell with ANGELOS_SETTINGS_WARM=1 there and =0 below.
    readonly property bool settingsLikely: Shell.startScreen !== "" || Sidebar.open || Object.keys(Shell.desktopMenus).some(k => {
        const m = Shell.desktopMenus[k];
        return !!m && (m.visible && !m.own || !!m.radial && m.radial.visible);
    })
    Linger {
        id: settingsLikelyKeep
        when: root.settingsLikely || Shell.settingsOpen
        ms: 180000
        onAliveChanged: if (!alive)
            Shell.settingsWarm = false
    }
    Connections {
        target: Power
        function onEcoChanged() {
            if (Power.eco)
                Shell.settingsWarm = false;
        }
    }
    Timer {
        // a moment: a menu flicked open and shut builds nothing, and its own opening goes first
        interval: 400
        running: root.settingsLikely && !Shell.settingsWarm && !Power.eco && Quickshell.env("ANGELOS_SETTINGS_WARM") !== "0" && !Shell.bootOpen && !Shell.bootCover && !Shell.setupOpen && !StreamMode.active
        onTriggered: {
            if (!Shell.settingsOpen) {
                Shell.settingsPage = "main";     // what opening without a page shows
                Shell.settingsSub = "";
            }
            Shell.settingsWarm = true;
        }
    }
    // built ahead in the background; opened, it is finished at once
    Connections {
        target: Shell
        function onSettingsOpenChanged() {
            if (Shell.settingsOpen)
                (root.settingsOverDesk ? settingsOverlayLoader : settingsLoader).active = true;
        }
    }
    // the P5 look opens over the whole desktop (SettingsOverlay); Golden Gate and hell's dresses
    // keep a window (the same choice as SettingsView.p5)
    readonly property bool settingsOverDesk: Quickshell.env("ANGELOS_SETTINGS_OLD") !== "1" && Config.settingsUi.skin !== "goldengate" && !(Angel.demon && HellLook.settingsPick !== "")
    LazyLoader {
        id: settingsLoader
        activeAsync: (settingsKeep.alive || Shell.settingsWarm) && !root.settingsOverDesk
        SettingsWindow {}
    }
    LazyLoader {
        id: settingsOverlayLoader
        activeAsync: (settingsKeep.alive || Shell.settingsWarm) && root.settingsOverDesk
        SettingsOverlay {}
    }
    // the other Settings windows (Shell.newSettingsWindow): each goes as soon as it is closed
    Instantiator {
        model: Shell.settingsMore
        delegate: SettingsWindow {
            id: more
            required property int key
            required property string page
            required property string sub
            nav: SettingsNav {
                settingsPage: more.page
                Component.onCompleted: settingsSub = more.sub
                onSettingsOpenChanged: if (!settingsOpen)
                    Qt.callLater(Shell.closeSettingsWindow, more.key)
            }
        }
    }

    // the game's debug panel: the author's only, its window comes with owner/debug
    // (services/GameDebug; no source, nothing looked for, in a public install)
    LazyLoader {
        source: GameDebug.windowUrl
        active: GameDebug.shown
    }

    // the live wallpaper's scene editor (modules/sceneeditor, services/SceneEditor)
    LazyLoader {
        source: SceneEditor.windowUrl
        active: SceneEditor.shown
    }

    // the Angel's diary (services/Diary): its closing swing plays inside the window
    Linger {
        id: diaryKeep
        when: Shell.diaryOpen
        ms: 8000
    }
    LazyLoader {
        active: diaryKeep.alive
        DiaryBook {}
    }

    // the mini-game «Смерть на смене» (services/Reaper): the Halo's button «Смерть»
    LazyLoader {
        active: Reaper.open
        ReaperWindow {}
    }
}
