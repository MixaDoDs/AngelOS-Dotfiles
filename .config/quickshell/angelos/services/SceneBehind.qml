pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

// Windows behind a layered wallpaper's nearer things (Settings → Wallpaper → Windows behind the
// scene): the floating windows of the apps in Config.wallpaper.behindApps stand in the scene like
// desktop widgets do (WidgetDepth) — by themselves just behind the leaves, deeper, or behind one
// thing of the scene. angel-niri (Niri.nativeMinimize: our fork) draws such a window under the
// bottom layer (set-window-behind-scene) and brings it forward while the pointer is over it, or
// when it is maximized or fullscreen, or in the overview; Background draws the scene's nearer
// layers once more on that layer over each of them (SceneFront), click-through. Stock niri can't:
// nothing happens there.
Singleton {
    id: root

    readonly property bool on: Niri.nativeMinimize
    readonly property var apps: (Config.wallpaper.behindApps || []).filter(a => a && typeof a.id === "string" && a.id !== "")

    function entryFor(appId) {
        const id = String(appId || "").toLowerCase();
        return apps.find(a => a.id.toLowerCase() === id) || null;
    }
    // "" by itself | "deep" | "behind:<layer id>"
    function depthOf(appId) {
        const e = entryFor(appId);
        return e && typeof e.depth === "string" ? e.depth : "";
    }

    // ---- the list (Settings) ----
    function add(appId) {
        const id = String(appId || "").trim();
        if (!id || entryFor(id))
            return;
        Config.wallpaper.behindApps = apps.concat([{
                "id": id,
                "depth": ""
            }]);
    }
    function remove(appId) {
        const id = String(appId || "").toLowerCase();
        Config.wallpaper.behindApps = apps.filter(a => a.id.toLowerCase() !== id);
    }
    function setDepth(appId, depth) {
        const id = String(appId || "").toLowerCase();
        Config.wallpaper.behindApps = apps.map(a => a.id.toLowerCase() === id ? Object.assign({}, a, {
                "depth": depth
            }) : a);
    }
    // the next depth: by itself → deeper → behind each thing of the scene where a window of the
    // app stands now (8 at most) → by itself again
    function nextDepth(appId) {
        const now = depthOf(appId);
        const kinds = ["", "deep"].concat(thingsFor(appId).map(l => "behind:" + l.id));
        const i = kinds.indexOf(now);
        return kinds[(i < 0 ? 0 : i + 1) % kinds.length];
    }
    function depthLabel(appId) {
        const d = depthOf(appId);
        if (d.startsWith("behind:")) {
            const thing = thingsFor(appId).find(l => "behind:" + l.id === d);
            return I18n.t("За: ", "Behind: ") + (thing ? (thing.label_ru || thing.id) : d.slice(7)).toLowerCase();
        }
        return d === "deep" ? I18n.t("Глубже в кадре", "Deeper in the picture") : I18n.t("Сама (чуть за листвой)", "By itself (just behind the leaves)");
    }

    // ---- the scene of each screen (Background registers its SceneWall) ----
    property var walls: ({})        // screen name -> SceneWall item, null for any other wallpaper
    function setWall(screen, wall) {
        if (walls[screen] === wall)
            return;
        const w = Object.assign({}, walls);
        w[screen] = wall;
        walls = w;
    }
    // the scene's things a window of the app stands in front of now (SceneWall.layersAt)
    function thingsFor(appId) {
        for (const w of Niri.windows) {
            if (!entryFor(w.app_id) || entryFor(w.app_id) !== entryFor(appId))
                continue;
            const out = Minimize.outputOf(w);
            const wall = walls[out];
            const r = rectOf(w);
            if (wall && r)
                return wall.layersAt(r).slice(0, 8);
        }
        return [];
    }

    // ---- the windows: where they are on their screen ----
    // a floating window of a listed app on the desktop in front, in its screen's logical px
    function rectOf(w) {
        const l = w ? w.layout : null;
        if (!w || !w.is_floating || w.is_minimized || !l || !l.tile_pos_in_workspace_view || !l.window_size)
            return null;
        const ws = Niri.workspaceById(w.workspace_id);
        if (!ws || !ws.is_active)
            return null;
        const off = l.window_offset_in_tile || [0, 0];
        return Qt.rect(l.tile_pos_in_workspace_view[0] + off[0], l.tile_pos_in_workspace_view[1] + off[1], l.window_size[0], l.window_size[1]);
    }
    // [{id, rect, depth}] on a screen, for Background
    function windowsOn(screen) {
        if (!on)
            return [];
        return Niri.windows.filter(w => !!entryFor(w.app_id) && Minimize.outputOf(w) === screen).map(w => ({
                    "id": w.id,
                    "rect": rectOf(w),
                    "depth": depthOf(w.app_id)
                })).filter(x => !!x.rect);
    }

    // ---- telling niri: the windows of listed apps behind, the others not ----
    property var marked: ({})       // window id -> true: told "behind"
    property bool _swept: false     // once at start: whatever an earlier shell marked is let go
    function sync() {
        if (!on || !Niri.ready)
            return;
        const m = Object.assign({}, marked);
        for (const w of Niri.windows) {
            const want = !!entryFor(w.app_id);
            if (want === !!m[w.id] && _swept)
                continue;
            if (want || m[w.id] || !_swept)
                Niri.action("SetWindowBehindScene", {
                    "id": w.id,
                    "behind": want
                });
            if (want)
                m[w.id] = true;
            else
                delete m[w.id];
        }
        for (const id in m)
            if (!Niri.windows.some(w => String(w.id) === id))
                delete m[id];
        _swept = true;
        marked = m;
    }
    Connections {
        target: Niri
        function onWindowsChanged() {
            syncLater.restart();
        }
        function onReadyChanged() {
            syncLater.restart();
        }
        function onNativeMinimizeChanged() {
            syncLater.restart();
        }
    }
    onAppsChanged: syncLater.restart()
    Timer {
        id: syncLater
        interval: 50
        onTriggered: root.sync()
    }
}
