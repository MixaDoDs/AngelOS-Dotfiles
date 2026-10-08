import QtQuick
import QtQml.Models
import Quickshell
import qs.services
import qs.widgets
import qs.modules.chest
import qs.modules.clipboard
import qs.modules.diary
import qs.modules.launcher
import qs.modules.laptop
import qs.modules.session
import qs.modules.settings

// Windows that are closed most of the time: each is built when it opens and kept a
// little after it closes (Linger: a quick reopen keeps its state), then it goes with
// everything it held. A closed launcher, clipboard, session menu or Settings holds no memory.
Scope {
    Linger {
        id: launcherKeep
        when: Shell.launcherOpen
    }
    LazyLoader {
        active: launcherKeep.alive
        Launcher {}
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
        id: projectKeep
        when: Shell.projectOpen
    }
    LazyLoader {
        active: projectKeep.alive
        ProjectMenu {}
    }

    // a minute: back/forward history lives in the window
    Linger {
        id: settingsKeep
        when: Shell.settingsOpen
        ms: 60000
    }
    // …and once the shell has settled it is built ahead and kept, hidden — its frame, the
    // navigation, Home, the search with its index, the look in use — so it opens at once
    // (the pages one goes on to come and go: SettingsView). Not during the boot screen, the
    // first-run wizard or a stream (the build is a second of CPU); asked again until it fits.
    Timer {
        id: settingsWarm
        interval: 8000
        running: !Shell.settingsWarm && Quickshell.env("ANGELOS_SETTINGS_WARM") !== "0"   // 0: never (to compare)
        repeat: true
        onTriggered: {
            if (Shell.bootOpen || Shell.bootCover || Shell.setupOpen || StreamMode.active)
                return;
            if (!Shell.settingsOpen) {
                Shell.settingsPage = "main";     // what opening without a page shows
                Shell.settingsSub = "";
            }
            Shell.settingsWarm = true;
        }
    }
    LazyLoader {
        active: settingsKeep.alive || Shell.settingsWarm
        SettingsWindow {}
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
}
