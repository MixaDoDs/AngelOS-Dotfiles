pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for services/StreamMode: the shell's state (CircleLink).
Singleton {
    readonly property bool onAir: CircleLink.onAir
    readonly property bool active: CircleLink.streamActive
}
