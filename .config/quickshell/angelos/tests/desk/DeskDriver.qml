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
    property bool lastMouseRan: false
    property var tilesRan: []
    // the tiles look's «Ещё» with 32 extras in a 640×480 window: the panel stays on the screen,
    // the wheel brings the last tile in and a real click runs it, the keys walk to it and run it
    function checkTiles(scale) {
        const r = ringLoader.item;
        const t = testTiles;
        const n = r.flyItems.length;
        const lastId = "extra:31";
        const panel = t.blurItem;
        const viewport = findItem(panel, it => it.contentY !== undefined && it.contentHeight !== undefined && it.clip);
        // corners in the window / in the viewport (half a pixel for the rounding)
        const onScreen = it => {
            const a = it.mapToItem(null, 0, 0), b = it.mapToItem(null, it.width, it.height);
            return a.x >= -0.5 && a.y >= -0.5 && b.x <= 640.5 && b.y <= 480.5;
        };
        const tileOf = () => findItem(panel, it => it.modelData && it.modelData.id === lastId && it.width > 0);
        const inView = it => {
            const p = it.mapToItem(viewport, 0, 0);
            return p.y >= -0.5 && p.y + it.height <= viewport.height + 0.5;
        };
        root.report("tiles-" + scale + "-panel-on-screen", n >= 30 && onScreen(panel), "items=" + n + " cols=" + t.cols + " panel=" + panel.x + "," + panel.y + " " + panel.width + "×" + panel.height);
        if (!viewport) {
            root.report("tiles-" + scale + "-scrolls", false, "no viewport");
            return;
        }
        // the mouse: the wheel over the tiles to the bottom, then a click where the last tile is
        const ev = Qt.createQmlObject("import QtTest; TestEvent {}", viewport);
        for (let i = 0; i < 60 && viewport.contentY < viewport.contentHeight - viewport.height; i++)
            ev.mouseWheel(viewport, viewport.width / 2, viewport.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
        root.report("tiles-" + scale + "-wheel-scrolls", viewport.contentY > 0 && viewport.contentY + viewport.height >= viewport.contentHeight, "scroll=" + viewport.contentY + " viewport=" + viewport.height + " content=" + viewport.contentHeight);
        let last = tileOf();
        const shown = !!last && onScreen(last) && inView(last);
        root.tilesRan = [];
        if (shown)
            ev.mouseClick(last, last.width / 2, last.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        root.report("tiles-" + scale + "-last-mouse-runs", shown && root.tilesRan.length === 1 && root.tilesRan[0] === 31, "shown=" + shown + " ran=" + root.tilesRan.join(","));
        // the keys: from the first tile (scrolled back up) down and right to the last, Enter runs it
        r.subCurrent = -1;
        t.nav({key: Qt.Key_Right});
        const fromTop = r.subCurrent === 0 && viewport.contentY === 0;
        for (let i = 0; i < n && r.subCurrent < n - 1; i++)
            t.nav({key: r.subCurrent + t.cols < n ? Qt.Key_Down : Qt.Key_Right});
        last = tileOf();
        const keyShown = r.subCurrent === n - 1 && !!last && onScreen(last) && inView(last);
        root.tilesRan = [];
        t.nav({key: Qt.Key_Return});
        root.report("tiles-" + scale + "-last-keyboard-runs", fromTop && keyShown && root.tilesRan.length === 1 && root.tilesRan[0] === 31, "fromTop=" + fromTop + " shown=" + keyShown + " sub=" + r.subCurrent + " scroll=" + viewport.contentY + " ran=" + root.tilesRan.join(","));
        ev.destroy();
    }
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
                    // the ring with the default entries: nothing moves into «Ещё» (no plugins: no «Ещё» at all)
                    const r = ringLoader.item;
                    const want = DeskMenu.quick.concat(DeskMenu.items.filter(id => id !== "sep" && id !== "more" && !DeskMenu.quick.includes(id)));
                    root.report("ring-default-fits", !(r.overflow || []).length && JSON.stringify(r.slots) === JSON.stringify(want), r.slots.join(","));
                    // 5 quick + 12 more (4 flyouts, a custom command last): 17, one past the ring
                    Config.desktop.menuCustom = [{
                            "id": "custom:1",
                            "label": "F06",
                            "icon": "heart",
                            "kind": "command",
                            "target": "touch \"$HOME/f06-ran\""
                        }];
                    Config.desktop.menuQuick = ["terminal", "files", "monitor", "wallpaperPick", "settings"];
                    Config.desktop.menuItems = ["view", "new", "wallpaper", "open", "sep", "displaySettings", "personalize", "more", "record", "clipboard", "launcher", "note", "nextWallpaper", "custom:1"];
                }
                root.next();
                break;
            case 7:
                {
                    const r = ringLoader.item;
                    const all = DeskMenu.quick.concat(DeskMenu.items.filter(id => id !== "sep" && id !== "more"));
                    Config.appearance.px = 4;
                    Config.desktop.menuSize = "large";
                    deskWin.visible = true;
                    noList.moreItems = Array.from({length: 28}, (_, i) => ({
                        "id": "extra:" + i,
                        "label": "Extra " + i,
                        "run": () => { if (i === 27) root.lastMouseRan = true; },
                        "keepOpen": true
                    }));
                    r.fly = "more";
                    const inMore = r.flyItems.map(x => x.id);
                    const lost = all.filter(id => !r.slots.includes(id) && !inMore.includes(id));
                    root.report("ring-overflow-reachable", all.length === 17 && r.slots.length <= 16 && r.slots.includes("more") && lost.length === 0, "slots=" + r.slots.length + " " + r.slots.join(",") + " more=" + inMore.join(",") + " lost=" + lost.join(","));
                    root.report("ring-overflow-custom-in-more", inMore.includes("custom:1") && !r.slots.includes("custom:1") && ["view", "new", "wallpaper", "open"].every(id => r.slots.includes(id)), inMore.join(","));
                    const fly = testFly;
                    if (fly) {
                        const viewport = findItem(fly, it => it.contentY !== undefined && it.contentHeight !== undefined && it.clip);
                        root.report("ring-overflow-keeps-ring-clickable", !!viewport && !viewport.interactive, viewport ? "interactive=" + viewport.interactive : "no viewport");
                        if (viewport) {
                            const wheel = Qt.createQmlObject("import QtTest; TestEvent {}", viewport);
                            wheel.mouseWheel(viewport, viewport.width - 10, viewport.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
                            wheel.destroy();
                        }
                        root.report("ring-overflow-wheel-scrolls", !!viewport && viewport.contentY > 0, viewport ? "scroll=" + viewport.contentY : "no viewport");
                        fly.ensureIndex(inMore.length - 1);
                        const last = findItem(fly, it => it.modelData && it.modelData.id === "extra:27" && it.width > 0);
                        const clickable = last ? findItem(last, it => it.cursorShape === Qt.PointingHandCursor) : null;
                        const mouseReachable = !!viewport && !!last && !!clickable && last.y - viewport.contentY >= 0 && last.y - viewport.contentY + last.height <= viewport.height;
                        if (mouseReachable) {
                            const event = Qt.createQmlObject("import QtTest; TestEvent {}", clickable);
                            event.mouseClick(clickable, clickable.width / 2, clickable.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
                            event.destroy();
                        }
                        root.report("ring-overflow-last-mouse-runs", root.lastMouseRan, "last=" + inMore[inMore.length - 1]);
                        r.subCurrent = 0;
                        const firstVisible = viewport && viewport.contentY === 0;
                        for (let i = 1; i < inMore.length; i++)
                            r.walk({key: Qt.Key_Down});
                        root.report("ring-overflow-last-mouse-visible", mouseReachable, last && viewport ? "y=" + last.y + " viewport=" + viewport.height + " px=" + Theme.u : "no last row");
                        root.report("ring-overflow-last-keyboard-scrolls", !!viewport && firstVisible && r.subCurrent === inMore.length - 1 && viewport.contentY > 0 && viewport.contentY + viewport.height >= viewport.contentHeight, viewport ? "scroll=" + viewport.contentY + " viewport=" + viewport.height + " content=" + viewport.contentHeight : "no viewport");
                    } else {
                        root.report("ring-overflow-last-mouse-visible", false, "no scroll viewport");
                        root.report("ring-overflow-last-keyboard-scrolls", false, "no scroll viewport");
                    }
                    // it runs what the list menu runs (DeskMenu.run → the custom command: a file in the test's HOME)
                    r.activateSub(inMore.indexOf("custom:1"));
                    Config.appearance.px = 2;
                    Config.desktop.menuSize = "normal";
                    deskWin.visible = false;
                }
                root.next();
                break;
            case 8:
                {
                    // the tiles look, normal size: 32 extras in «Ещё»
                    noList.moreItems = Array.from({length: 32}, (_, i) => ({
                        "id": "extra:" + i,
                        "label": "Extra " + i,
                        "run": () => root.tilesRan = root.tilesRan.concat([i]),
                        "keepOpen": true
                    }));
                    ringLoader.item.cx = 600;
                    ringLoader.item.cy = 400;
                    ringLoader.item.fly = "more";
                    tilesWin.visible = true;
                }
                root.next();
                break;
            case 9:
                if (Date.now() - root.since < 400)
                    return;
                root.checkTiles("normal");
                // …and a big UI
                Config.appearance.px = 4;
                Config.desktop.menuSize = "large";
                root.next();
                break;
            case 10:
                if (Date.now() - root.since < 400)
                    return;
                root.checkTiles("large");
                Config.appearance.px = 2;
                Config.desktop.menuSize = "normal";
                tilesWin.visible = false;
                root.next();
                break;
            case 11:
                if (Date.now() - root.since < 600)
                    return;
                ranCheck.running = true;
                root.next();
                break;
            case 12:
                if (ranCheck.running || ranCheck.code < 0) {
                    if (Date.now() - root.since < 3000)
                        return;
                }
                root.report("ring-overflow-runs", ranCheck.code === 0, "test -e exit " + ranCheck.code);
                console.log("TEST DONE");
                Qt.quit();
                root.next();
                break;
            }
        }
    }

    // the ring's host (modules/background/RadialMenu), built hidden; the list menu only lends its
    // plugin entries (none here)
    FloatingWindow {
        id: deskWin
        visible: false
        implicitWidth: 640
        implicitHeight: 480
        FlyColumn {
            id: testFly
            menu: ringLoader.item
        }
    }
    FloatingWindow {
        id: tilesWin
        visible: false
        implicitWidth: 640
        implicitHeight: 480
        TilesLook {
            id: testTiles
            menu: ringLoader.item
        }
    }
    QtObject {
        id: noList
        property var moreItems: []
        function listFor(name) {
            return name === "more" ? moreItems : [];
        }
    }
    Loader {
        id: ringLoader
        sourceComponent: RadialMenu {
            parentWindow: deskWin
            listMenu: noList
        }
    }
    Process {
        id: ranCheck
        property int code: -1
        command: ["test", "-e", Quickshell.env("HOME") + "/f06-ran"]
        onExited: c => code = c
    }
}
