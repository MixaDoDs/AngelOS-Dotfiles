pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The wallpaper editor, a window of the shell (modules/wallstudio): a picture, its speakers and how
// they move with the music, all kept in a layered scene's scene.json (widgets/SceneWall).
//   angelos studio [edit [picture or scene folder]] | close | status
//   Settings → Wallpaper → Wallpaper sounds
Singleton {
    id: root

    readonly property string windowUrl: "file://" + Quickshell.shellDir + "/modules/wallstudio/WallStudioWindow.qml"
    property bool open: false
    property string picture: ""
    // a picture asked for while the window is open already
    signal asked(string picture)
    // «На обои»: a screen that waited (it is on the stream) takes the scene's new state
    signal applied(string folder)

    function edit(path) {
        picture = path || "";
        if (open)
            asked(picture);
        open = true;
        return "open " + (picture || "(the wallpaper on the screen)");
    }
    function command(line) {
        const w = line.trim(), cmd = w.split(/\s+/)[0] || "edit";
        if (cmd === "edit")
            return edit(w.slice(4).trim());
        if (cmd === "close") {
            open = false;
            return "closed";
        }
        if (cmd === "status")
            return (open ? "open " : "closed ") + picture;
        return "usage: studio edit [picture] | close | status";
    }
}
