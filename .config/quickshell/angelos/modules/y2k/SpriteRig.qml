import QtQuick
import Quickshell
import Quickshell.Io

// The helper drawn from pictures in parts (sprites/<who>/, cut from the
// artist's sheets by the sprite-rig tool): the body with blink and talk
// overlays on top, the wings (and the demon's tail) under it as strips of
// pre-rendered swing frames, played back and forth on the helper's 8 fps
// clock. rig.json holds the layout in art pixels; `px` screen pixels each.
// `variant`: which pictures — "" the chibi ones (sprites/<who>/), "glitch" the
// cracked-halo angel and the sleepless neon demon (sprites/<who>-glitch/), "ophanim" the
// many-eyed golden wheels (the angel's only: sprites/angel-ophanim/). `angelVariant` and
// `demonVariant` set it apart for each figure (the helper: the angel's look and the demon's).
// `skin`: the demon of a circle of hell (sprites/demon-<skin>/, cut by
// scripts/sprite-rig.py skins from the author's sheets) — until a circle has one, the
// demon of `variant` stands in.
// `ready` stays false without the pictures: the helper keeps her pixel sprite.
Item {
    id: root

    property string who: "angel"
    property string variant: ""
    property string angelVariant: variant
    property string demonVariant: variant
    property string skin: ""
    property int tick: 0
    // the clock of the swinging parts (wings, tail); authored frame strips (a belly's mouth)
    // keep `tick` — the helper rests the one while the other plays
    property int swingTick: tick
    property bool blink: false
    property bool talk: false
    // held by the pointer: the wings beat twice as fast
    property bool flutter: false
    // she cries: pixel drops run from under her closed eyes (rig.json → tears, found by
    // sprite-rig.py on the blink overlay) and fall, on the same clock as the rest of her
    property bool tears: false
    // petted (services/Angel → petting): pink ovals under her closed eyes, 0…1 (rig.json →
    // cheeks, found by sprite-rig.py on the blink overlay; a figure whose eye is its face has none)
    property real blush: 0
    property real px: 1
    // false: Settings → Y2K → Looks picked a pixel version, the helper draws that instead
    property bool use: true

    // both figures are read up front: the swap flips between them at once; the circle's
    // demon when her pictures are there
    readonly property RigFile file: who === "demon" ? (skin && skinRig.rig ? skinRig : demonRig) : angelRig
    readonly property var rig: file.rig
    readonly property bool ready: use && !!rig
    readonly property bool circleSkin: ready && who === "demon" && file === skinRig
    // the talk overlay is shown; a figure whose eye is its face (rig.json blinkCoversTalk):
    // the blink wins
    readonly property bool talking: talk && !(blink && !!rig && !!rig.blinkCoversTalk)
    // where the body is inside the rig (the figure without wings and tail)
    // px may be fractional (the helper's Ctrl+wheel size): edges are rounded to whole
    // screen pixels, so the parts still meet without seams
    function at(v) {
        return Math.round(v * px);
    }
    readonly property rect body: ready ? Qt.rect(at(rig.body.x), at(rig.body.y), at(rig.body.x + rig.body.w) - at(rig.body.x), at(rig.body.y + rig.body.h) - at(rig.body.y)) : Qt.rect(0, 0, width, height)

    implicitWidth: ready ? at(rig.size[0]) : 0
    implicitHeight: ready ? at(rig.size[1]) : 0

    component RigFile: FileView {
        required property string name
        // Keep the layout and its image directory together while the next skin loads.
        // `name` changes first; using it for images would mix the old rig with new files.
        property var loaded: ({path: "", dir: "", rig: null})
        readonly property var rig: loaded.rig
        readonly property string loadedPath: loaded.path
        readonly property string dir: loaded.dir
        path: name ? Quickshell.shellDir + "/modules/y2k/sprites/" + name + "/rig.json" : ""
        printErrors: false
        // read at once: no frame of the pixel sprite before the pictures
        blockLoading: true
        onLoaded: {
            let parsed = null;
            try {
                parsed = JSON.parse(text());
            } catch (e) {
                console.warn("SpriteRig:", path, e);
            }
            loaded = {path: path, dir: path.slice(0, path.lastIndexOf("/") + 1), rig: parsed};
        }
        onLoadFailed: {
            loaded = {path: path, dir: "", rig: null};
        }
    }
    RigFile {
        id: angelRig
        name: root.angelVariant === "glitch" || root.angelVariant === "ophanim" ? "angel-" + root.angelVariant : "angel"
    }
    RigFile {
        id: demonRig
        name: root.demonVariant === "glitch" ? "demon-glitch" : "demon"
    }
    RigFile {
        id: skinRig
        name: root.skin ? "demon-" + root.skin : ""
    }
    // the parts of one layer; each carries its own picture, so the old figure's
    // parts never look into the new one's folder while the swap swaps them
    function partsUnder(under) {
        const data = file.loaded, r = data.rig, dir = data.dir;
        return !r ? [] : Object.keys(r.parts).filter(k => !!r.parts[k].under === under).map(k => Object.assign({
                "src": "file://" + dir + k + ".png"
            }, r.parts[k]));
    }

    // a strip of swing frames, cut to the current one
    component Part: Item {
        id: part
        required property var modelData
        readonly property var p: modelData
        readonly property int step: Math.floor((p.angles && p.angles.length ? root.swingTick : root.tick) * (root.flutter && p.every === 1 ? 2 : 1) / p.every)
        readonly property int period: Math.max(1, (p.frames - 1) * 2)
        // back and forth: 0 1 2 3 4 3 2 1 …
        readonly property int frame: {
            const i = step % period;
            return i < p.frames ? i : period - i;
        }
        x: root.at(p.x)
        y: root.at(p.y)
        width: root.at(p.x + p.w) - x
        height: root.at(p.y + p.h) - y
        clip: true
        Image {
            x: -part.frame * part.width
            width: part.width * part.p.frames
            height: part.height
            source: part.p.src
            smooth: false
            mipmap: false
        }
    }

    Repeater {
        model: root.partsUnder(true)
        Part {}
    }
    Item {
        visible: root.ready
        x: root.body.x
        y: root.body.y
        width: root.body.width
        height: root.body.height
        Image {
            anchors.fill: parent
            source: root.use && root.file.loaded.rig ? "file://" + root.file.loaded.dir + "body.png" : ""
            smooth: false
            mipmap: false
        }
        Image {
            anchors.fill: parent
            visible: root.blink
            source: root.use && root.file.loaded.rig ? "file://" + root.file.loaded.dir + "eyes.png" : ""
            smooth: false
            mipmap: false
        }
        Image {
            anchors.fill: parent
            visible: root.talking
            source: root.use && root.file.loaded.rig ? "file://" + root.file.loaded.dir + "mouth.png" : ""
            smooth: false
            mipmap: false
        }
        // the blush: a 7×3 oval of `k` art pixels each, two darker strokes across it
        Repeater {
            model: root.blush > 0 && root.ready && root.rig.cheeks ? root.rig.cheeks.at : []
            Item {
                id: cheek
                required property var modelData
                readonly property real k: root.rig.cheeks.k * root.px
                x: Math.round(modelData[0] * root.px)
                y: Math.round(modelData[1] * root.px)
                opacity: root.blush
                Repeater {
                    model: [[1, 0, 5, 1, 0], [0, 1, 7, 1, 0], [1, 2, 5, 1, 0], [2, 1, 1, 1, 1], [4, 1, 1, 1, 1]]
                    Rectangle {
                        required property var modelData
                        x: Math.round(modelData[0] * cheek.k)
                        y: Math.round(modelData[1] * cheek.k)
                        width: Math.round((modelData[0] + modelData[2]) * cheek.k) - x
                        height: Math.round((modelData[1] + modelData[3]) * cheek.k) - y
                        color: modelData[4] ? Qt.rgba(0.84, 0.2, 0.41, 0.8) : Qt.rgba(1, 0.38, 0.55, 0.55)
                    }
                }
            }
        }
    }
    Repeater {
        model: root.partsUnder(false)
        Part {}
    }

    // ---- tears: three drops a source, apart in time, falling faster as they go ----
    // a drop is 3×4 art pixels — a dark blue rim round a light core, a white glint — so it
    // reads over gold and white alike; a wet trail runs behind it from the eye
    Repeater {
        model: root.tears && root.ready && root.rig.tears ? root.rig.tears.length * 3 : 0
        Item {
            id: drop
            required property int index
            // (the figure may change under it — the swap — before the model follows)
            readonly property var from: (root.rig && root.rig.tears && root.rig.tears[Math.floor(index / 3)]) || [0, 0]
            readonly property int period: 18
            // ticks into this drop's fall; it wells up for a moment, then drops
            readonly property int t: (root.tick + Math.floor(index / 3) * 5 + (index % 3) * 6) % period
            readonly property int fall: t < 2 ? 0 : Math.round(0.3 * (t - 2) * (t - 2))
            visible: t < 13
            opacity: t < 10 ? 1 : (13 - t) / 4
            x: root.body.x + root.at(from[0] - 1)
            y: root.body.y + root.at(from[1])
            Rectangle {
                x: root.at(1)
                width: Math.max(1, root.at(1))
                height: root.at(drop.fall)
                color: "#7cc4ff"
                opacity: 0.45
            }
            Item {
                y: root.at(drop.fall)
                Rectangle {
                    width: root.at(3)
                    height: root.at(drop.t < 2 ? 2 : 4)
                    color: "#2b63b8"
                }
                Rectangle {
                    x: root.at(1)
                    y: root.at(1)
                    width: root.at(1)
                    height: root.at(drop.t < 2 ? 1 : 2)
                    color: "#bfe9ff"
                }
                Rectangle {
                    x: root.at(1)
                    y: root.at(1)
                    width: root.at(1)
                    height: root.at(1)
                    visible: drop.t >= 2
                    color: "#ffffff"
                }
            }
        }
    }
}
