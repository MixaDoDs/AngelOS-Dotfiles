pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The wallpaper editor's state: the scene being edited (a folder with scene.json, widgets/SceneWall),
// its modifiers, undo. Every change is written by itself half a second after the last, and that
// moment is one step of undo. The first write of a scene keeps what it was as scene.orig.json.
Item {
    id: ed

    property string dir: ""
    property var scene: null
    property var mods: []
    property int sel: -1
    property string tool: "move"          // move | brush | erase
    property int brush: 10                // art px
    property string note: ""

    readonly property int cw: scene ? scene.logical_canvas.width : 1
    readonly property int ch: scene ? scene.logical_canvas.height : 1
    readonly property var selected: mods[sel] || null
    readonly property int bulges: mods.filter(m => m.type === "bulge").length
    readonly property int maxBulges: 4
    readonly property string reference: scene && scene.neutral_pose ? dir + "/" + scene.neutral_pose.reference : ""
    readonly property string holdRel: "logical/modifier_hold.png"

    // ---- opening ----
    function open(folder) {
        flush();
        history = [];
        at = -1;
        backedUp = false;
        sel = -1;
        tool = "move";
        scene = null;
        mods = [];
        dir = folder;
    }
    FileView {
        id: file
        path: ed.dir ? ed.dir + "/scene.json" : ""
        onLoaded: {
            const s = JSON.parse(text());
            ed.mods = s.modifiers || [];
            ed.scene = s;
            ed.history = [{
                    "mods": JSON.stringify(ed.mods),
                    "hold": null
                }];
            ed.at = 0;
        }
        onLoadFailed: {
            ed.note = I18n.t("Не удалось прочитать сцену", "Could not read the scene");
            ed.dir = "";
        }
    }
    // a scene folder, a scene's picture, or any picture: that one is first asked how to take it
    function openPicture(path) {
        if (!path)
            return;
        const scene = Wallpapers.sceneOf(path) || (Object.values(Wallpapers.scenes).includes(path) ? path : "");
        if (scene)
            open(scene);
        else
            ask(path);
    }

    // ---- a new wallpaper from a picture (scripts/wall-studio.py) ----
    readonly property string script: Quickshell.shellDir + "/scripts/wall-studio.py"
    readonly property string projects: Wallpapers.heavenDir + "/studio"
    property var asking: null             // {path, width, height}: an ordinary picture, how to take it
    readonly property bool busy: inspector.running || maker.running
    function ask(path) {
        note = "";
        asking = null;
        inspector.command = ["python3", script, "inspect", path];
        inspector.path = path;
        inspector.running = true;
    }
    function make(path, mode) {
        asking = null;
        const s = Quickshell.screens.reduce((a, b) => b.width * b.height > a.width * a.height ? b : a);
        maker.command = ["python3", script, "new", path, projects, "--mode", mode, "--screen", s.width + "x" + s.height];
        maker.running = true;
    }
    Process {
        id: inspector
        property string path: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                const info = JSON.parse(text);
                // pixel art is taken as it is; for the rest the author chooses
                if (info.art)
                    ed.make(inspector.path, "art");
                else
                    ed.asking = Object.assign({
                        "path": inspector.path
                    }, info);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                ed.note = I18n.t("Эту картинку не открыть", "This picture can't be opened")
        }
    }
    Process {
        id: maker
        stdout: StdioCollector {
            onStreamFinished: {
                const made = text.trim();
                if (!made)
                    return;
                Wallpapers.scan();
                ed.open(made);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                ed.note = I18n.t("Не удалось создать обои", "Could not make the wallpaper")
        }
    }

    // ---- changes ----
    function newId() {
        return "m" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
    }
    function change(list) {
        mods = list;
        saver.restart();
    }
    function setMod(i, key, value) {
        change(mods.map((m, n) => {
            if (n !== i)
                return m;
            const c = Object.assign({}, m);
            c[key] = value;
            // a wave put in a place of its own no longer follows its zone
            if (key === "center")
                delete c.zone;
            return c;
        }));
    }
    function bulge(cx, cy) {
        const r = Math.round(Math.min(cw, ch) * 0.12);
        return {
            "id": newId(),
            "type": "bulge",
            "source": "kick",
            "strength": 0.6,
            "release": 0.18,
            "center": [Math.round(cx), Math.round(cy)],
            "radius": [r, r]
        };
    }
    function addBulge() {
        if (bulges >= maxBulges)
            return;
        const m = bulge(cw / 2, ch / 2);
        change(mods.concat([m]));
        sel = mods.length - 1;
    }
    function addWave() {
        change(mods.concat([{
                    "id": newId(),
                    "type": "wave",
                    "source": "kick",
                    "strength": 0.6,
                    "speed": 1,
                    "center": [Math.round(cw / 2), Math.round(ch / 2)],
                    "widgets": true
                }]));
        sel = mods.length - 1;
    }
    // the speaker in one click: a cone that swells and the wave out of it
    function addSpeaker() {
        if (bulges >= maxBulges)
            return;
        const b = bulge(cw / 2, ch / 2);
        change(mods.concat([b, {
                    "id": newId(),
                    "type": "wave",
                    "source": "kick",
                    "strength": 0.5,
                    "speed": 1,
                    "zone": b.id,
                    "widgets": true
                }]));
        sel = mods.length - 2;
    }
    // the presets of the editor's «Заготовка» row: one click, and the picture moves; returns the
    // sound that shows it off (the window strikes it once). "speaker" — a cone and its wave on the
    // kick, "wave" — a wave over the whole picture, "shake" — a spot jolting on the snare, "tick" —
    // a small twitch on the hats
    function addPreset(kind) {
        if (kind === "speaker") {
            addSpeaker();
            return "kick";
        }
        if (kind === "wave") {
            addWave();
            return "kick";
        }
        if (bulges >= maxBulges)
            return "";
        const m = bulge(cw / 2, ch / 2);
        if (kind === "shake") {
            m.source = "snare";
            m.strength = 0.45;
            m.release = 0.1;
        } else {
            m.source = "hat";
            m.strength = 0.25;
            m.release = 0.08;
            m.radius = [Math.round(m.radius[0] * 0.6), Math.round(m.radius[1] * 0.6)];
        }
        change(mods.concat([m]));
        sel = mods.length - 1;
        return m.source;
    }
    function remove(i) {
        const gone = mods[i];
        // a wave of that zone stays where it was
        change(mods.filter((m, n) => n !== i).map(m => {
            if (m.zone !== gone.id)
                return m;
            const c = Object.assign({}, m);
            delete c.zone;
            c.center = gone.center;
            return c;
        }));
        sel = -1;
    }

    // ---- writing: half a second after the last change ----
    property bool backedUp: false
    property bool holdChanged: false
    property var stage: null              // the picture, it holds the brush's canvas
    Timer {
        id: saver
        interval: 500
        onTriggered: ed.write()
    }
    function flush() {
        if (saver.running) {
            saver.stop();
            write();
        }
    }
    function write() {
        if (!scene)
            return;
        if (!backedUp) {
            backedUp = true;
            backup.command = ["cp", "-n", dir + "/scene.json", dir + "/scene.orig.json"];
            backup.startDetached();
        }
        scene.modifiers = mods;
        file.setText(JSON.stringify(scene, null, 2) + "\n");
        // one step of undo; a brush's strokes keep the mask as it was after them
        history = history.slice(Math.max(0, at - 30), at + 1).concat([{
                "mods": JSON.stringify(mods),
                "hold": holdChanged && stage ? stage.holdPixels() : holdNow()
            }]);
        at = history.length - 1;
        holdChanged = false;
    }
    Process {
        id: backup
    }
    // the brush's mask was saved (StudioStage): the scene says so and it is a step of undo
    function holdSaved(undoing) {
        if (scene)
            scene.modifier_hold = holdRel;
        if (undoing) {
            file.setText(JSON.stringify(scene, null, 2) + "\n");
            return;
        }
        holdChanged = true;
        saver.restart();
    }
    // the mask the scene came with: what undo goes back to
    function holdLoaded(pixels) {
        if (at === 0 && history[0])
            history[0].hold = pixels;
    }

    // ---- undo: history[at] is what the file says now ----
    property var history: []
    property int at: -1
    readonly property bool canUndo: at > 0 || saver.running
    readonly property bool canRedo: at >= 0 && at < history.length - 1 && !saver.running
    function holdNow() {
        return at >= 0 && history[at] ? history[at].hold : null;
    }
    function step(to) {
        const h = history[to];
        if (!h)
            return;
        const was = holdNow();
        at = to;
        mods = JSON.parse(h.mods);
        if (sel >= mods.length)
            sel = -1;
        scene.modifiers = mods;
        if (h.hold !== was && stage)
            stage.holdRestore(h.hold);
        file.setText(JSON.stringify(scene, null, 2) + "\n");
    }
    function undo() {
        flush();
        step(at - 1);
    }
    function redo() {
        step(at + 1);
    }

    // ---- «На обои» ----
    function apply(output) {
        flush();
        if (!reference)
            return;
        if (output)
            Wallpapers.setForOutput(output, reference);
        else
            Wallpapers.setEverywhere(reference);
        WallStudio.applied(dir);
        note = I18n.t("Поставлено на обои", "Set as the wallpaper");
    }
}
