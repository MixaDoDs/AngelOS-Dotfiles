pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Resolves which wallpaper a screen shows (per workspace > per output > fallback).
// Heaven and hell have wallpapers of their own (C2): heaven's is Config.wallpaper and is never
// touched while the demon rules; hell's is the player's save (Story.player.hellWall) — the
// circle's painting (services/Angel puts it up), or what the player picked in this circle,
// gone with the next circle. Every setter here writes to the realm that is shown, and in hell
// only hell's pictures are offered.
Singleton {
    id: root

    property var images: []                  // heaven's pictures (Config.wallpaper.dir, not the Hell pack)
    property var hellImages: []              // hell's: the Hell pack, its cache, the drawn hells
    readonly property bool hellOn: Angel.demon
    readonly property var hellWall: Story.player.hellWall || null
    // what the screens show: hell's once it is painted (until then the last picture stays)
    readonly property var shown: hellOn && hellWall ? hellWall : Config.wallpaper
    readonly property string stateKey: JSON.stringify([shown.fallback, shown.outputs, shown.workspaces])
    readonly property var list: hellOn ? hellImages : images
    readonly property string hellPack: Config.home + "/Pictures/Hell"
    readonly property string hellCache: Config.home + "/.local/share/angelos/hell-pack"
    readonly property string hellDrawn: Config.home + "/.local/share/angelos/hell"
    // the paintings are there (installed or fetched once), or only the drawn hells
    readonly property bool hellPackHere: hellImages.some(p => !p.startsWith(hellDrawn + "/"))
    // pixel transitions of shaders/pixel_transition.frag, in shader order
    readonly property var transitions: [
        { "id": "mosaic-dither", "label": I18n.t("Мозаика + дизер", "Mosaic + dither"), "hint": I18n.t("пиксели укрупняются и рассыпаются в новую картинку", "Pixels grow and dither into the new picture") },
        { "id": "mosaic", "label": I18n.t("Мозаика", "Mosaic"), "hint": I18n.t("крупные квадраты, смена посередине", "Big squares, swap in the middle") },
        { "id": "dither", "label": I18n.t("Дизер", "Dither"), "hint": I18n.t("сетка точек, как в старых играх", "A dot grid, like old games") },
        { "id": "heart", "label": I18n.t("Сердечко", "Heart"), "hint": I18n.t("новая картинка раскрывается сердечком из центра", "The new picture opens as a heart from the middle") },
        { "id": "crt", "label": I18n.t("Старый телевизор", "Old TV"), "hint": I18n.t("картинка сжимается в полоску и разворачивается новая", "The picture folds into a line, the new one unfolds") },
        { "id": "blinds", "label": I18n.t("Жалюзи", "Blinds"), "hint": I18n.t("полоски переворачиваются сверху вниз", "Slats turn from top to bottom") },
        { "id": "diamonds", "label": I18n.t("Ромбы", "Diamonds"), "hint": I18n.t("ромбики растут слева направо, как в Win98", "Diamonds grow left to right, like Win98") },
        { "id": "glitch", "label": I18n.t("Глитч", "Glitch"), "hint": I18n.t("полосы дёргаются и расслаиваются по цветам", "Bands jump and split into colours") },
        { "id": "melt", "label": I18n.t("Плавление", "Melt"), "hint": I18n.t("старая картинка стекает столбиками, как в DOOM", "The old picture drips down in columns, like DOOM") },
        { "id": "sparkle", "label": I18n.t("Блёстки", "Sparkles"), "hint": I18n.t("пиксели меняются вразнобой и искрятся", "Pixels flip at random and sparkle") },
        { "id": "wipe", "label": I18n.t("Шторка", "Wipe"), "hint": I18n.t("шторка слева направо с рваным краем", "A wipe from left to right with a ragged edge") }
    ]
    function transitionIndex(id) {
        if (id === "random")
            return Math.floor(Math.random() * transitions.length);
        return transitions.findIndex(t => t.id === id);
    }
    readonly property string dir: hellOn ? hellPack : Config.expand(Config.wallpaper.dir)
    readonly property string heavenDir: Config.expand(Config.wallpaper.dir)

    function key(output, idx) {
        return output + ":" + idx;
    }

    function resolve(output, idx) {
        const w = shown;
        const p = (w.workspaces || {})[key(output, idx)] || (w.outputs || {})[output] || w.fallback || (shown === Config.wallpaper ? images[0] : "") || "";
        return Config.expand(p);
    }

    // a pick in hell: hell's wallpaper for this circle only (the next circle puts its own)
    function _hellEdit(fn) {
        const w = JSON.parse(JSON.stringify(hellWall || {
            "fallback": "",
            "outputs": {},
            "workspaces": {}
        }));
        w.outputs = w.outputs || {};
        w.workspaces = w.workspaces || {};
        fn(w);
        w.circle = Story.circle;
        w.picked = true;
        Story.player.hellWall = w;
    }
    function setForOutput(output, path) {
        Achievements.note("wallpaper.set");
        if (hellOn)
            return _hellEdit(w => path ? w.outputs[output] = path : delete w.outputs[output]);
        Config.setIn(Config.wallpaper, "outputs", output, path);
    }
    function setForWorkspace(output, idx, path) {
        Achievements.note("wallpaper.set");
        if (hellOn)
            return _hellEdit(w => path ? w.workspaces[key(output, idx)] = path : delete w.workspaces[key(output, idx)]);
        Config.setIn(Config.wallpaper, "workspaces", key(output, idx), path);
    }
    function setEverywhere(path) {
        Achievements.note("wallpaper.set");
        if (hellOn)
            return _hellEdit(w => {
                w.fallback = path;
                w.outputs = {};
                w.workspaces = {};
            });
        Config.wallpaper.fallback = path;
        Config.wallpaper.outputs = ({});
        Config.wallpaper.workspaces = ({});
    }
    function random(output) {
        const images = list;
        if (images.length === 0)
            return;
        const p = images[Math.floor(Math.random() * images.length)];
        if (output)
            setForOutput(output, p);
        else
            setEverywhere(p);
    }

    // next / random picture for the screen's current workspace: a workspace that has
    // its own wallpaper gets a new one, otherwise the whole monitor does
    function _setLike(output, idx, path) {
        if ((shown.workspaces || {})[key(output, idx)])
            setForWorkspace(output, idx, path);
        else
            setForOutput(output, path);
    }
    function next(output, idx, step) {
        const images = list;
        if (images.length === 0)
            return;
        const cur = resolve(output, idx);
        const i = images.indexOf(cur);
        const n = images.length;
        _setLike(output, idx, images[((i < 0 ? -1 : i) + (step || 1) + n) % n]);
    }
    function shuffle(output, idx) {
        const images = list;
        if (images.length === 0)
            return;
        const cur = resolve(output, idx);
        let p = cur;
        for (let k = 0; k < 8 && p === cur; k++)
            p = images[Math.floor(Math.random() * images.length)];
        _setLike(output, idx, p);
    }

    // Qt will not decode a picture over 256 MB of pixels (15360×10240 PNG and up),
    // with sourceSize or not. Views report such a failure with fit(); the picture is
    // then shown from a copy that fits a 4K box, made once into the cache.
    property var fitted: ({})          // original path -> fitted copy
    property var fitQueue: []
    property var fitFailed: []
    function display(path) {
        return fitted[path] || path;
    }
    function fit(path) {
        if (!path || !path.startsWith("/") || fitted[path] || fitQueue.includes(path) || fitFailed.includes(path))
            return;
        fitQueue = fitQueue.concat([path]);
        _fitNext();
    }
    function _fitNext() {
        if (fitter.running || fitQueue.length === 0)
            return;
        fitter.source = fitQueue[0];
        fitter.target = Config.cacheDir + "/wallpapers/" + Qt.md5(fitter.source) + ".png";
        fitter.running = true;
    }

    function scan() {
        scanner.running = false;
        scanner.running = true;
        hellScanner.running = false;
        hellScanner.running = true;
    }

    onHeavenDirChanged: scan()
    onHellOnChanged: scan()
    Component.onCompleted: {
        scan();
        loginSync.restart();
    }

    // the login screen (SDDM, extras/sddm) shows these wallpapers too: the landscape
    // screen's on landscape screens, the portrait one's on portrait ones; `angelos sddm
    // walls` puts them into the installed theme (its walls/ is ours, no password)
    function loginWalls() {
        const scr = Quickshell.screens;
        const wide = scr.find(s => s.name === Shell.primaryName && s.width >= s.height) || scr.find(s => s.width >= s.height);
        const tall = scr.find(s => s.height > s.width);
        const w = wide ? resolve(wide.name, 1) : "", t = tall ? resolve(tall.name, 1) : "";
        return [w || t, t || w];
    }
    onStateKeyChanged: loginSync.restart()
    Timer {
        id: loginSync
        interval: 5000
        onTriggered: {
            if (!Config.ready || !Config.lock.sddmWalls || Shell.dev || Quickshell.env("ANGELOS_TEST") === "1")
                return;
            if (loginWallsRun.running) {
                restart();
                return;
            }
            const [w, t] = root.loginWalls();
            if (!w)
                return;
            loginWallsRun.command = ["python3", Quickshell.shellDir + "/scripts/sddm-theme.py", "walls", "--wallpaper", w, "--tall", t];
            loginWallsRun.running = true;
        }
    }
    Process {
        id: loginWallsRun
    }

    // no Hell pack yet: fetch it once (scripts/hell-wallpaper.py downloads the Hell folder of
    // the wallpapers repo into its cache, like the installer would into ~/Pictures/Hell)
    property bool fetching: false
    function fetchHell() {
        if (fetching)
            return;
        fetching = true;
        fetcher.running = true;
    }
    Process {
        id: fetcher
        command: ["python3", Quickshell.shellDir + "/scripts/hell-wallpaper.py", root.hellDrawn, "--pack", root.hellPack, "--cache", root.hellCache, "1920x1080"]
        onExited: {
            root.fetching = false;
            root.scan();
        }
    }

    Process {
        id: fitter
        property string source
        property string target
        // reuse the copy while it is newer than the picture; libvips streams the
        // picture, ImageMagick is the fallback
        command: ["sh", "-c", 'mkdir -p "${2%/*}" && { [ "$2" -nt "$1" ] || if command -v vipsthumbnail >/dev/null; then vipsthumbnail "$1" --size 3840x3840 -o "$2"; else magick "$1" -resize "3840x3840>" "$2"; fi; }', "sh", source, target]
        onExited: code => {
            if (code === 0) {
                const m = Object.assign({}, root.fitted);
                m[source] = target;
                root.fitted = m;
            } else {
                root.fitFailed = root.fitFailed.concat([source]);
            }
            root.fitQueue = root.fitQueue.filter(p => p !== source);
            Qt.callLater(root._fitNext);
        }
    }

    Process {
        id: scanner
        // heaven's pictures: the Hell pack is hell's (C2: no picking the wrong realm by accident)
        command: ["find", "-L", root.heavenDir, "-maxdepth", "3", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", "-o", "-iname", "*.bmp", ")", "-not", "-path", "*/Screenshots/*", "-not", "-path", root.hellPack + "/*"]
        stdout: StdioCollector {
            onStreamFinished: root.images = text.split("\n").filter(l => l !== "").sort()
        }
    }
    Process {
        id: hellScanner
        // the pack (installed, else its fetched copy — the same names), then the drawn hells
        command: ["sh", "-c", 'for d in "$1" "$2"; do ls "$d"/*.png 2>/dev/null && break; done; ls "$3"/hell-*.png 2>/dev/null; true', "sh", root.hellPack, root.hellCache, root.hellDrawn]
        stdout: StdioCollector {
            onStreamFinished: root.hellImages = text.split("\n").filter(l => l !== "")
        }
    }
}
