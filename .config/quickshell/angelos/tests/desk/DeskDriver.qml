pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.desktop
import qs.modules.background

// The desk's one clock (started by tests/desk/run.sh, offscreen): the music spectrum keeps its
// blocks when the levels move, its bars move on DeskClock's tick and not on cava's own
// frames, the clock runs at the scene's rate with a spectrum lifting it to 20, and LiveBeat
// hears the kick in a spectrum's bass instead of starting a cava of its own. And the
// launcher's file thumbnails are what the cache holds, not a guess per size (FileSearch).
Scope {
    id: root

    property int step: 0
    property double since: Date.now()
    function report(name, ok, detail) {
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail === undefined ? "" : detail));
    }
    function next() {
        step++;
        since = Date.now();
    }

    // every object under an item, depth first
    function walk(it, out) {
        for (const c of it.children || []) {
            out.push(c);
            walk(c, out);
        }
        return out;
    }
    function findItem(it, test) {
        if (!it)
            return null;
        if (test(it))
            return it;
        for (const c of it.children || []) {
            const found = findItem(c, test);
            if (found)
                return found;
        }
        return null;
    }
    // the block Rectangles of the first bar (the pixel look): the Column with `rows` children
    function blocks() {
        const col = walk(spec, []).find(o => o.spacing !== undefined && Array.from(o.children || []).filter(c => c.color !== undefined).length === spec.rows);
        return col ? Array.from(col.children).filter(c => c.color !== undefined) : [];
    }
    function lit(list) {
        return list.filter(b => b.visible).length;
    }

    MusicSpectrum {
        id: spec
        screenName: ""
        rows: 7
        face: true
        music: true
        mac: false
        widget: ({
                "uid": "desk-test",
                "settings": {
                    "bars": 4
                }
            })
    }

    property var first: []
    property int ticks: 0
    property var beat: 0
    Connections {
        target: DeskClock
        function onTick() {
            root.ticks++;
        }
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            switch (root.step) {
            case 0:
                if (Date.now() - root.since < 1500)
                    return;
                root.report("desk-spectrum-counted", spec.live && DeskClock.spectra === 1 && LiveBeat.feeders === 1, "live=" + spec.live + " spectra=" + DeskClock.spectra + " feeders=" + LiveBeat.feeders);
                root.report("desk-clock-spectrum-20", DeskClock.fps === 20, "fps=" + DeskClock.fps);
                DeskClock.walls++;
                Config.wallpaper.liveFps = 60;
                root.report("desk-clock-scene-faster", DeskClock.fps === 60, "fps=" + DeskClock.fps);
                Config.wallpaper.liveFps = 12;
                root.report("desk-clock-spectrum-lifts", DeskClock.fps === 20, "fps=" + DeskClock.fps);
                // a laptop's battery (#60): never more than 24, «Monitor» (0) on the clock at 24,
                // and the spectrum doesn't lift it past that
                DeskClock.battery = true;
                Config.wallpaper.liveFps = 60;
                const capped = DeskClock.sceneFps === 24 && DeskClock.fps === 24;
                Config.wallpaper.liveFps = 0;
                const monitor = DeskClock.sceneFps === 24 && DeskClock.fps === 24;
                Config.wallpaper.liveFps = 12;
                const slow = DeskClock.sceneFps === 12 && DeskClock.fps === 20;
                root.report("desk-clock-battery-cap", capped && monitor && slow, "60→" + capped + " monitor→" + monitor + " 12→" + slow);
                DeskClock.battery = false;
                DeskClock.walls--;
                Config.wallpaper.liveFps = 24;
                root.first = root.blocks();
                root.report("desk-blocks-made-once", root.first.length === 7 && root.lit(root.first) === 0, "blocks=" + root.first.length + " lit=" + root.lit(root.first));
                // a frame from cava: waits for the clock
                spec.pending = [1, 0.5, 0.2, 0];
                root.report("desk-levels-wait-for-tick", spec.levels.length === 0, "levels=" + spec.levels);
                root.next();
                break;
            case 1:
                if (spec.pending !== null && Date.now() - root.since < 2000)
                    return;
                root.report("desk-levels-on-tick", spec.pending === null && spec.levels[0] === 1, "levels=" + spec.levels);
                {
                    const now = root.blocks();
                    const same = now.length === root.first.length && now.every((b, i) => b === root.first[i]);
                    root.report("desk-blocks-kept", same && root.lit(now) === 7, "same=" + same + " lit=" + root.lit(now));
                }
                spec.levels = [3 / 7, 0, 0, 0];
                {
                    const now = root.blocks();
                    const same = now.length === root.first.length && now.every((b, i) => b === root.first[i]);
                    // the lit ones are the bottom three, the top one counted as index 0 as before
                    const vis = now.filter(b => b.visible);
                    root.report("desk-blocks-lower", same && vis.length === 3 && now[4].visible && !now[3].visible && vis[0].lit === 0, "same=" + same + " lit=" + vis.length);
                }
                // LiveBeat: a spectrum hears everything, so no cava of its own
                LiveBeat.next(() => root.beat++);
                root.report("desk-beat-no-own-cava", !LiveBeat.listening, "listening=" + LiveBeat.listening);
                for (let i = 0; i < 10; i++)
                    LiveBeat.feed(0.05);
                LiveBeat.feed(0.5);
                root.report("desk-beat-from-spectrum", root.beat === 1, "beats=" + root.beat);
                root.next();
                break;
            case 2:
                // no kick: the waiting one goes anyway after 4 s
                if (Date.now() - root.since < 200)
                    return;
                LiveBeat.next(() => root.beat++);
                root.next();
                break;
            case 3:
                if (root.beat < 2 && Date.now() - root.since < 6000)
                    return;
                root.report("desk-beat-gives-up", root.beat === 2 && !LiveBeat.listening, "beats=" + root.beat);
                spec.destroy();
                root.next();
                break;
            case 4:
                if (Date.now() - root.since < 300)
                    return;
                root.report("desk-spectrum-uncounted", DeskClock.spectra === 0 && LiveBeat.feeders === 0 && DeskClock.fps === 0, "spectra=" + DeskClock.spectra + " feeders=" + LiveBeat.feeders + " fps=" + DeskClock.fps);
                // the launcher's thumbnails: only what the cache holds (run.sh put one in x-large)
                FileSearch.cachedAt = 0;
                FileSearch.listThumbs();
                root.next();
                break;
            case 5:
                if (Object.keys(FileSearch.cached).length === 0 && Date.now() - root.since < 4000)
                    return;
                {
                    const home = Quickshell.env("HOME");
                    const has = FileSearch.thumbs({
                        "path": home + "/docs/has.txt",
                        "kind": "doc"
                    });
                    const none = FileSearch.thumbs({
                        "path": home + "/docs/none.txt",
                        "kind": "doc"
                    });
                    const pic = FileSearch.thumbs({
                        "path": home + "/docs/pic.png",
                        "kind": "image"
                    });
                    root.report("files-thumb-cached", has.length === 1 && has[0].indexOf("/x-large/") > 0, has.join(" "));
                    root.report("files-thumb-no-guess", none.length === 0 && pic.length === 1 && pic[0].endsWith("/docs/pic.png"), none.join(" ") + " | " + pic.join(" "));
                }
                root.next();
                break;
            case 6:
                {
                    // the menus' layouts: the owner's defaults, the limits, what suits each target
                    const d = DeskMenu.layout("desktop");
                    root.report("menu-desktop-defaults", JSON.stringify(d) === JSON.stringify(DeskMenu.defaults.desktop), JSON.stringify(d));
                    root.report("menu-ring-default", JSON.stringify(DeskMenu.ring) === JSON.stringify(DeskMenu.ringDefault) && DeskMenu.ring.length === 8, DeskMenu.ring.join(","));
                    Config.desktop.menuQuick = ["terminal", "files", "minimize", "sep", "terminal", "monitor", "note", "record", "lock", "start"];
                    Config.desktop.menuItems = ["note", "sep", "sep", "kill", "a", "b", "addWidget", "lock", "start", "session", "settings", "launcher", "files", "halo"];
                    const l = DeskMenu.layout("desktop");
                    root.report("menu-limits", l.quick.length === 6 && !l.quick.includes("minimize") && !l.quick.includes("sep") && l.quick.filter(x => x === "terminal").length === 1 && l.items.length === 8 && !l.items.includes("kill"), JSON.stringify(l));
                    root.report("menu-targets-own", DeskMenu.known("minimize", "task") && !DeskMenu.known("minimize", "desktop") && DeskMenu.catalog("panel").includes("autoHide") && !DeskMenu.catalog("widget").includes("terminal"), DeskMenu.catalog("panel").join(","));
                    const m = DeskMenu.menu("panel", {
                        "screen": ""
                    });
                    const last = m.items[m.items.length - 1];
                    root.report("menu-customize-last", m.quick.length === 3 && !!last && !!last.run && m.items[m.items.length - 2].separator === true, JSON.stringify(m.items.map(x => x.label || "—")));
                    DeskMenu.resetLayout("desktop");
                    // an old layout (with the flyouts) starts from the new defaults, the own entries kept
                    Config.desktop.menuCustom = [{
                            "id": "custom:1",
                            "label": "F06",
                            "icon": "heart",
                            "kind": "command",
                            "target": "touch \"$HOME/f06-ran\""
                        }];
                    Config.desktop.menuQuick = ["terminal", "files", "monitor", "wallpaperPick", "settings"];
                    Config.desktop.menuItems = ["view", "new", "wallpaper", "open", "sep", "displaySettings", "personalize", "more", "custom:1"];
                    Config.desktop.menuStyle = "tiles";
                    Config._migrate();
                    root.report("menu-migrated", JSON.stringify(Config.desktop.menuQuick) === JSON.stringify(DeskMenu.defaults.desktop.quick) && JSON.stringify(Config.desktop.menuItems) === JSON.stringify(DeskMenu.defaults.desktop.items.concat(["custom:1"])) && Config.desktop.menuStyle === "list", JSON.stringify(Config.desktop.menuItems) + " " + Config.desktop.menuStyle);
                    deskWin.visible = true;
                }
                root.next();
                break;
            case 7:
                if (Date.now() - root.since < 300)
                    return;
                {
                    // the middle button's ring: eight directions, a flick picks one, let go in the
                    // middle and it stays
                    const r = ringLoader.item;
                    DeskMenu.setRing(6, "custom:1");
                    r.openRing(320, 240);
                    root.report("ring-eight", r.ringMode && r.look === "ring" && r.slots.length === 8 && r.slots[6] === "custom:1", r.slots.join(","));
                    root.report("ring-sectors", r.sector(320, 140) === 0 && r.sector(420, 240) === 2 && r.sector(320, 340) === 4 && r.sector(220, 240) === 6 && r.sector(390, 170) === 1 && r.sector(324, 244) === -1, [r.sector(320, 140), r.sector(420, 240), r.sector(320, 340), r.sector(220, 240), r.sector(390, 170), r.sector(324, 244)].join(","));
                    r.aim(322, 242);
                    r.release(322, 242);
                    root.report("ring-stays-in-middle", r.visible && !r.armed && r.current === -1, "visible=" + r.visible + " armed=" + r.armed);
                    r.close();
                    r.openRing(320, 240);
                    r.aim(250, 238);
                    const aimed = r.current;
                    r.release(200, 240);
                    root.report("ring-flick-runs", aimed === 6 && !r.visible, "aimed=" + aimed + " visible=" + r.visible);
                    // the right-click menu's own looks take the desktop's entries, no ring
                    r.openAt(320, 240);
                    root.report("overlay-desktop-entries", !r.ringMode && r.slots[0] === DeskMenu.layout("desktop").quick[0], r.slots.join(","));
                    r.close();
                    Config.menus.ring = [];
                    deskWin.visible = false;
                }
                root.next();
                break;
            case 8:
                if (Date.now() - root.since < 600)
                    return;
                ranCheck.running = true;
                root.next();
                break;
            case 9:
                if (ranCheck.running || ranCheck.code < 0) {
                    if (Date.now() - root.since < 3000)
                        return;
                }
                root.report("ring-flick-ran-custom", ranCheck.code === 0, "test -e exit " + ranCheck.code);
                console.log("TEST DONE");
                Qt.quit();
                root.next();
                break;
            }
        }
    }

    // the ring's host (modules/background/RadialMenu), in a window shown for its step
    FloatingWindow {
        id: deskWin
        visible: false
        implicitWidth: 640
        implicitHeight: 480
    }
    Loader {
        id: ringLoader
        sourceComponent: RadialMenu {
            parentWindow: deskWin
        }
    }
    Process {
        id: ranCheck
        property int code: -1
        command: ["test", "-e", Quickshell.env("HOME") + "/f06-ran"]
        onExited: c => code = c
    }
}
