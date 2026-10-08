pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Accent colour from a wallpaper (scripts/wallpaper-color.py). With the
// "From wallpaper" scheme and auto mode on, it follows the wallpaper of the
// palette screen (its active workspace) whenever that picture changes.
Singleton {
    id: root

    property string error: ""
    readonly property bool busy: process.running
    property var cache: ({})          // wallpaper path -> "#rrggbb"
    property string _pending: ""
    property string _running: ""

    readonly property string screenName: Config.appearance.paletteScreen || (Shell.primaryScreen ? Shell.primaryScreen.name : "")
    readonly property var workspace: Niri.activeWorkspace(screenName)
    readonly property string wallpaper: Wallpapers.resolve(screenName, workspace ? workspace.idx : 1)
    // never in hell: there the colours are the circle's (Theme.generated), whatever the picture
    readonly property bool auto: Config.ready && Config.appearance.flavor === "wallpaper" && Config.appearance.autoWallpaperColors && !Wallpapers.hellOn

    onWallpaperChanged: if (auto)
        autoTimer.restart()
    onAutoChanged: if (auto)
        autoTimer.restart()
    Timer {
        id: autoTimer
        interval: 900       // wallpaper transitions and workspace bursts settle first
        onTriggered: if (root.auto && root.wallpaper)
            root.generateFrom(root.wallpaper)
    }

    // "Generate from wallpaper" button: the picture on the focused screen
    function generate() {
        const screen = Niri.focusedOutput || screenName;
        const ws = Niri.activeWorkspace(screen);
        const path = Wallpapers.resolve(screen, ws ? ws.idx : 1);
        if (!path) {
            error = I18n.t("Сначала выбери обои", "Choose a wallpaper first");
            return;
        }
        generateFrom(path, true);
    }
    function generateFrom(path, switchFlavor) {
        error = "";
        if (cache[path]) {
            apply(cache[path], switchFlavor);
            return;
        }
        if (process.running) {
            _pending = path;
            return;
        }
        _running = path;
        _switch = !!switchFlavor;
        process.command = ["python3", Quickshell.shellDir + "/scripts/wallpaper-color.py", Wallpapers.display(path)];
        process.running = true;
    }
    property bool _switch: false
    // heaven's accent only: hell's picture recolours nothing (hell wears its circle's colours)
    function apply(accent, switchFlavor) {
        if (!Wallpapers.hellOn && Config.appearance.customAccent !== accent)
            Config.appearance.customAccent = accent;
        if (switchFlavor)
            Config.appearance.flavor = "wallpaper";
    }

    Process {
        id: process
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!/^#[0-9a-f]{6}$/i.test(result.accent))
                        throw "Invalid color";
                    const c = Object.assign({}, root.cache);
                    if (Object.keys(c).length > 200)
                        for (const k of Object.keys(c).slice(0, 50))
                            delete c[k];
                    c[root._running] = result.accent;
                    root.cache = c;
                    store.setText(JSON.stringify(c));
                    root.apply(result.accent, root._switch);
                } catch (e) {
                    if (!root.error)
                        root.error = String(e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                root.error = text.trim().split("\n").pop()
        }
        onExited: if (root._pending) {
            const next = root._pending;
            root._pending = "";
            Qt.callLater(() => root.generateFrom(next));
        }
    }

    FileView {
        id: store
        path: Config.cacheDir + "/wallpaper-colors.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.cache = JSON.parse(text()) || {};
            } catch (e) {}
        }
    }
}
