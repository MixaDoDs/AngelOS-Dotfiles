import QtQuick
import Quickshell
import qs.config
import qs.services

// The Halo (Нимб) on every screen it is on (Settings → Halo; services/Halo).
Variants {
    model: Shell.desktopHeld ? [] : Shell.screens.filter(s => Halo.on(s.name))

    HaloWindow {}
}
