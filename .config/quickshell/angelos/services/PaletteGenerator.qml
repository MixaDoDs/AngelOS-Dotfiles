pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Accent colour from a wallpaper (scripts/wallpaper-color.py). With the
// "From wallpaper" scheme and auto mode on, it follows the wallpaper of the
// palette screen (its active workspace) whenever that picture changes.
// Settings → Appearance → "Where the colour comes from" (Config.appearance.paletteArea): a part of
// the picture only — the sky, the middle, the ground or a rectangle drawn on it — is read by
// Quickshell's ColorQuantizer (median cut, in C++), not by the script.
Singleton {
    id: root

    property string error: ""
    readonly property bool busy: process.running || sizer.running || !!_quant
    property var cache: ({})          // wallpaper path -> "#rrggbb"
    property string _pending: ""
    property string _running: ""

    // the part of the picture the colour comes from: [x, y, w, h] as parts of it, null = all of it
    readonly property var areas: ({
            "sky": [0, 0, 1, 0.4],
            "middle": [0, 0.3, 1, 0.4],
            "ground": [0, 0.6, 1, 0.4]
        })
    function rectOf(area, custom) {
        if (area === "custom") {
            const r = (custom || []).map(Number);
            return r.length === 4 && r.every(v => isFinite(v)) && r[2] > 0.01 && r[3] > 0.01 ? r : null;
        }
        return areas[area] || null;
    }
    readonly property var area: Config.ready ? rectOf(Config.appearance.paletteArea, Config.appearance.paletteRect) : null
    onAreaChanged: if (auto)
        autoTimer.restart()
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
        const rect = area;
        const key = rect ? path + "#" + rect.join(",") : path;
        if (cache[key]) {
            apply(cache[key], switchFlavor);
            return;
        }
        if (busy) {
            _pending = path;
            return;
        }
        _running = key;
        _switch = !!switchFlavor;
        if (rect) {
            _rect = rect;
            _source = Wallpapers.display(path);
            if (sizes[_source])
                quantize();
            else {
                sizer.command = ["python3", "-c", "import sys\nfrom PIL import Image, ImageOps\nwith Image.open(sys.argv[1]) as i:\n    print(*ImageOps.exif_transpose(i).size)", _source];
                sizer.running = true;
            }
            return;
        }
        process.command = ["python3", Quickshell.shellDir + "/scripts/wallpaper-color.py", Wallpapers.display(path)];
        process.running = true;
    }
    property bool _switch: false

    // ---- a part of the picture: ColorQuantizer ----
    property var sizes: ({})          // picture path -> [w, h] in pixels (imageRect is in them)
    property var _rect: null
    property string _source: ""
    property var _quant: null
    function pixelRect(path, rect) {
        const sz = sizes[path];
        if (!sz || !rect)
            return null;
        return Qt.rect(Math.round(rect[0] * sz[0]), Math.round(rect[1] * sz[1]), Math.max(1, Math.round(rect[2] * sz[0])), Math.max(1, Math.round(rect[3] * sz[1])));
    }
    // the accent from quantized colours, scored as wallpaper-color.py scores its own: colourful,
    // neither near black nor near white, and many buckets of the same colour weigh more
    function accentOf(colors) {
        const seen = {};
        const byKey = {};
        for (const c of colors) {
            const k = c.toString();
            seen[k] = (seen[k] || 0) + 1;
            byKey[k] = c;
        }
        let best = null;
        for (const k of Object.keys(seen)) {
            const c = byKey[k];
            const s = c.hsvSaturation, v = c.hsvValue;
            const score = seen[k] * (0.2 + s) * (v > 0.18 && v < 0.95 ? 1 : 0.2);
            if (!best || score > best.score)
                best = {
                    "score": score,
                    "h": Math.max(0, c.hsvHue),
                    "s": Math.max(0.35, s),
                    "v": Math.max(0.6, v)
                };
        }
        if (!best)
            return "";
        return Qt.hsva(best.h, Math.min(best.s, 0.8), Math.min(best.v, 0.9), 1).toString();
    }
    function quantize() {
        const r = pixelRect(_source, _rect);
        if (!r) {
            error = I18n.t("Не удалось прочитать картинку", "Cannot read the picture");
            finished();
            return;
        }
        _quant = quantizer.createObject(root, {
            "imageRect": r,
            "source": "file://" + _source
        });
        quantTimeout.restart();
    }
    function finished() {
        quantTimeout.stop();
        if (_quant) {
            _quant.destroy();
            _quant = null;
        }
        if (_pending) {
            const next = _pending;
            _pending = "";
            Qt.callLater(() => root.generateFrom(next));
        }
    }
    function remember(key, accent) {
        const c = Object.assign({}, cache);
        if (Object.keys(c).length > 200)
            for (const k of Object.keys(c).slice(0, 50))
                delete c[k];
        c[key] = accent;
        cache = c;
        store.write(JSON.stringify(c));
    }
    Component {
        id: quantizer
        ColorQuantizer {
            id: q
            depth: 4            // 16 buckets
            rescaleSize: 128
            onColorsChanged: if (colors.length && root._quant === q) {
                const accent = root.accentOf(colors);
                if (accent) {
                    root.remember(root._running, accent);
                    root.apply(accent, root._switch);
                }
                root.finished();
            }
        }
    }
    Timer {
        id: quantTimeout
        interval: 10000
        onTriggered: {
            root.error = I18n.t("Картинка не прочиталась", "The picture did not load");
            root.finished();
        }
    }
    Process {
        id: sizer
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /^(\d+) (\d+)/.exec(text.trim());
                if (m) {
                    const s = Object.assign({}, root.sizes);
                    s[root._source] = [+m[1], +m[2]];
                    root.sizes = s;
                    root.quantize();
                } else {
                    root.error = I18n.t("Не удалось прочитать картинку", "Cannot read the picture");
                    root.finished();
                }
            }
        }
    }
    // the size of a picture for pixelRect (Settings shows the area's colours live)
    function measure(path) {
        if (!path || sizes[path] || measurer.running)
            return;
        measurer.path = path;
        measurer.command = ["python3", "-c", "import sys\nfrom PIL import Image, ImageOps\nwith Image.open(sys.argv[1]) as i:\n    print(*ImageOps.exif_transpose(i).size)", path];
        measurer.running = true;
    }
    Process {
        id: measurer
        property string path: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /^(\d+) (\d+)/.exec(text.trim());
                if (m) {
                    const s = Object.assign({}, root.sizes);
                    s[measurer.path] = [+m[1], +m[2]];
                    root.sizes = s;
                }
            }
        }
    }
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
                    root.remember(root._running, result.accent);
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

    AsyncFile {
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
