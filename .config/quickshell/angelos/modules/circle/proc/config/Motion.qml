pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for config/Motion: the shell's level (CircleLink sets it). The
// real one writes Config and runs niri-game-mode.
Singleton {
    property bool calm: false
    property bool still: false
    readonly property string level: still ? "off" : calm ? "calm" : "full"
    function ms(duration) {
        return still ? 0 : duration;
    }
}
