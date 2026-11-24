import QtQuick
import Quickshell
import qs.services
import qs.widgets

// serp-skin: the skin's windows that live on one screen at a time: the settings window
Scope {
    LazyLoader {
        active: Serp.on && Serp.settingsOpen
        SerpSettings {}
    }
    // the clipboard history (Mod+V…) in the skin's look; angelOS's own steps aside (LazyWindows)
    Linger {
        id: clipKeep
        when: Serp.on && Shell.clipboardOpen
    }
    LazyLoader {
        active: clipKeep.alive
        SerpClipboard {}
    }
}
