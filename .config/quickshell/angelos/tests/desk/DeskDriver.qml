pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.modules.desktop

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
                console.log("TEST DONE");
                Qt.quit();
                root.next();
                break;
            }
        }
    }
}
