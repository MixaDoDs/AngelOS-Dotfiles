pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "../widgets/Icons.js" as Icons
import "../widgets/StdIcons.js" as Std

// An icon by name, or by the source an app handed over (a notification's, a tray item's): the
// user's icon theme when it can draw it, else a pixel icon of ours for that name
// (widgets/StdIcons.js: the freedesktop names, then words in the name), else the fallback name,
// else "". Qt drew a pink-and-black checkerboard for a name the theme lacks (#47); nothing here
// hands one out, whatever icon theme a user has.
Singleton {
    // a name → an image source
    function url(name, fallback) {
        const n = String(name || "");
        const t = n ? Quickshell.iconPath(n, true) || Quickshell.iconPath(n.toLowerCase(), true) : "";
        return t || pixel(n) || (fallback ? url(fallback) : "");
    }
    // ours alone, in the theme's colours ("" : nothing fits the name)
    function pixel(name) {
        const r = Std.find(name);
        return r ? Icons.svg(r, {
            "#": Theme.hex(Theme.dark ? Theme.text : Theme.edge),
            "o": Theme.hex(Theme.accent),
            "x": Theme.hex(Theme.accent2),
            "y": Theme.hex(Theme.accent3),
            "w": "#ffffff",
            "f": Theme.hex(Theme.dark ? Theme.faceAlt : Theme.sunken),
            "r": Theme.hex(Theme.danger)
        }, false).url : "";
    }
    // a source an app handed over: a path, a URL, image://icon/<name>, or a bare name
    function safe(src, fallback) {
        const s = String(src || "");
        if (!s)
            return fallback ? url(fallback) : "";
        if (s.startsWith("image://icon/"))
            return url(decodeURIComponent(s.slice(13).split("?")[0]), fallback);
        if (s.startsWith("/"))
            return "file://" + s;
        if (s.includes(":"))
            return s;
        return url(s, fallback);
    }
}
