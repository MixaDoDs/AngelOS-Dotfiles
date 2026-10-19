//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import qs.services
import qs.modules.circle

// The screenshot overlay's own process (services/CircleHost starts it through
// scripts/circle-proc.sh): the overlay alone, with a main thread nothing else of the shell shares
// — the bar, the Halo, the wallpapers kept the pointer waiting while picking. It runs from a tree
// of links to the shell's files where the services the overlay touches are stand-ins
// (modules/circle/proc/services, config): they hand saving, the island, Quick Share to the shell
// through CircleLink. This file is that tree's shell.qml.
ShellRoot {
    settings.watchFiles: false

    CircleOverlay {}
    Component.onCompleted: CircleLink.connect()
}
