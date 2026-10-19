pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for services/QuickShare: the shell sends it.
Singleton {
    function share(paths, text) {
        CircleLink.send({
            "t": "share",
            "paths": paths || [],
            "text": text || ""
        });
    }
}
