pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for services/Capture: the shell keeps the picture (its folders,
// clipboard, notification, the corner's thumbnail); done(r) once it has.
Singleton {
    signal shotSaved(string path)

    function saveShot(framePath, rect, opts, done) {
        CircleLink.ask({
            "t": "save",
            "frame": framePath,
            "rect": rect || null,
            "opts": opts || {}
        }, done || null);
    }
}
