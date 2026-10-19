pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for services/ShotEdit: where the shell will show a saved shot's
// picture, given with the opening (CircleLink).
Singleton {
    function placeOn(name) {
        return CircleLink.land;
    }
}
