pragma Singleton

import QtQuick
import Quickshell

// Mission Control (Mod+W, `angelos open mission`, modules/mission): the windows of the focused
// monitor's desk laid out side by side, its desks in a strip on top. Open on one screen at a time.
Singleton {
    id: root

    property bool shown: false
    property string screenName: ""
    // asked to close: the window plays its way out, then calls close()
    property bool leaveAsked: false
    function open() {
        screenName = Niri.focusedOutput || "";
        leaveAsked = false;
        shown = true;
    }
    function close() {
        shown = false;
        leaveAsked = false;
    }
    function toggle() {
        if (shown)
            leaveAsked = true;
        else
            open();
    }
}
