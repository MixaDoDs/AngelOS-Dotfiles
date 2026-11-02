pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// A layered pixel-art scene (scene.json, schema angelos.layered-scene.v1): full-canvas layers
// in z order, a soft parallax from the pointer, a puppet warp for plants (root pinned), frame
// sequences (the CRT), slow clouds and a rare window glint. The picture is a pure function of
// `time` and the camera, so it can be paused, stepped frame by frame and compared. Texels stay
// sharp at any offset: each layer samples its texture nearest, at screen resolution.
Item {
    id: root

    property string dir                       // the scene's folder (scene.json, logical/)
    property real time: 0                     // seconds
    property point pointer: Qt.point(0, 0)    // -1..1 on each axis; the camera eases to it
    property real strength: 1                 // 0..1, scales every movement
    property bool still: false                // the neutral frame: the exact reference, nothing moves
    // the wind (services/SceneWind gives the hour's, the machine's seed and the events' gusts);
    // the scene adds its own gusts, seeded, as a function of `time`
    property real wind: 0.35
    property real windDir: 1
    property real pulse: 0
    property real kick: 0                     // 0..1: the music's last kick, its waves ring out (WallpaperView); 0 = off
    // the last four kicks, each its own wave (kickNow): a wave rings 1.2 s and the kicks come every
    // half second, so a new one rings out over the ones before instead of cutting them short.
    // Per kick: its `time`, how loud, how hard its bass hit (the CRT's flare), the song's first
    // kicks ring harder (services/Bass)
    property vector4d kicksAt: Qt.vector4d(-9, -9, -9, -9)
    property vector4d kicksGain: Qt.vector4d(0, 0, 0, 0)
    property vector4d kicksPunch: Qt.vector4d(0, 0, 0, 0)
    property vector4d kicksHype: Qt.vector4d(0, 0, 0, 0)
    // each its own place (art px) and speed: the CRT's kicks ring out of it, a modifier's out of
    // the place it was given; the widgets feel only the ones that say so
    property vector4d kicksX: Qt.vector4d(0, 0, 0, 0)
    property vector4d kicksY: Qt.vector4d(0, 0, 0, 0)
    property vector4d kicksRate: Qt.vector4d(1, 1, 1, 1)
    property vector4d kicksOnWidgets: Qt.vector4d(0, 0, 0, 0)
    property int kickSlot: 0
    function slotOf(v, i, x) {
        return Qt.vector4d(i === 0 ? x : v.x, i === 1 ? x : v.y, i === 2 ? x : v.z, i === 3 ? x : v.w);
    }
    function ringNow(from, gain, punch, hype, rate, widgets) {
        const i = kickSlot;
        kicksAt = slotOf(kicksAt, i, time);
        kicksGain = slotOf(kicksGain, i, gain);
        kicksPunch = slotOf(kicksPunch, i, punch);
        kicksHype = slotOf(kicksHype, i, hype);
        kicksX = slotOf(kicksX, i, from.x);
        kicksY = slotOf(kicksY, i, from.y);
        kicksRate = slotOf(kicksRate, i, rate);
        kicksOnWidgets = slotOf(kicksOnWidgets, i, widgets ? gain : 0);
        kickSlot = (i + 1) % 4;
    }
    function kickNow(gain, punch, hype) {
        ringNow(kickFrom, gain, punch, hype, 1, true);
    }

    // ---- the wallpaper editor's modifiers (scene.json "modifiers", modules/wallstudio) ----
    // {id, type: "bulge" | "wave", source: "kick" | "snare" | "hat", strength 0..1, on,
    //  threshold 0..1 (a softer hit does nothing), even (every hit alike), and by type
    //  bulge: center [x, y], radius [rx, ry] art px, release s; wave: center, or zone (a bulge's id),
    //  speed (1 = as the CRT's), widgets (false: they stay still)}
    property var mods: []
    property var modsOverride: null           // the editor's own while it is being changed
    property bool modsOn: false               // the host hears the music (widgets/SceneDrums)
    property real modsGain: 1                 // Settings → Wallpaper: all of it, softer
    readonly property var modifiers: (modsOverride || mods).filter(m => m.on !== false)
    readonly property var zoneMods: modifiers.filter(m => m.type === "bulge").slice(0, 4)
    readonly property bool hasWaves: modifiers.some(m => m.type === "wave")
    // false: only what the modifiers say, none of the effects a scene has by itself
    readonly property bool builtin: !scene || scene.builtin !== false
    property vector4d zonesAt: Qt.vector4d(-9, -9, -9, -9)
    property vector4d zonesGain: Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d zonesRelease: {
        const r = i => zoneMods[i] ? zoneMods[i].release || 0.18 : 0.18;
        return Qt.vector4d(r(0), r(1), r(2), r(3));
    }
    function zoneRect(i) {
        const m = zoneMods[i];
        if (!m)
            return Qt.vector4d(-9, -9, 1, 1);
        return Qt.vector4d(ox + (m.center[0] + panShift.x) * k, oy + (m.center[1] + panShift.y) * k, m.radius[0] * k, m.radius[1] * k);
    }
    readonly property vector4d zoneA: zoneRect(0)
    readonly property vector4d zoneB: zoneRect(1)
    readonly property vector4d zoneC: zoneRect(2)
    readonly property vector4d zoneD: zoneRect(3)
    function modCenter(m) {
        const z = m.zone ? zoneMods.find(b => b.id === m.zone) : null;
        const c = z ? z.center : m.center || [cw / 2, ch / 2];
        return Qt.point(c[0], c[1]);
    }
    // a hit of the music: how loud it plays, how hard the hit (punch), the song's first ones (hype)
    function drum(source, gain, punch, hype) {
        const hit = gain * (1 + 0.6 * punch + 0.6 * hype);
        for (const m of modifiers) {
            if (m.source !== source || (!m.even && hit < (m.threshold || 0)))
                continue;
            const g = (m.strength === undefined ? 0.6 : m.strength) * modsGain * (m.even ? 1 : hit);
            if (m.type === "wave")
                ringNow(modCenter(m), g * 1.6, punch, hype, m.speed || 1, m.widgets !== false);
            else if (m.type === "bulge") {
                const i = zoneMods.indexOf(m);
                zonesAt = slotOf(zonesAt, i, time);
                zonesGain = slotOf(zonesGain, i, g * 0.4);
            }
        }
    }
    // what the editor's brush pinned: nothing moves there. Any picture when there is none
    property int holdRev: 0
    readonly property string holdFile: scene && scene.modifier_hold ? dir + "/" + scene.modifier_hold : ""
    readonly property Image holdImage: holdImg
    readonly property bool holdReady: holdFile !== "" && holdImg.status === Image.Ready
    Image {
        id: holdImg
        source: root.holdFile ? "file://" + root.holdFile + "?" + root.holdRev : "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='1' height='1'/>"
        cache: false
        smooth: true
        visible: false
    }
    property real snare: 0                    // 0..1: the last snare, the CRT loses its signal (shaders/scene_layer)
    property real snareAt: -1
    property real edge: 0                     // 0..1: the last snare, red and blue part at the screen's edges (shaders/scene_kick)
    property real breath: 0                   // 0..1: the bass now, the lens at the edges follows it (shaders/scene_kick)
    property bool breathOn: false             // listening to it: the widgets' layer stays on through its quiet moments
    property real hat: 0                      // 0..1: the last hi-hat, a scanline lights on the CRT (shaders/scene_layer)
    property real hatAt: -1
    property real hatSeed: 0
    // it rings out of the CRT's screen (the music plays there); a scene without one: its middle
    readonly property point kickFrom: {
        const s = (scene && scene.layers || []).find(l => l.role === "screen" && l.bounds_logical);
        return s ? Qt.point((s.bounds_logical[0] + s.bounds_logical[2]) / 2, (s.bounds_logical[1] + s.bounds_logical[3]) / 2) : Qt.point(cw / 2, ch / 2);
    }
    property real seed: 0.5

    property var scene: null

    // the night (scene.json "night", scripts/scene-night.py: every layer recoloured, the event's
    // light and sprites): how far into it, 0..1 — the host's clock or the wallpaper's own pick —
    // and the night's event, seconds from its moment (the impact; NaN = none now). Both plain
    // properties, so a check can step through the night frame by frame
    property real nightMix: 0
    // the dusk or the dawn under the night (scripts/scene-twilight.py, scene.json "twilight"):
    // day → twilight by twilightMix, then → night by nightMix; which one, by twilightKind
    property real twilightMix: 0
    property string twilightKind: "dusk"
    readonly property var twilightInfo: scene && scene.twilight && scene.twilight[twilightKind] ? scene.twilight[twilightKind] : null
    property real eventAge: NaN
    // the meteor's colour tonight (Wallpapers.nightVariant): 0 its own fire, else one of `fires`
    // [deep, mid, hot] — the sprites, its light on the walls and the shards it leaves take it
    property int variant: 0
    readonly property var fires: [null, ["#3a0612", "#d8203c", "#ffd6c8"], ["#04281c", "#20d880", "#e2ffe8"], ["#081440", "#3c8cff", "#eaf4ff"], ["#220838", "#a446ff", "#f6e2ff"], ["#3c2204", "#ffb424", "#fffbe6"]]
    readonly property var fire: fires[variant] || null
    // the same three for what burns in any colour (the blast, the shards): its own fire's tonight
    readonly property var flame: fire || ["#8a1a0c", "#ff8a1e", "#fff0b0"]
    readonly property var nightInfo: scene && scene.night ? scene.night : null
    readonly property var nightEventInfo: nightInfo && nightInfo.event ? nightInfo.event : null
    // the event moves, so not on a still wallpaper; and only as dark as the night is
    readonly property bool eventOn: nightEventInfo !== null && moving && nightMix > 0 && isFinite(eventAge)
    function smooth(x) {
        x = Math.max(0, Math.min(1, x));
        return x * x * (3 - 2 * x);
    }
    // 40 minutes coming near — a cold spark for half an hour, its warm light on the walls only in
    // the last ten minutes (sooner, four in the morning looked like a sunset) — the impact behind
    // the left house: a flash over everything, a ball of fire that swells in a second or two and
    // then slowly grows on, the light dying down over the next 15 minutes
    readonly property real approach: eventOn && eventAge < 0 ? smooth((eventAge + 2400) / 2400) : 0
    readonly property real flash: !eventOn || eventAge < 0 ? 0 : eventAge < 0.08 ? 1 : Math.exp(-(eventAge - 0.08) / 0.45)
    readonly property real fireRise: eventOn && eventAge >= 0 ? 0.7 * (1 - Math.exp(-eventAge / 0.8)) + 0.3 * smooth(eventAge / (nightEventInfo.fire.rise || 120)) : 0
    readonly property real fireFade: eventOn && eventAge >= 0 ? 1 - smooth((eventAge - 100) / 360) : 0
    readonly property real glowNear: !eventOn ? 0 : nightMix * (eventAge < 0 ? smooth((eventAge + 600) / 600) : 1 - smooth((eventAge - 250) / 720))
    readonly property real glowBlast: !eventOn ? 0 : nightMix * Math.max(flash, Math.min(0.75, fireRise * fireFade * (nightEventInfo.fire.scale || 0.65)))
    // the blast's wave: out of the fire's foot at `shockSpeed` art px a second, bending all it passes
    // (WallpaperView: shaders/scene_kick), throwing the plants away from the fire as it reaches them
    // (shaders/scene_layer); after it a strong wind for some seconds
    readonly property real shockSpeed: 420
    readonly property real shockAge: eventOn && eventAge >= 0 && eventAge < 25 ? eventAge : -1
    readonly property point shockFrom: nightEventInfo ? Qt.point(nightEventInfo.fire.origin[0], nightEventInfo.fire.origin[1]) : Qt.point(0, 0)
    // the CRT is hit when the wave reaches it, keeps flickering for a while
    // and keeps twitching now and then for hours after, less and less often
    readonly property real screenHit: Math.max(!eventOn || eventAge < 0.3 ? 0 : smooth((eventAge - 0.3) / 0.15) * (1 - 0.6 * smooth((eventAge - 0.8) / 2)) * (1 - smooth((eventAge - 10) / 4)), aftershock)
    readonly property real aftershock: !afterOn || afterAge < 40 ? 0 : hash(Math.floor(time / 9) * 1.7 + 0.3) < 0.3 * Math.exp(-afterAge / 7200) && time % 9 < 0.4 ? 0.4 : 0
    readonly property color nearColor: fire ? fire[1] : nightInfo && nightInfo.approach_color ? Qt.rgba(...nightInfo.approach_color, 1) : "black"
    readonly property color blastColor: fire ? fire[1] : nightInfo && nightInfo.blast_color ? Qt.rgba(...nightInfo.blast_color, 1) : "black"
    // after the impact, day or night (widgets/SceneAftermath): smoke, shards, ash
    readonly property bool afterOn: nightEventInfo !== null && moving && isFinite(eventAge) && eventAge >= 0
    readonly property real afterAge: afterOn ? eventAge : -1
    SceneAftermath {
        wall: root
    }
    // the palette colour (night's at night) of about this lightness (0..1) and no more colourful
    function paletteNear(lum, sat) {
        let best = Qt.rgba(0.5, 0.5, 0.5, 1), bd = 9;
        for (const c of palette) {
            const q = Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1);
            const d = Math.abs(0.3 * q.r + 0.59 * q.g + 0.11 * q.b - lum) + (q.hslSaturation > sat ? 1 : 0);
            if (d < bd) {
                bd = d;
                best = q;
            }
        }
        return best;
    }
    // where the light lands (r: the meteor's, g: the blast's), broad: read between its texels
    readonly property Image lightImage: lightImg
    readonly property bool lightReady: lightImg.status === Image.Ready
    Image {
        id: lightImg
        source: root.nightInfo && root.nightInfo.light ? "file://" + root.dir + "/logical/" + root.nightInfo.light : ""
        smooth: true
        visible: false
    }
    SceneEvent {
        wall: root
    }
    readonly property int cw: scene ? scene.logical_canvas.width : 1
    readonly property int ch: scene ? scene.logical_canvas.height : 1
    // art drawn past the edges for the movement to reveal: the view is the canvas inset by it
    // (656×376 → 640×360, ×3 on 1080p)
    readonly property int margin: 8
    // cover the screen with the view; a scale within 2 % of a whole number snaps to it (even art pixels)
    readonly property real k: {
        const c = Math.max(width / (cw - 2 * margin), height / (ch - 2 * margin));
        return Math.abs(c - Math.round(c)) < 0.02 * c ? Math.round(c) : c;
    }
    readonly property real ox: Math.round((width - cw * k) / 2)
    readonly property real oy: Math.round((height - ch * k) / 2)
    readonly property bool moving: !still && strength > 0
    // how far the free end of the nearest plant bends in a wind of 1, art px; where and how far
    // each spot bends is the scene's one field (scripts/scene-hold.py: roots, things holding
    // plants, the far trees hardly). Twice this and more cut the art into strips
    readonly property real bend: 1.2
    // the plants' nearest parallax (scene-hold.py's NEAR, and the pack's [3, 1]): the field
    // scales it down for the farther ones
    readonly property point plantDepth: Qt.point(3, 1)

    // the camera follows the pointer with the pack's smoothing, stepped by `time` (not a timer):
    // a stepped clock gives the same frames every run
    property point camera: Qt.point(0, 0)
    // it is the camera that moves, not the things: the whole picture drifts a little against the
    // pointer (pan, art px), the nearer layers a hair more (their parallax × depthGain — the pack's
    // amplitudes were ten times too much: barely, but you can tell)
    readonly property real pan: 1
    readonly property real depthGain: 0.1
    readonly property point panShift: moving ? Qt.point(-camera.x * pan * strength, -camera.y * pan * strength) : Qt.point(0, 0)
    property real lastTime: 0
    onTimeChanged: {
        const dt = Math.max(0, time - lastTime);
        lastTime = time;
        const s = scene && scene.camera && scene.camera.smoothing_seconds !== undefined ? scene.camera.smoothing_seconds : 0.35;
        const a = s > 0 ? 1 - Math.exp(-dt / s) : 1;
        camera = Qt.point(camera.x + (pointer.x - camera.x) * a, camera.y + (pointer.y - camera.y) * a);
    }

    function hash(n) {
        const x = Math.sin(n * 127.1 + seed * 311.7) * 43758.5453;
        return x - Math.floor(x);
    }
    function noise(x) {
        const i = Math.floor(x), f = x - i, s = f * f * (3 - 2 * f);
        return hash(i) * (1 - s) + hash(i + 1) * s;
    }
    // a gust every so often, a few seconds long, at this machine's own moments
    function gust(t) {
        const n = noise(t * 0.12 + seed * 100);
        const g = Math.max(0, Math.min(1, (n - 0.55) / 0.35));
        return g * g * (3 - 2 * g);
    }
    function windAt(t) {
        return Math.min(1.6, wind * (0.55 + 0.9 * gust(t)) + pulse + blastGust);
    }
    // the wind behind the blast's wave: strong for a few seconds, gusting, dying down
    readonly property real blastGust: !eventOn || eventAge < 0 || eventAge > 12 ? 0 : 1.6 * smooth((eventAge - 0.3) / 0.3) * (1 - smooth((eventAge - 1.5) / 9)) * (0.75 + 0.25 * Math.sin(eventAge * 2.7))
    readonly property real windNow: moving ? windAt(time) : 0

    // scene.layers plus the window glints as a layer of their own, sorted by z
    readonly property var layers: {
        if (!scene)
            return [];
        // a layer attached to another (the CRT's screen to its body) moves with it
        const byId = {};
        for (const l of scene.layers)
            byId[l.id] = l;
        const all = scene.layers.filter(l => l.visible !== false).map(l => Object.assign({}, l, {
                "frames": (l.animation && l.animation.frames) || [l.file]
            }, l.attach_to_layer && byId[l.attach_to_layer] ? {
                "parallax_max_logical": byId[l.attach_to_layer].parallax_max_logical
            } : {}));
        const w = scene.effects && scene.effects.windows;
        if (w) {
            const host = scene.layers.find(l => l.id === w.attach_to_layer);
            all.push({
                "id": "windows",
                "frames": w.frames,
                "z": w.z,
                "parallax_max_logical": host ? host.parallax_max_logical : [0, 0],
                "bounds_logical": host ? host.bounds_logical : null,
                "edge_mode": "transparent",
                "animation": {
                    "type": "glint"
                }
            });
        }
        return all.sort((a, b) => a.z - b.z);
    }

    // what stands between the layers, Apple's depth effect: the host puts it into `depth`; the
    // scene says where (scene.json "depth_text": {"z", "rect": [x, y, w, h] art px, and only to
    // fix them "color", "shadow"}),
    // nearer layers cover it. A scene without depth_text has no place for it
    readonly property var depthText: !scene || !scene.depth_text ? null : nightMix >= 0.5 && nightInfo && nightInfo.depth_text ? Object.assign({}, scene.depth_text, nightInfo.depth_text) : scene.depth_text
    property alias depth: depthSlot.data
    // the layer the depth text takes its grain from, and where (depth_text "texture_layer",
    // "texture_from" [x, y]; else the bottom layer under the text itself)
    readonly property string depthTexture: {
        if (!depthText || !scene)
            return "";
        const l = scene.layers.find(l => l.id === depthText.texture_layer) || scene.layers.slice().sort((a, b) => a.z - b.z)[0];
        return l ? "file://" + dir + "/logical/" + l.file : "";
    }
    // the whole scene at rest, for the depth text to mirror (chrome)
    readonly property string depthReflection: scene && scene.neutral_pose ? "file://" + dir + "/" + scene.neutral_pose.reference : ""
    readonly property point depthTextureFrom: depthText ? Qt.point(...(depthText.texture_from || depthText.rect.slice(0, 2))) : Qt.point(0, 0)
    Item {
        id: depthSlot
        readonly property var r: root.depthText ? root.depthText.rect : [0, 0, 0, 0]
        visible: root.depthText !== null
        z: root.depthText ? root.depthText.z : 0
        x: root.ox + (r[0] + root.panShift.x) * root.k
        y: root.oy + (r[1] + root.panShift.y) * root.k
        width: r[2] * root.k
        height: r[3] * root.k
    }

    // the scene's palette (palette.json "rgb") and how light what stands behind the depth text is
    // (mean relative luminance 0..1, -1 = not yet): the depth text picks its colours from them.
    // At night the night's own (scene.json "night" → "palette"): the day's bright colours glared
    // as neon on the night, and leaves the wind tore off came down in the sun's green
    // With a dusk and a dawn (scene.json "twilight" → "aligned": each day colour's own at dusk, at
    // dawn and at night, in the day's order) the palette flows with the hour, colour for colour:
    // the depth text, the leaves and the shards no longer jump at the middle of the change
    property var dayPalette: []
    property var nightPalette: []
    readonly property var aligned: scene && scene.twilight && scene.twilight.aligned ? scene.twilight.aligned : null
    readonly property var palette: {
        const al = aligned;
        if (!al || !al.day || !al.night || !(nightMix > 0 || twilightMix > 0))
            return nightMix >= 0.5 && nightPalette.length ? nightPalette : dayPalette.length ? dayPalette : al ? al.day : [];
        const tw = al[twilightKind] || al.day;
        const n = nightMix, t = twilightMix;
        return al.day.map((c, i) => [0, 1, 2].map(j => Math.round((c[j] + (tw[i][j] - c[j]) * t) * (1 - n) + al.night[i][j] * n)));
    }
    // how light what stands behind the depth text is, flowing with the night as the palette does
    readonly property real depthBackdrop: {
        const d = depthLuma < 0 ? 0.5 : depthLuma;
        return depthLumaNight >= 0 ? d + (depthLumaNight - d) * nightMix : d;
    }
    // the night has its own place for the depth text: around the middle of the change it fades
    // out at one and in at the other instead of jumping
    readonly property real depthFade: nightInfo && nightInfo.depth_text && nightMix > 0 && nightMix < 1 ? smooth(Math.abs(nightMix - 0.5) / 0.1) : 1
    property real depthLuma: -1
    // the same behind the night's layers (a scene with a night): dark digits on the day's sky
    // would be lost in the night's
    property real depthLumaNight: -1
    // how far each spot of the plants bends, one field for the scene (scripts/scene-hold.py, cached)
    property string flexPath: ""
    onDirChanged: {
        mods = [];
        sceneText = "";
        dayPalette = [];
        nightPalette = [];
        depthLuma = -1;
        depthLumaNight = -1;
        flexPath = "";
        nearPath = "";
        near = null;
    }

    // ---- the desktop widgets between the layers (Background: WidgetDepth, SceneFront) ----
    // which layer is the nearest at each art pixel (scripts/scene-depth.py, cached):
    // {w, h, z: the distinct z, near: one char a pixel, "0" + 1 + the index of its z, "0" for nothing}
    property string nearPath: ""
    property var near: null
    Process {
        running: root.scene !== null && root.dir !== "" && root.nearPath === ""
        command: ["python3", Quickshell.shellDir + "/scripts/scene-depth.py", root.dir, (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/angelos/scene-depth"]
        stdout: StdioCollector {
            onStreamFinished: root.nearPath = text.trim() || "none"
        }
    }
    FileView {
        path: root.nearPath && root.nearPath !== "none" ? root.nearPath : ""
        onLoaded: root.near = JSON.parse(text())
    }
    // the depth for a widget on the screen (r, in this item's px): the deepest at which the
    // nearer layers cover no more than `cover` of it, just in front of a layer's z; Infinity
    // (in front of it all) without a map
    function planeFor(r, cover) {
        const c = coverShares(r);
        if (!c)
            return Infinity;
        for (let i = 0; i < c.length; i++)
            if (c[i] <= cover)
                return near.z[i] + 0.5;
        return Infinity;
    }
    // how much of it (0..1) the nearer layers cover at a depth
    function coverAt(r, plane) {
        const c = coverShares(r);
        if (!c)
            return 0;
        const i = near.z.findIndex(z => z > plane);
        return i < 0 ? 0 : i === 0 ? 1 : c[i - 1];
    }
    // c[i]: the share of r whose nearest layer is nearer than z[i]; null without a map
    function coverShares(r) {
        const d = near;
        if (!d || r.width <= 0 || r.height <= 0)
            return null;
        const x0 = Math.max(0, Math.floor((r.x - ox) / k)), x1 = Math.min(d.w, Math.ceil((r.x + r.width - ox) / k));
        const y0 = Math.max(0, Math.floor((r.y - oy) / k)), y1 = Math.min(d.h, Math.ceil((r.y + r.height - oy) / k));
        if (x1 <= x0 || y1 <= y0)
            return null;
        const hist = new Array(d.z.length + 2).fill(0);
        for (let y = y0; y < y1; y++)
            for (let x = x0, i = y * d.w + x0; x < x1; x++, i++)
                hist[d.near.charCodeAt(i) - 48]++;
        const total = (x1 - x0) * (y1 - y0), c = [];
        let above = 0;
        for (let i = d.z.length; i >= 1; i--) {
            c[i - 1] = above / total;
            above += hist[i];
        }
        return c;
    }
    // the scene's things and plants a widget there (r, this item's px) can stand behind, the
    // nearest first: the layers whose own pixels reach into it, by their names (label_ru), once
    function layersAt(r) {
        const d = near;
        if (!d || !scene)
            return [];
        const x0 = Math.max(0, Math.floor((r.x - ox) / k)), x1 = Math.min(d.w, Math.ceil((r.x + r.width - ox) / k));
        const y0 = Math.max(0, Math.floor((r.y - oy) / k)), y1 = Math.min(d.h, Math.ceil((r.y + r.height - oy) / k));
        const seen = {};
        for (let y = y0; y < y1; y++)
            for (let x = x0, i = y * d.w + x0; x < x1; x++, i++)
                seen[d.near.charCodeAt(i) - 48] = true;
        const zs = Object.keys(seen).map(i => d.z[i - 1]).filter(z => z !== undefined);
        const names = {};
        return scene.layers.filter(l => l.visible !== false && (l.role === "object" || l.role === "vegetation") && zs.includes(l.z)).sort((a, b) => b.z - a.z).filter(l => {
            const n = l.label_ru || l.id;
            return names[n] ? false : (names[n] = true);
        });
    }
    // how far a thing at that depth moves with the camera, screen px: as the layer behind it
    function shiftAt(plane) {
        if (!moving)
            return Qt.point(0, 0);
        const behind = layers.filter(l => l.z < plane && !(l.animation && l.animation.type === "cloud_drift")).pop();
        const par = behind && behind.parallax_max_logical || [0, 0];
        return Qt.point((panShift.x - camera.x * par[0] * depthGain * strength) * k, (panShift.y - camera.y * par[1] * depthGain * strength) * k);
    }
    Process {
        running: root.scene !== null && root.dir !== "" && root.flexPath === ""
        command: ["python3", Quickshell.shellDir + "/scripts/scene-hold.py", root.dir, (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/angelos/scene-hold"]
        stdout: StdioCollector {
            onStreamFinished: root.flexPath = text.trim() || "none"
        }
    }
    // smooth: the field is read between its texels, so it has no steps
    readonly property Image flexImage: flexImg
    Image {
        id: flexImg
        source: root.flexPath && root.flexPath !== "none" ? "file://" + root.flexPath : ""
        smooth: true
        visible: false
    }
    // plants keep still until the field is there
    readonly property bool flexReady: flexImg.status === Image.Ready
    FileView {
        path: root.scene && root.scene.palette ? root.dir + "/" + root.scene.palette.file : ""
        onLoaded: root.dayPalette = JSON.parse(text()).rgb || []
    }
    FileView {
        path: root.nightInfo && root.nightInfo.palette ? root.dir + "/logical/" + root.nightInfo.palette : ""
        onLoaded: root.nightPalette = JSON.parse(text()).rgb || []
    }
    // the layers behind the depth text, drawn once off to the side and read back in its rect
    Loader {
        active: root.depthText !== null && root.depthLuma < 0
        sourceComponent: LumaBehind {
            rect: root.scene.depth_text.rect
            urls: root.scene.layers.filter(l => l.visible !== false && l.z < root.depthText.z).sort((a, b) => a.z - b.z).map(l => "file://" + root.dir + "/logical/" + l.file)
            onMeasured: l => root.depthLuma = l
        }
    }
    Loader {
        active: root.depthText !== null && root.nightInfo !== null && root.depthLumaNight < 0
        sourceComponent: LumaBehind {
            rect: (root.nightInfo.depth_text || root.scene.depth_text).rect
            urls: root.scene.layers.filter(l => l.visible !== false && l.z < root.depthText.z).sort((a, b) => a.z - b.z).map(l => "file://" + root.dir + "/logical/" + ((root.nightInfo.keep || []).includes(l.id) ? "" : root.nightInfo.layers) + l.file)
            onMeasured: l => root.depthLumaNight = l
        }
    }
    component LumaBehind: Canvas {
        id: behind
        required property var urls
        required property var rect
        signal measured(real luma)
        x: -width
        width: root.cw
        height: root.ch
        opacity: 0
        Component.onCompleted: urls.forEach(u => loadImage(u))
        onImageLoaded: if (urls.every(u => isImageLoaded(u)))
            requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            urls.forEach(u => ctx.drawImage(u, 0, 0));
            const r = behind.rect;
            const d = ctx.getImageData(r[0], r[1], r[2], r[3]).data;
            const lin = c => (c /= 255) <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
            let sum = 0, n = 0;
            for (let i = 0; i < d.length; i += 4)
                if (d[i + 3] > 0) {
                    sum += 0.2126 * lin(d[i]) + 0.7152 * lin(d[i + 1]) + 0.0722 * lin(d[i + 2]);
                    n++;
                }
            behind.measured(n ? sum / n : 0.5);
        }
    }

    // what the wind tears off: leaves from the trees, petals from the flowers, fluff from the grass,
    // pixels of the palette; more of them in a gust. Each is a function of `time`: a slot with its
    // own cycle, alive for a cycle when the wind at its start says so. A layer with "shed": false
    // loses nothing (a curtain, plants in a room); "shed_z" puts what it loses at that depth
    // (leaves from outside behind the room's walls, seen only through its windows)
    readonly property var emitters: {
        if (!scene)
            return [];
        return layers.filter(l => l.animation && l.animation.type === "wind" && l.shed !== false).map(l => {
            const b = l.bounds_logical || [0, 0, cw, ch];
            const kind = /flower/.test(l.id) ? "petal" : /grass/.test(l.id) ? "fluff" : "leaf";
            const par = l.parallax_max_logical || [0, 0];
            return {
                "b": b,
                "kind": kind,
                "near": Math.abs(par[0]) >= 2,
                "z": l.shed_z !== undefined ? l.shed_z : Math.abs(par[0]) >= 2 ? 95 : 79,
                "weight": (b[2] - b[0]) * (b[3] - b[1]) * (Math.abs(par[0]) >= 2 ? 1 : 0.4) * (kind === "leaf" ? 1 : 0.6)
            };
        });
    }
    readonly property var tints: {
        const cols = palette.map(c => Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1));
        const lum = c => 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
        const pick = (f, n) => cols.filter(f).sort((a, b) => b.hslSaturation - a.hslSaturation).slice(0, n);
        // leaves are yellow-green to green, never the CRT's teal
        const leaf = pick(c => c.hslHue >= 0.14 && c.hslHue <= 0.36 && c.hslSaturation > 0.2 && lum(c) > 0.3 && lum(c) < 0.85, 4);
        const petal = pick(c => c.r > c.g + 0.08 && c.r > c.b && lum(c) > 0.35, 3);
        const light = cols.slice().sort((a, b) => lum(b) - lum(a)).slice(0, 2);
        return {
            "leaf": leaf.length ? leaf : light,
            "petal": petal.length ? petal : light,
            "fluff": light.length ? light : ["#ffffff"]
        };
    }
    Repeater {
        model: root.moving && root.emitters.length > 0 && root.palette.length > 0 ? 36 : 0

        Rectangle {
            id: bit
            required property int index
            readonly property real t: root.time
            readonly property real life: 5 + 7 * root.hash(index * 13.1 + 1)
            readonly property real c: (t + root.hash(index * 7.7 + 2) * life) / life
            readonly property int cycle: Math.floor(c)
            readonly property real u: c - cycle
            readonly property real born: t - u * life
            function h(n) {
                return root.hash(index * 31.7 + cycle * 3.3 + n);
            }
            readonly property var e: {
                const total = root.emitters.reduce((a, x) => a + x.weight, 0);
                let r = h(1) * total;
                for (const x of root.emitters)
                    if ((r -= x.weight) <= 0)
                        return x;
                return root.emitters[0];
            }
            readonly property bool alive: h(2) < 0.08 + 0.6 * Math.min(1, root.windAt(born)) + 0.6 * root.pulse
            readonly property real ax: e.b[0] + h(3) * (e.b[2] - e.b[0])
                + root.windDir * (12 + 60 * root.wind) * u * life / 6 + 3 * Math.sin(u * life * 2.1 + index)
                + root.panShift.x - root.camera.x * (e.near ? 3 : 1) * root.depthGain * root.strength
            readonly property real fall: e.kind === "fluff" ? -1 + 4 * h(4) : e.kind === "petal" ? 4 + 4 * h(4) : 6 + 8 * h(4)
            readonly property real ay: e.b[1] + (e.b[3] - e.b[1]) * (0.2 + 0.6 * h(5)) + fall * u * life + 1.5 * Math.sin(u * life * 3.3 + index)
            // a leaf tumbles: its light and dark side, wide and narrow
            readonly property bool flip: Math.sin(u * life * 5 + index) > 0
            readonly property var tint: root.tints[e.kind]
            visible: alive && ax >= 0 && ax < root.cw && ay >= 0 && ay < root.ch
            z: e.z
            x: Math.round(root.ox + ax * root.k)
            y: Math.round(root.oy + ay * root.k)
            // art px: a near leaf 3×2 ⇄ 2×3, a far one 2×1, a petal 2×1 ⇄ 1×2, fluff 1×1
            width: root.k * (e.kind === "leaf" ? (e.near ? (flip ? 3 : 2) : 2) : e.kind === "petal" ? (flip ? 2 : 1) : 1)
            height: root.k * (e.kind === "leaf" ? (e.near ? (flip ? 2 : 3) : 1) : e.kind === "petal" ? (flip ? 1 : 2) : 1)
            color: tint[(flip ? 0 : 1) % tint.length]
        }
    }

    // the night's stars (scene.json "night" → "stars", scripts/scene-night.py): single art pixels
    // in the open sky, behind the clouds and everything standing; each comes out at its own depth
    // of the dusk, so they light one by one, and now and then one dims for a moment
    readonly property var stars: nightInfo && nightInfo.stars ? nightInfo.stars : null
    Repeater {
        model: root.stars && root.nightMix > 0 ? root.stars.at : []

        Rectangle {
            required property var modelData
            required property int index
            readonly property bool bright: modelData[2] === 1
            readonly property int beat: Math.floor(root.time / 2.5)
            readonly property bool dim: root.moving && root.hash(index * 17.3 + beat * 5.1) < (bright ? 0.12 : 0.06)
            visible: root.nightMix >= modelData[3]
            z: root.stars.z
            x: Math.round(root.ox + (modelData[0] + root.panShift.x) * root.k)
            y: Math.round(root.oy + (modelData[1] + root.panShift.y) * root.k)
            width: Math.round(root.k)
            height: Math.round(root.k)
            color: Qt.rgba(...(bright && !dim ? root.stars.bright : root.stars.faint).map(v => v / 255), 1)
            opacity: !bright && dim ? 0 : 1
        }
    }

    // false: a change in the file waits for reloadScene (a screen on the stream)
    property bool follow: true
    function reloadScene() {
        sceneFile.reload();
    }
    // a change of the modifiers alone leaves the layers as they are, they would load anew
    property string sceneText: ""
    FileView {
        id: sceneFile
        path: root.dir ? root.dir + "/scene.json" : ""
        watchChanges: root.follow
        onFileChanged: reload()
        onLoaded: {
            const s = JSON.parse(text());
            root.mods = s.modifiers || [];
            root.holdRev++;
            delete s.modifiers;
            const t = JSON.stringify(s);
            if (t !== root.sceneText) {
                root.sceneText = t;
                root.scene = s;
            }
        }
        onLoadFailed: console.warn("SceneWall: no scene.json in", root.dir)
    }

    Repeater {
        model: root.layers

        SceneLayer {
            wall: root
        }
    }
}
