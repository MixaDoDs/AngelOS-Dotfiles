pragma Singleton

import QtQuick
import Quickshell

// The overlay process's stand-in for services/Island: the shell opens the island.
Singleton {
    function search(text) {
        CircleLink.send({
            "t": "island",
            "act": "search",
            "arg": text
        });
    }
    function open(url) {
        CircleLink.send({
            "t": "island",
            "act": "open",
            "arg": url
        });
    }
    function lens(png) {
        CircleLink.send({
            "t": "island",
            "act": "lens",
            "arg": png
        });
    }
}
