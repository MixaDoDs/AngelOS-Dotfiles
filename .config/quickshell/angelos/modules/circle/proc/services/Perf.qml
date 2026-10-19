pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for services/Perf: nobody counts this process's windows.
Singleton {
    function addWindow(guard) {
    }
    function dropWindow(guard) {
    }
}
