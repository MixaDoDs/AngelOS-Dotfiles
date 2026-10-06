import QtQuick
import QtQml.Models
import Quickshell
import qs.services
import qs.widgets
import qs.modules.clipboard
import qs.modules.debug
import qs.modules.diary
import qs.modules.launcher
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

    // a minute: back/forward history lives in the window
    Linger {
        id: settingsKeep
        when: Shell.settingsOpen
        ms: 60000
    }
    LazyLoader {
        active: settingsKeep.alive
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

    LazyLoader {
        active: GameDebug.shown
        GameDebugWindow {}
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
