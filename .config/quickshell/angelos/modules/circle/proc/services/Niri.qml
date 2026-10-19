pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for services/Niri: what niri showed on that screen, as the shell
// gave it with the opening (CircleLink); no niri event stream of its own.
Singleton {
    readonly property string focusedOutput: CircleLink.focusedOutput
    readonly property int focusedWindowId: CircleLink.focusedWindowId

    function activeWorkspace(output) {
        return CircleLink.ws;
    }
    function windowsOn(wsId) {
        return CircleLink.windows;
    }
}
