pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The live wallpaper's scene editor — the author's only: a window of the shell where the layers
// of a picture are painted (what is sky, water, a waterfall …: what moves there), effects are
// switched off, the places of the rare events are put, and requests are handed to Claude.
// Its code is not here: it lives in owner/scene-editor/ (never published) and comes with the
// author's tools (scripts/author-tools.sh, services/Owner). A public install has no such folder:
// this stub loads nothing and every way in stays shut.
//   window   owner/scene-editor/SceneEditorWindow.qml (modules/LazyWindows), while `shown`
//   picture  what to open in it ("" — the picture on the focused screen)
// `angelos scene edit [picture]`, «Пуск» → «Редактор живых обоев…», Settings → Wallpaper → Alive,
// Dotfiles → «Анимация…» next to a release's picture.
Singleton {
    id: root

    readonly property string dir: Owner.dir + "/scene-editor"
    readonly property string windowUrl: hasWindow ? "file://" + dir + "/SceneEditorWindow.qml" : ""
    property bool hasWindow: false
    readonly property bool allowed: hasWindow && (Owner.enabled || Shell.dev)
    property bool open: false
    readonly property bool shown: open && allowed
    property string picture: ""
    // a picture asked for while the window is open already (the window listens)
    signal asked(string picture)

    function edit(path) {
        if (!allowed)
            return "owner only";
        picture = path || "";
        if (open)
            asked(picture);
        open = true;
        return "open " + (picture || "(the picture on the screen)");
    }
    function close() {
        open = false;
        return "closed";
    }
    onAllowedChanged: if (!allowed)
        open = false

    // `angelos scene …` (modules/Ipc): edit [picture] | close | status
    function command(line: string): string {
        if (!allowed)
            return "owner only";
        const w = line.trim(), cmd = w.split(/\s+/)[0] || "edit";
        if (cmd === "edit")
            return edit(w.slice(4).trim());
        if (cmd === "close")
            return close();
        if (cmd === "status")
            return (open ? "open " : "closed ") + picture;
        return "usage: scene edit [picture] | close | status";
    }

    // look again for owner/scene-editor (after the author's tools were fetched)
    function probe() {
        windowProbe.running = false;
        windowProbe.running = true;
    }
    Process {
        id: windowProbe
        running: true
        command: ["test", "-f", root.dir + "/SceneEditorWindow.qml"]
        onExited: code => root.hasWindow = code === 0
    }
    Connections {
        target: Owner
        function onRefreshed() {
            root.probe();
        }
        function onHasDirChanged() {
            root.probe();
        }
    }
}
