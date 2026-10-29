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
    property var scenes: ({})                // a layered scene's picture -> its folder (widgets/SceneWall)
    function sceneOf(path) {
        return scenes[path] || "";
    }
    // a scene with a night of its own (scripts/scene-night.py): its folder -> the night's still
    property var nights: ({})
    function nightOf(path) {
        return nights[sceneOf(path)] || "";
    }
    // how far into the night the scene is at `d`, 0..1 (its own pick: Settings → Wallpaper → Time
    // of day). By the clock the evening goes day → dusk 20:00–21:00, dusk → night 21:00–22:00, the
    // morning night → dawn 06:00–07:00, dawn → day 07:00–08:00 (day from 8, the owner)
    function _hour(d) {
        return d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600;
    }
    function _byClock(path) {
        if (!nightOf(path))
            return false;
        if (SceneDebug.hour >= 0)
            return true;
        const mode = own(path, "sceneTime");
        return mode !== "day" && mode !== "night";
    }
    function nightMix(path, d) {
        if (!nightOf(path))
            return 0;
        if (!_byClock(path))
            return own(path, "sceneTime") === "night" ? 1 : 0;
        const h = _hour(SceneDebug.at(d));
        return h >= 12 ? Math.max(0, Math.min(1, h - 21)) : Math.max(0, Math.min(1, 7 - h));
    }
    // the dusk or the dawn under the night at `d`, 0..1 (scripts/scene-twilight.py); none when the
    // time of day is picked by hand or the night is all there is
    function twilightMix(path, d) {
        if (!_byClock(path))
            return 0;
        const h = _hour(SceneDebug.at(d));
        return h >= 12 ? (h >= 22 ? 0 : Math.max(0, Math.min(1, h - 20))) : (h < 6 ? 0 : Math.max(0, Math.min(1, 8 - h)));
    }
    function twilightKind(d) {
        return SceneDebug.at(d).getHours() >= 12 ? "dusk" : "dawn";
    }
    // the night's event (scene.json "night" → "event"): seconds from its moment, 04:00 — it comes
    // near for 40 minutes before, burns for 20 after, and what it left (smoke, shards, ash) fades
    // till 20:00; NaN the rest of the day. The owner may run it by hand (SceneDebug)
    function nightEvent(d) {
        if (SceneDebug.eventOn)
            return SceneDebug.eventAge;
        d = SceneDebug.at(d);
        const at = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 4, 0, 0);
        const s = (d - at) / 1000;
        return s >= SceneDebug.eventStart && s <= SceneDebug.afterEnd ? s : NaN;
    }
    // the meteor's colour tonight (SceneEvent's variants): mostly its own fire, now and then
    // another, seeded by the date so both screens and the sounds agree
    function nightVariant(d) {
        if (SceneDebug.variant >= 0)
            return SceneDebug.variant;
        const n = d.getFullYear() * 400 + d.getMonth() * 32 + d.getDate();
        const h = Math.abs(Math.sin(n * 12.9898) * 43758.5453) % 1;
        return h < 0.5 ? 0 : 1 + Math.floor((h - 0.5) / 0.1);
    }
    // the still a wallpaper shows at `d`: a scene's night's at night, its own picture otherwise
    function still(path, d) {
        const n = nightOf(path);
        return n && nightMix(path, d) >= 0.5 ? n : display(path);
    }
    // some settings belong to the wallpaper, not to the shell (Settings → Wallpaper, while it is shown):
    // its live effects and its scene's text — water that suits one picture may not suit another.
    // A release's wallpapers (Pictures/AngelOS/NN-name/) share theirs, any other picture keeps its
    // own; what a wallpaper has not set is the common Config.wallpaper value
    readonly property var ownKeys: ["liveStrength", "liveStars", "liveMeteors", "liveWater", "liveLights", "liveEvents", "sceneDepth", "sceneDepthStyle", "sceneDepthTexture", "sceneTime", "sceneSounds", "sceneSoundAir", "sceneSoundEvent", "sceneBass"]
    function wallKey(path) {
        const p = sceneOf(path) || origin(path);
        const r = p ? releases.find(r => p === r.dir || p.startsWith(r.dir + "/")) : null;
        return r ? r.dir : p || "";
    }
    // what the settings call it: the release, else the picture
    function wallName(path) {
        const k = wallKey(path);
        const r = releases.find(r => r.dir === k);
        return r ? releaseLabel(r) : nameOf(path);
    }
    function own(path, key) {
        const o = (Config.wallpaper.perWall || {})[wallKey(path)] || {};
        return o[key] !== undefined ? o[key] : Config.wallpaper[key];
    }
    function setOwn(path, key, value) {
        const k = wallKey(path);
        if (!k) {
            Config.wallpaper[key] = value;
            return;
        }
        const all = Object.assign({}, Config.wallpaper.perWall || {});
        all[k] = Object.assign({}, all[k] || {}, {
            [key]: value
        });
        Config.wallpaper.perWall = all;
    }
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
        { "id": "wipe", "label": I18n.t("Шторка", "Wipe"), "hint": I18n.t("шторка слева направо с рваным краем", "A wipe from left to right with a ragged edge") },
        { "id": "verdict", "label": I18n.t("Вердикт", "Verdict"), "hint": I18n.t("театральная врезка как в Persona 5: шторки, полосы, слово, разрез — 0,8 с", "A theatrical cut-in like Persona 5: shutters, stripes, a word, a slice — 0.8 s") },
        // (local patch 56) a scene of its own, not a blink: it brings its own length (ms)
        { "id": "cinema", "label": I18n.t("Кино", "Cinema"), "hint": I18n.t("полосы 21:9 захлопываются, вспышка, новая картинка проявляется, как на загрузке", "21:9 bars slam shut, a flash, the new picture develops like a loading screen"), "ms": 2600 },
        // not the shader's: GateScene over the whole screen, with sound (the shader draws it
        // as "cinema" in the settings' preview and when the scene can't run)
        { "id": "gate", "label": I18n.t("Небесные врата", "Heaven's Gate"), "hint": I18n.t("экран загрузки: врата поверх всего, титульная карта, новые обои проявляются фотографией, со звуком", "A loading screen: the gates over everything, a title card, the new picture develops like a photograph, with sound"), "ms": 2600, "scene": true }
    ]
    function transitionIndex(id) {
        if (id === "random")
            return Math.floor(Math.random() * transitions.length);
        return transitions.findIndex(t => t.id === id);
    }
    function transitionMs(index) {
        const t = transitions[index];
        return t && t.ms ? t.ms : Config.wallpaper.duration;
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
    // … and the file of it the screen shows (its pixel copy when pixel wallpapers are on)
    function resolve(output, idx) {
        return pixel(pick(raw(output, idx), output), output);
    }

    // ---- pixel wallpapers (Settings → Wallpaper → Pixel wallpaper, scripts/wall-pixelate.py) ----
    // Any picture redrawn in big pixels: a copy per screen, made once into the cache at exactly
    // the screen's pixels (every art pixel a whole square), from then on what that screen
    // shows — the desktop, the lock, the login screen, the alive wallpaper (the theme's colours
    // still come from the picture itself: services/PaletteGenerator). Pixel art, and a GIF that
    // moves, stay as they are. Heaven's only: hell's paintings are the circle's.
    readonly property bool pixelOn: Config.wallpaper.pixel && !hellOn
    property var pixeled: ({})         // key (path, screen, the numbers) -> the script's JSON
    property var pixelOrigin: ({})     // a copy -> the picture it was made from
    property string pixelBusy: ""      // the picture being redrawn now
    readonly property var _pix: ({
            "queue": [],                // keys waiting (not a property: asked from bindings)
            "jobs": {},                 // key -> [path, "WxH"]
            "last": {}                  // path + screen -> the copy shown last, while a new one is made
        })
    // the screen's real pixels, "WxH" (a screen that is not there: Full HD)
    function screenPixels(output) {
        const s = Quickshell.screens.find(x => x.name === output);
        if (!s || !(s.width > 0 && s.height > 0))
            return "1920x1080";
        const r = s.devicePixelRatio > 0 ? s.devicePixelRatio : 1;
        return Math.round(s.width * r) + "x" + Math.round(s.height * r);
    }
    function _pixKey(path, wh) {
        return [path, wh, Config.wallpaper.pixelSize, Config.wallpaper.pixelColors, Config.wallpaper.pixelDither].join("|");
    }
    // the picture a file stands for: a pixel copy's original, else the file itself
    function origin(path) {
        return pixelOrigin[path] || path;
    }
    // what the script said about a picture on a screen: null while it is being redrawn
    function pixelInfo(path, output) {
        path = origin(path);
        return path ? pixeled[_pixKey(path, screenPixels(output))] || null : null;
    }
    // low: asked ahead (_pixWarm), after what a screen is waiting for now
    function pixel(path, output, low) {
        if (!pixelOn || !path || !path.startsWith("/"))
            return path;
        const wh = screenPixels(output), k = _pixKey(path, wh);
        const j = pixeled[k];
        if (j)
            return j.out || path;
        if (!_pix.jobs[k]) {
            _pix.jobs[k] = [path, wh];
            if (low)
                _pix.queue.unshift(k);
            else
                _pix.queue.push(k);
            Qt.callLater(root._pixNext);
        }
        // meanwhile: the copy shown so far (a slider was moved); at start-up nothing, so the
        // big original is not read only to be dropped a moment later
        return _pix.last[path + "|" + wh] || (settled ? path : "");
    }
    function _pixNext() {
        if (pixeler.running || _pix.queue.length === 0)
            return;
        // the newest question first: an answer nobody waits for any more can wait
        const k = _pix.queue.pop();
        const job = _pix.jobs[k];
        if (pixeled[k] || !job)
            return Qt.callLater(root._pixNext);
        // asked with numbers that are not the settings' any more (a slider on its way), or
        // the pixels were switched off meanwhile: nobody waits for this one
        if (!pixelOn || k !== _pixKey(job[0], job[1])) {
            delete _pix.jobs[k];
            return Qt.callLater(root._pixNext);
        }
        pixeler.key = k;
        pixeler.said = false;
        pixelBusy = job[0];
        pixeler.command = ["python3", Quickshell.shellDir + "/scripts/wall-pixelate.py", job[0], "--screen", job[1], "--size", String(Config.wallpaper.pixelSize), "--colors", String(Config.wallpaper.pixelColors), "--dither", String(Config.wallpaper.pixelDither), "--cache", Config.cacheDir + "/wall-pixel"];
        pixeler.running = true;
    }
    // The copies a screen will want next are made ahead: every workspace's picture, and its
    // other file for the other theme (day ⇄ night) — so a switch of workspace or theme puts the
    // copy up at once instead of the picture first and its copy a moment later.
    readonly property string _pixWarmKey: pixelOn ? [stateKey, _pixKey("", ""), Quickshell.screens.map(s => s.name + screenPixels(s.name)).join(","), images.length, Object.keys(meta).length].join("|") : ""
    on_PixWarmKeyChanged: if (_pixWarmKey)
        Qt.callLater(root._pixWarm)
    function _pixWarm() {
        if (!pixelOn)
            return;
        for (const s of Quickshell.screens) {
            const idxs = [1];
            for (const k in (shown.workspaces || {})) {
                const at = k.lastIndexOf(":");
                if (k.slice(0, at) === s.name)
                    idxs.push(parseInt(k.slice(at + 1)) || 1);
            }
            for (const i of idxs) {
                const p = raw(s.name, i);
                for (const dark of [Theme.night, !Theme.night])
                    pixel(pickFor(p, aspectOf(s.name), dark), s.name, true);
            }
        }
    }
    function _pixDone(k, j) {
        const job = _pix.jobs[k];
        if (!job)
            return;
        delete _pix.jobs[k];
        if (!j || !j.out)
            j = {
                "out": job[0],
                "error": (j && j.error) || "no answer"
            };
        if (j.out !== job[0]) {
            _pix.last[job[0] + "|" + job[1]] = j.out;
            const o = Object.assign({}, pixelOrigin);
            o[j.out] = job[0];
            pixelOrigin = o;
        }
        const m = Object.assign({}, pixeled);
        m[k] = j;
        pixeled = m;
    }
    Process {
        id: pixeler
        property string key
        property bool said: false
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null;
                try {
                    j = JSON.parse(text.trim().split("\n").pop());
                } catch (e) {}
                pixeler.said = true;
                root._pixDone(pixeler.key, j);
            }
        }
        onExited: {
            // no python, no numpy: the picture as it is
            if (!pixeler.said)
                root._pixDone(pixeler.key, null);
            root.pixelBusy = "";
            Qt.callLater(root._pixNext);
        }
    }

    // ---- one wallpaper in several files (scripts/wall-meta.py) ----
    // ozero.png, ozero-night.png, ozero-21x9.png, ozero-9x16.png … (or Ozero/day.png, Ozero/night.png)
    // are one wallpaper: the settings and the wizard show it once, the shape is read from the files
    // The same picture twice (a copy in another folder, a release's picture shipped again with
    // the next one) is one wallpaper as well: the copy says `dup`, the lists leave it out, and
    // a copy that was picked before still stands for its wallpaper
    property var meta: ({})                  // path -> {w, h, time: day | night | "", key, name, dup?}
    readonly property int copiesHidden: variantsOn ? images.filter(p => (meta[p] || {}).dup && images.includes(meta[p].dup)).length : 0
    readonly property bool variantsOn: Config.wallpaper.variants !== false
    readonly property var heavenSets: _group(images, meta)
    readonly property var hellSets: _group(hellImages, meta)
    // the wallpapers to offer: one entry per wallpaper (every file when variants are off)
    readonly property var heads: variantsOn ? (hellOn ? hellSets : heavenSets).heads : list
    function _group(paths, m) {
        const byKey = {}, heads = [], members = {}, copies = [], here = new Set(paths);
        for (const p of paths) {
            const k = (m[p] || {}).key || p;
            // a copy of a picture that is here too (not of one outside the list)
            if ((m[p] || {}).dup && here.has(m[p].dup)) {
                copies.push(p);
                continue;
            }
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
        for (const p of copies)
            members[p] = members[m[p].dup] || [m[p].dup];
        return {
            "heads": heads,
            "members": members
        };
    }
    function members(path) {
        return variantsOn ? heavenSets.members[path] || hellSets.members[path] || [path] : [path];
    }
    function sameSet(a, b) {
        a = origin(a);
        b = origin(b);
        if (a === b || !a || !b)
            return a === b;
        const other = members(b);
        return members(a).some(p => other.includes(p));
    }
    function nameOf(path) {
        // a scene is called by its folder, not by its reference picture
        const sc = sceneOf(path);
        if (sc)
            return sc.slice(sc.lastIndexOf("/") + 1);
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
        return path ? pickFor(path, aspectOf(output), Theme.night) : path;
    }
    Process {
        id: metaReader
        property var paths: []
        command: ["python3", Quickshell.shellDir + "/scripts/wall-meta.py", "--cache", Config.cacheDir + "/wall-meta.json", "--prefer", root.releasesDir]
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
            // the releases' pictures too: the wallpaper folder may be another one
            const rel = [];
            for (const r of root.releases)
                for (const w of r.walls)
                    for (const f of [w.day, w.night])
                        if (f && !root.images.includes(f))
                            rel.push(f);
            metaReader.paths = root.images.concat(root.hellImages, rel);
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
    onReleasesChanged: metaTimer.restart()

    // ---- the wallpapers of angelOS's big releases ----
    // every big release brings its own (drawn by the author): Pictures/AngelOS/NN-name/ with a
    // release.json {number, codename, date, files}, put into ~/Pictures by the installer. A fresh
    // system shows the newest; a system with a picture of its own is asked once per release.
    readonly property string releasesDir: Config.home + "/Pictures/AngelOS"
    property var releases: []          // newest first: {number, codename, date, dir, walls: [{name, day, night}], main}
    readonly property var latestRelease: releases.length ? releases[0] : null
    // for the lists: a wallpaper shipped again with a later release is shown with that one only
    readonly property var releasesShown: variantsOn ? releases.map(r => Object.assign({}, r, {
                "walls": r.walls.filter(w => !(meta[w.day || w.night] || {}).dup)
            })).filter(r => r.walls.length > 0) : releases
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
        const w = wide ? resolve(wide.name, 1) : tall ? pickFor(raw(tall.name, 1), 16 / 9, Theme.night) : "";
        const t = tall ? resolve(tall.name, 1) : wide ? pickFor(raw(wide.name, 1), 9 / 16, Theme.night) : "";
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
        // then the layered scenes (scripts/scene-list.py): a scene is one wallpaper, its neutral
        // picture in the list, never its layers, masks and frames
        command: ["sh", "-c", 'find -L "$1" -maxdepth 3 -type f "(" -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" ")" -not -path "*/Screenshots/*" -not -path "$2/*"; echo "@scenes"; python3 "$3" "$1" "$4"', "sh", root.heavenDir, root.hellPack, Quickshell.shellDir + "/scripts/scene-list.py", root.releasesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const [files, sc] = text.split("@scenes\n");
                const scenes = {}, nights = {};
                for (const l of (sc || "").split("\n").filter(l => l.includes("\t"))) {
                    const [dir, ref, night] = l.split("\t");
                    scenes[ref] = dir;
                    if (night)
                        nights[dir] = night;
                }
                const dirs = Object.values(scenes);
                root.scenes = scenes;
                root.nights = nights;
                root.images = files.split("\n").filter(l => l !== "" && !dirs.some(d => l.startsWith(d + "/"))).concat(Object.keys(scenes)).sort();
            }
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

    // ---- new pictures: Settings → Wallpaper «Добавить обои…» or a drop from the file manager.
    // Copied into the folder (the same file already there is skipped, another one of that name
    // gets a -2), with a picture's .scene.json (the live wallpaper's hints); then a new scan.
    // The choosers open where the last pick was (scripts/pick-file.py --remember), not in ~ ----
    property string importNote: ""
    readonly property bool importing: importer.running || addPicker.running || dirPicker.running
    function importFiles(paths) {
        paths = (paths || []).filter(f => /\.(png|jpe?g|webp|gif|bmp)$/i.test(f));
        if (paths.length === 0 || importer.running)
            return;
        importNote = "";
        importer.command = ["sh", "-c", 'd="$1"; shift; mkdir -p "$d" || exit 1; n=0; k=0; for f; do [ -f "$f" ] || continue; case "$f" in "$d"/*) k=$((k+1)); continue;; esac; b=$(basename "$f"); t="$d/$b"; if [ -e "$t" ]; then if cmp -s "$f" "$t"; then k=$((k+1)); continue; fi; s="${b%.*}"; e="${b##*.}"; i=2; while [ -e "$d/$s-$i.$e" ]; do i=$((i+1)); done; t="$d/$s-$i.$e"; fi; cp "$f" "$t" && n=$((n+1)); sc="${f%.*}.scene.json"; [ -f "$sc" ] && cp -n "$sc" "${t%.*}.scene.json"; done; echo "$n $k"', "sh", heavenDir].concat(paths);
        importer.running = true;
    }
    function pickToImport() {
        if (!addPicker.running)
            addPicker.running = true;
    }
    function pickDir() {
        if (!dirPicker.running)
            dirPicker.running = true;
    }
    Process {
        id: importer
        stdout: StdioCollector {
            onStreamFinished: {
                const [n, k] = text.trim().split(" ").map(x => parseInt(x) || 0);
                root.importNote = n > 0 ? I18n.t("Добавлено: ", "Added: ") + n + (k ? I18n.t(" (уже были: ", " (already there: ") + k + ")" : "") : k ? I18n.t("Эти обои уже в папке", "These are in the folder already") : I18n.t("Ничего не скопировалось", "Nothing was copied");
                root.scan();
            }
        }
    }
    Process {
        id: addPicker
        command: ["python3", Quickshell.shellDir + "/scripts/pick-file.py", "--multi", "--remember", "wallpaper-add", I18n.t("angelOS — добавить обои", "angelOS — add wallpapers"), I18n.t("Картинки", "Pictures"), "*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp"]
        stdout: StdioCollector {
            onStreamFinished: root.importFiles(text.split("\n").filter(l => l !== ""))
        }
    }
    Process {
        id: dirPicker
        command: ["python3", Quickshell.shellDir + "/scripts/pick-file.py", "--dir", "--start", root.heavenDir, I18n.t("angelOS — папка с обоями", "angelOS — the wallpaper folder")]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim();
                if (d)
                    Config.wallpaper.dir = d.startsWith(Config.home + "/") ? "~" + d.slice(Config.home.length) : d;
            }
        }
    }
}
