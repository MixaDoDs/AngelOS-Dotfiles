pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

// One taskbar per screen. The Golden Gate skin has a menu bar and a Dock of its own instead
// (modules/mac/MacDesktop).
Variants {
    model: GoldenGate.on || Shell.desktopHeld ? [] : Shell.screens.filter(s => !Config.bar.screens || Config.bar.screens.length === 0 || Config.bar.screens.includes(s.name))

    TaskbarWindow {}
}
