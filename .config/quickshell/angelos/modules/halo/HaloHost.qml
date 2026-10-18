import QtQuick
import Quickshell
import qs.config
import qs.services

// The Halo (Нимб) on every screen it is on (Settings → Halo; services/Halo).
Variants {
    // made only once the settings are read: a window made with the defaults (the strip on) lost
    // the strip-off that came a moment later, and the strip stayed after a restart (#89)
    model: Shell.desktopHeld || !Config.ready ? [] : Shell.screens.filter(s => Halo.on(s.name))

    HaloWindow {}
}
