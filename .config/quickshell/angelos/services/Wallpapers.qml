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
// One wallpaper may come in several files (day / night, 21:9, 32:9, 9:16 …): a pick stores any
// of them, and every screen shows the one that fits the theme and its shape (pick).
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

    // what was picked for the screen's workspace (any file of the wallpaper) …
    function raw(output, idx) {
        const w = shown;
        const p = (w.workspaces || {})[key(output, idx)] || (w.outputs || {})[output] || w.fallback || (shown === Config.wallpaper ? (releaseWall() || images[0]) : "") || "";
        return Config.expand(p);
    }
    // … and the file of it the screen shows
    function resolve(output, idx) {
        return pick(raw(output, idx), output);
    }

    // ---- one wallpaper in several files (scripts/wall-meta.py) ----
    // ozero.png, ozero-night.png, ozero-21x9.png, ozero-9x16.png … (or Ozero/day.png, Ozero/night.png)
    // are one wallpaper: the settings and the wizard show it once, the shape is read from the files
    property var meta: ({})                  // path -> {w, h, time: day | night | "", key, name}
    readonly property bool variantsOn: Config.wallpaper.variants !== false
    readonly property var heavenSets: _group(images, meta)
    readonly property var hellSets: _group(hellImages, meta)
    // the wallpapers to offer: one entry per wallpaper (every file when variants are off)
    readonly property var heads: variantsOn ? (hellOn ? hellSets : heavenSets).heads : list
    function _group(paths, m) {
        const byKey = {}, heads = [], members = {};
        for (const p of paths) {
            const k = (m[p] || {}).key || p;
            if (!byKey[k]) {
                byKey[k] = [];
                heads.push(p);
            }
            byKey[k].push(p);
        }
        for (const k in byKey)
            if (byKey[k].length > 1)
                for (const p of byKey[k])
                    members[p] = byKey[k];
        return {
            "heads": heads,
            "members": members
        };
    }
    function members(path) {
        return variantsOn ? heavenSets.members[path] || hellSets.members[path] || [path] : [path];
    }
    function sameSet(a, b) {
        return a === b || (!!a && !!b && members(a).includes(b));
    }
    function nameOf(path) {
        const i = meta[path];
        return members(path).length > 1 && i && i.name ? i.name : path.slice(path.lastIndexOf("/") + 1).replace(/\.[a-z0-9]+$/i, "");
    }
    // the screen as it stands now (turned on its side it is tall): its width / height
    function aspectOf(output) {
        const s = Quickshell.screens.find(x => x.name === output);
        return s && s.width > 0 && s.height > 0 ? s.width / s.height : 16 / 9;
    }
    function ratioLabel(w, h) {
        if (!w || !h)
            return "";
        const r = w / h;
        const known = [[16, 9], [16, 10], [21, 9], [32, 9], [48, 9], [4, 3], [5, 4], [3, 2], [1, 1], [9, 16], [10, 16], [9, 21], [3, 4]];
        const k = known.find(x => Math.abs(x[0] / x[1] / r - 1) < 0.04);
        return k ? k[0] + ":" + k[1] : r >= 1 ? r.toFixed(2) + ":1" : "1:" + (1 / r).toFixed(2);
    }
    // what a wallpaper has: [{time, ratio}] of its files, for the little marks under a picture
    function variantTags(path) {
        const all = members(path);
        if (all.length < 2)
            return [];
        const times = new Set(), ratios = [];
        for (const p of all) {
            const i = meta[p] || {};
            if (i.time)
                times.add(i.time);
            const r = ratioLabel(i.w, i.h);
            if (r && !ratios.includes(r))
                ratios.push(r);
        }
        // a file with no time mark is the day one when a night one is there
        if (times.has("night") && all.some(p => !(meta[p] || {}).time))
            times.add("day");
        const out = [];
        if (times.has("day"))
            out.push("☼");
        if (times.has("night"))
            out.push("☾");
        return out.concat(ratios.length > 1 ? ratios : []);
    }
    // the file of a wallpaper for a screen of this shape in this theme: the shape counts most
    // (a tall screen takes the tall day picture over a wide night one), then day or night
    function pickFor(path, aspect, dark) {
        const all = members(path);
        if (all.length < 2)
            return path;
        let best = path, bestScore = 1e9;
        for (const p of all) {
            const i = meta[p] || {};
            const shape = i.w > 0 && i.h > 0 ? Math.abs(Math.log(i.w / i.h / aspect)) : 0.5;
            const time = !i.time ? 0.1 : (i.time === "night") === dark ? 0 : 0.5;
            if (shape + time < bestScore - 1e-6) {
                best = p;
                bestScore = shape + time;
            }
        }
        return best;
    }
    function pick(path, output) {
        return path ? pickFor(path, aspectOf(output), Theme.dark) : path;
    }
    Process {
        id: metaReader
        property var paths: []
        command: ["python3", Quickshell.shellDir + "/scripts/wall-meta.py", "--cache", Config.cacheDir + "/wall-meta.json"]
        stdinEnabled: true
        onStarted: {
            write(paths.join("\n") + "\n");
            stdinEnabled = false;
        }
        onExited: stdinEnabled = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.meta = JSON.parse(text);
                } catch (e) {}
                settle.start();
            }
        }
    }
    Timer {
        id: metaTimer
        interval: 200
        onTriggered: {
            if (metaReader.running)
                return restart();
            metaReader.paths = root.images.concat(root.hellImages);
            metaReader.running = true;
        }
    }
    // the first read only puts the right files up; from then on a swap of files of one
    // wallpaper (day ⇄ night, the screen turned) plays the transition (WallpaperView)
    property bool settled: false
    Timer {
        id: settle
        interval: 1500
        onTriggered: root.settled = true
    }
    onImagesChanged: metaTimer.restart()
    onHellImagesChanged: metaTimer.restart()

    // ---- the wallpapers of angelOS's big releases ----
    // every big release brings its own (drawn by the author): Pictures/AngelOS/NN-name/ with a
    // release.json {number, codename, date, files}, put into ~/Pictures by the installer. A fresh
    // system shows the newest; a system with a picture of its own is asked once per release.
    readonly property string releasesDir: Config.home + "/Pictures/AngelOS"
    property var releases: []          // newest first: {number, codename, date, dir, walls: [{name, day, night}], main}
    readonly property var latestRelease: releases.length ? releases[0] : null
    function releaseWall() {
        return latestRelease ? latestRelease.main : "";
    }
    function releaseLabel(r) {
        return r ? "angelOS " + r.number + (r.codename ? " «" + r.codename + "»" : "") : "";
    }
    function _offerRelease() {
        const r = latestRelease;
        if (!r || r.number <= Config.wallpaper.releaseSeen || hellOn || Shell.setupLocked || Shell.dev || Quickshell.env("ANGELOS_TEST") === "1")
            return;
        Config.wallpaper.releaseSeen = r.number;
        // nothing picked yet: the newest release's picture is already on the screens
        const own = Config.wallpaper.fallback || Object.keys(Config.wallpaper.outputs || {}).length || Object.keys(Config.wallpaper.workspaces || {}).length;
        if (!own || !r.main)
            return;
        releaseNotify.command = ["notify-send", "-a", "angelOS", "-i", "preferences-desktop-wallpaper", "--wait", "-A", "set=" + I18n.t("Поставить", "Set it"), "-A", "open=" + I18n.t("Посмотреть", "Show"), I18n.t("Новые обои: ", "New wallpapers: ") + releaseLabel(r), I18n.t("С этим релизом пришли его обои, сделанные для angelOS (" + r.walls.length + "). Твои обои останутся, пока не поставишь новые.", "This release brought its own wallpapers, made for angelOS (" + r.walls.length + "). Yours stay until you set the new ones.")];
        releaseNotify.running = true;
    }
    Process {
        id: releaseScanner
        command: ["sh", "-c", 'for f in "$1"/*/release.json; do [ -f "$f" ] || continue; printf "%s\t" "${f%/release.json}"; tr -d "\n" < "$f"; echo; done', "sh", root.releasesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const dir = line.slice(0, tab);
                    try {
                        const j = JSON.parse(line.slice(tab + 1));
                        const walls = (j.walls || []).map(w => ({
                                    "name": w.name || "",
                                    "day": w.day ? dir + "/" + w.day : "",
                                    "night": w.night ? dir + "/" + w.night : ""
                                })).filter(w => w.day || w.night);
                        out.push({
                            "number": j.number || 0,
                            "codename": j.codename || "",
                            "date": j.date || "",
                            "dir": dir,
                            "walls": walls,
                            "main": walls.length ? walls[0].day || walls[0].night : ""
                        });
                    } catch (e) {}
                }
                root.releases = out.sort((a, b) => b.number - a.number);
                releaseOffer.restart();
            }
        }
    }
    // settled: Config.ready comes before the settings' values (and the wizard, the demon)
    Timer {
        id: releaseOffer
        interval: 20000
        onTriggered: if (Config.ready)
            root._offerRelease()
    }
    Process {
        id: releaseNotify
        stdout: SplitParser {
            onRead: line => {
                const r = root.latestRelease;
                if (line.trim() === "set" && r)
                    root.setEverywhere(r.main);
                else if (line.trim() === "open")
                    Shell.openSettings("wallpaper");
            }
        }
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
        const images = heads;
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
        const images = heads;
        if (images.length === 0)
            return;
        const cur = raw(output, idx);
        const i = images.findIndex(p => sameSet(p, cur));
        const n = images.length;
        _setLike(output, idx, images[((i < 0 ? -1 : i) + (step || 1) + n) % n]);
    }
    function shuffle(output, idx) {
        const images = heads;
        if (images.length === 0)
            return;
        const cur = raw(output, idx);
        let p = cur;
        for (let k = 0; k < 8 && sameSet(p, cur); k++)
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
        releaseScanner.running = false;
        releaseScanner.running = true;
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
    // walls` puts them into the installed theme (its walls/ is ours, no password); a wallpaper
    // with a tall file gives it to portrait screens even when no screen here stands tall
    function loginWalls() {
        const scr = Quickshell.screens;
        const wide = scr.find(s => s.name === Shell.primaryName && s.width >= s.height) || scr.find(s => s.width >= s.height);
        const tall = scr.find(s => s.height > s.width);
        const w = wide ? resolve(wide.name, 1) : tall ? pickFor(raw(tall.name, 1), 16 / 9, Theme.dark) : "";
        const t = tall ? resolve(tall.name, 1) : wide ? pickFor(raw(wide.name, 1), 9 / 16, Theme.dark) : "";
        return [w || t, t || w];
    }
    readonly property string loginKey: loginWalls().join("\n")
    onLoginKeyChanged: loginSync.restart()
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
