pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The live wallpaper's scene editor, for everyone: a window of the shell where the layers of a
// picture are painted (what is sky, water, a waterfall …: what moves there), effects are switched
// off and the places of the rare events are put. The scene goes next to the picture
// (<name>.scene.json), or — for a picture angelOS ships or a folder that isn't the user's — into
// ~/.local/share/angelos/scenes (scripts/scene-editor/scene_core.py; live-wall.py reads both).
//   window   modules/sceneeditor/SceneEditorWindow.qml (modules/LazyWindows), while `shown`
//   server   scripts/scene-editor/scene-editor.py (the window starts it)
//   picture  what to open in it ("" — the picture on the focused screen)
// The author's own extra: the «Claude» tab, requests handed to Claude over MCP
// (owner/scene-editor/scene-mcp.py) — only where that is (`claude`).
// `angelos scene edit [picture]`, «Пуск» → «Редактор живых обоев…», Settings → Wallpaper → Alive,
// Dotfiles → «Анимация…» next to a release's picture.
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir + "/scripts/scene-editor"
    readonly property string windowUrl: "file://" + Quickshell.shellDir + "/modules/sceneeditor/SceneEditorWindow.qml"
    readonly property bool hasWindow: true
    readonly property bool allowed: true
    // Claude's tab: the author's MCP server is there
    property bool claude: false
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

    // look again for the author's MCP server (after the author's tools were fetched)
    function probe() {
        mcpProbe.running = false;
        mcpProbe.running = true;
    }
    Process {
        id: mcpProbe
        running: true
        command: ["test", "-f", Owner.dir + "/scene-editor/scene-mcp.py"]
        onExited: code => root.claude = code === 0 && (Owner.enabled || Shell.dev)
    }
    Connections {
        target: Owner
        function onRefreshed() {
            root.probe();
        }
        function onHasDirChanged() {
            root.probe();
        }
        function onEnabledChanged() {
            root.probe();
        }
    }
}
