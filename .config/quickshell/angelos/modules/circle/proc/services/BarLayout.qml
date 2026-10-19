pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for services/BarLayout: the bar's edge, given with the opening.
Singleton {
    readonly property string edge: CircleLink.barEdge
}
