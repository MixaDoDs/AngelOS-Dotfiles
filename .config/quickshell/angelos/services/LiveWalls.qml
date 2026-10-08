pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Half-alive wallpapers (Settings → Wallpaper → Alive): what in a picture may move a little,
// found once per picture by scripts/live-wall.py (a mask + a few facts, cached in
// ~/.cache/angelos/live-wall) and drawn by widgets/LiveWall. A night sky gets
// twinkling and falling stars, water ripples and shimmers (and mirrors the sky's stars when
// it shows the scene upside down), the picture's own lights twinkle.
// Per picture the finding can be corrected: Config.wallpaper.liveOverrides[path] =
// {sky: "auto"|"on"|"off", water: "auto"|"on"|"off", axis: 0..1 (the waterline)}.
// `angelos liveWall status|on|off|analyze`
Singleton {
    id: root

    property var found: ({})            // path -> the script's JSON ({error} when it failed)
    property var queue: []
    property string busy: ""
    property int version: 0

    readonly property bool on: Config.wallpaper.live && !Motion.still

    // what is known about a picture: null while it is being looked at
    function info(path) {
        version;
        return path ? found[path] || null : null;
    }
    function request(path, force) {
        if (!path || (!force && (found[path] || queue.includes(path) || busy === path)))
            return;
        queue = queue.concat([force ? "!" + path : path]);
        _next();
    }
    function reanalyze(path) {
        const m = Object.assign({}, found);
        delete m[path];
        found = m;
        version++;
        request(path, true);
    }
    function _next() {
        if (runner.running || queue.length === 0)
            return;
        const item = queue[0];
        queue = queue.slice(1);
        const force = item.startsWith("!");
        busy = force ? item.slice(1) : item;
        runner.command = ["python3", Quickshell.shellDir + "/scripts/live-wall.py", busy, "--cache", Config.cacheDir + "/live-wall"].concat(force ? ["--force"] : []);
        runner.running = true;
    }
    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                let j = null;
                try {
                    j = JSON.parse(text.trim().split("\n").pop());
                } catch (e) {
                    j = {
                        "error": "no answer"
                    };
                }
                const m = Object.assign({}, root.found);
                m[root.busy] = j;
                root.found = m;
                root.version++;
            }
        }
        onExited: {
            root.busy = "";
            Qt.callLater(root._next);
        }
    }

    // ---- per picture: the finding, corrected by hand ----
    function override(path) {
        return (Config.wallpaper.liveOverrides || {})[path] || {};
    }
    function setOverride(path, key, value) {
        const all = Object.assign({}, Config.wallpaper.liveOverrides || {});
        const o = Object.assign({}, all[path] || {});
        if (value === "auto" || value === undefined || value === null)
            delete o[key];
        else
            o[key] = value;
        if (Object.keys(o).length)
            all[path] = o;
        else
            delete all[path];
        Config.wallpaper.liveOverrides = all;
    }
    // what the shader is given: {skyMode, waterMode, axis, mirror, night, alive}
    function effective(path) {
        const i = info(path);
        if (!i || i.error)
            return null;
        const o = override(path);
        const sky = o.sky || "auto", water = o.water || "auto";
        const axis = o.axis !== undefined ? o.axis : (i.water && i.water.axis !== null && i.water.axis !== undefined ? i.water.axis : 0.65);
        const hasSky = sky === "on" || (sky === "auto" && i.sky && i.sky.found);
        const hasWater = water === "on" || (water === "auto" && i.water && i.water.found);
        const night = sky === "on" ? Math.max(0.8, i.sky ? i.sky.night : 0) : (i.sky ? i.sky.night : 0);
        return {
            "skyMode": sky === "on" ? 1 : sky === "off" ? 2 : 0,
            "waterMode": water === "on" ? 1 : water === "off" ? 2 : 0,
            "axis": axis,
            "mirror": hasWater && (water === "on" || (i.water && i.water.mirror)),
            "night": hasSky ? night : 0,
            "sky": hasSky,
            "water": hasWater,
            "lights": i.lights || 0,
            "glints": hasWater ? i.glints || 0 : 0,
            "alive": (hasSky && night >= 0.3) || hasWater || (i.lights || 0) > 0
        };
    }
    // one line for Settings and `angelos liveWall status`
    function describe(path) {
        const i = info(path);
        if (!path)
            return I18n.t("Обоев нет", "No wallpaper");
        if (!i)
            return I18n.t("Смотрю на картинку…", "Looking at the picture…");
        if (i.error)
            return I18n.t("Не получилось прочитать картинку", "Couldn't read the picture");
        const e = effective(path);
        const parts = [];
        if (e.sky)
            parts.push(e.night >= 0.3 ? I18n.t("ночное небо", "a night sky") : I18n.t("небо (днём звёзд нет)", "a sky (no stars by day)"));
        if (e.water)
            parts.push(e.mirror ? I18n.t("вода с отражением", "water with a reflection") : I18n.t("вода", "water"));
        if (e.lights)
            parts.push(I18n.t("огоньков: ", "lights: ") + e.lights);
        if (e.glints)
            parts.push(I18n.t("бликов на воде: ", "glints on the water: ") + e.glints);
        return parts.length ? parts.join(" · ") : I18n.t("ничего живого не нашлось", "nothing alive found");
    }
}
