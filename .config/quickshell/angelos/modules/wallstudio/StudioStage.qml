pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The wallpaper editor's picture: the real scene (widgets/SceneWall with the same effect as on the
// desktop) as big as whole art pixels allow, the selected modifier's marks and the brush that pins
// what must not move.
Item {
    id: root

    required property var ed
    readonly property alias wall: picture
    readonly property alias drums: drums
    // (for the self-test: where the pointer works)
    readonly property alias pointer: mouse

    readonly property real viewW: Math.max(1, ed.cw - 2 * picture.margin)
    readonly property real viewH: Math.max(1, ed.ch - 2 * picture.margin)
    readonly property real fit: Math.min(width / viewW, height / viewH)
    readonly property real zoom: fit >= 1 ? Math.floor(fit) : fit

    Component.onCompleted: ed.stage = root

    Item {
        id: view
        anchors.centerIn: parent
        width: Math.round(root.viewW * root.zoom)
        height: Math.round(root.viewH * root.zoom)
        clip: true
        visible: root.ed.scene !== null

        SceneWall {
            id: picture
            anchors.fill: parent
            dir: root.ed.dir
            modsOverride: root.ed.mods
            wind: SceneWind.strength
            windDir: SceneWind.dir
            pulse: SceneWind.pulse
            seed: SceneWind.seed
            SceneDrums {
                id: drums
                wall: picture
                folder: root.ed.dir
                hearing: true
                studio: true
            }
            layer.enabled: true
            layer.smooth: false
            layer.effect: SceneKickFx {
                wall: picture
            }
            FrameAnimation {
                running: root.visible && root.ed.scene !== null
                onTriggered: picture.time = (picture.time + Math.min(frameTime, 0.1)) % 3600
            }
        }

        // what the brush pinned, shown while it is in the hand; the file SceneWall reads
        Canvas {
            id: hold
            readonly property real scale_: Math.min(1, 656 / Math.max(1, root.ed.cw))
            // what onPaint has to do: strokes (Canvas draws only there)
            property var strokes: []
            property bool clearing: false
            property var restore: null
            property bool restoring: false
            property bool undoing: false    // this save is a step of undo, not a new change
            property string pixels: ""      // the mask as it is now, a PNG for undo
            property bool loadAfter: false
            readonly property string fileUrl: root.ed.dir ? "file://" + root.ed.dir + "/" + root.ed.holdRel : ""
            width: Math.round(root.ed.cw * scale_)
            height: Math.round(root.ed.ch * scale_)
            x: picture.ox
            y: picture.oy
            transformOrigin: Item.TopLeft
            scale: picture.k / scale_
            smooth: false
            // not 0: an item that isn't drawn doesn't paint, undo and saving need it to
            opacity: root.ed.tool === "move" ? 0.001 : 0.55
            onFileUrlChanged: reload()
            function reload() {
                clearing = true;
                requestPaint();
                if (!fileUrl || !root.ed.dir)
                    return;
                unloadImage(fileUrl);
                loadImage(fileUrl);
            }
            onImageLoaded: {
                loadAfter = !restoring;
                requestPaint();
            }
            onPaint: {
                const ctx = getContext("2d");
                if (clearing) {
                    clearing = false;
                    ctx.clearRect(0, 0, width, height);
                }
                if (restoring && (!restore || isImageLoaded(restore))) {
                    restoring = false;
                    ctx.clearRect(0, 0, width, height);
                    if (restore)
                        ctx.drawImage(restore, 0, 0);
                    holdSave.restart();
                }
                if (loadAfter) {
                    loadAfter = false;
                    if (isImageLoaded(fileUrl)) {
                        ctx.drawImage(fileUrl, 0, 0, width, height);
                        holdBase.restart();
                    }
                }
                for (const s of strokes) {
                    ctx.globalCompositeOperation = s.erase ? "destination-out" : "source-over";
                    const g = ctx.createRadialGradient(s.x, s.y, 0, s.x, s.y, s.r);
                    g.addColorStop(0, "rgba(255,48,80,1)");
                    g.addColorStop(0.6, "rgba(255,48,80,1)");
                    g.addColorStop(1, "rgba(255,48,80,0)");
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(s.x, s.y, s.r, 0, 2 * Math.PI);
                    ctx.fill();
                }
                strokes = [];
                ctx.globalCompositeOperation = "source-over";
            }
            // the mask the scene came with: what undo goes back to
            Timer {
                id: holdBase
                interval: 60
                onTriggered: {
                    hold.pixels = hold.toDataURL("image/png");
                    root.ed.holdLoaded(hold.pixels);
                }
            }
            Timer {
                id: holdSave
                interval: 60                // the strokes have to be painted first
                onTriggered: {
                    hold.pixels = hold.toDataURL("image/png");
                    if (hold.save(root.ed.dir + "/" + root.ed.holdRel))
                        root.ed.holdSaved(hold.undoing);
                    else
                        root.ed.note = I18n.t("Не удалось сохранить маску", "Could not save the mask");
                    hold.undoing = false;
                }
            }
        }
        // the selected modifier: an ellipse and its grips, or the point a wave rings out of
        Canvas {
            id: marks
            anchors.fill: parent
            readonly property var m: root.ed.selected
            readonly property var c: m ? root.centerOf(m) : null
            readonly property string key: m ? JSON.stringify([c, m.radius, picture.k, picture.ox, picture.oy]) : ""
            onKeyChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!m)
                    return;
                const x = picture.ox + c[0] * picture.k, y = picture.oy + c[1] * picture.k, u = Theme.u;
                const ink = (draw, w) => {
                    ctx.lineWidth = w + 2;
                    ctx.strokeStyle = "#000000";
                    draw();
                    ctx.lineWidth = w;
                    ctx.strokeStyle = "#ffffff";
                    draw();
                };
                if (m.type === "bulge") {
                    const rx = m.radius[0] * picture.k, ry = m.radius[1] * picture.k;
                    ink(() => {
                        ctx.beginPath();
                        ctx.ellipse(x - rx, y - ry, rx * 2, ry * 2);
                        ctx.stroke();
                    }, 1);
                    for (const p of [[x + rx, y], [x, y + ry]]) {
                        ctx.fillStyle = "#000000";
                        ctx.fillRect(p[0] - u * 2, p[1] - u * 2, u * 4, u * 4);
                        ctx.fillStyle = "#ffffff";
                        ctx.fillRect(p[0] - u, p[1] - u, u * 2, u * 2);
                    }
                }
                ink(() => {
                    ctx.beginPath();
                    ctx.moveTo(x - u * 4, y);
                    ctx.lineTo(x + u * 4, y);
                    ctx.moveTo(x, y - u * 4);
                    ctx.lineTo(x, y + u * 4);
                    ctx.stroke();
                }, 1);
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: root.ed.scene !== null
            hoverEnabled: true
            cursorShape: root.ed.tool === "move" ? (drag ? Qt.ClosedHandCursor : Qt.ArrowCursor) : Qt.CrossCursor
            property var drag: null         // {i, what: center | rx | ry}
            property point last: Qt.point(0, 0)
            function art(p) {
                return Qt.point((p.x - picture.ox) / picture.k, (p.y - picture.oy) / picture.k);
            }
            onPressed: e => {
                const a = art(e);
                if (root.ed.tool !== "move") {
                    last = a;
                    root.dab(a, a);
                    return;
                }
                drag = root.grip(a);
                if (drag)
                    root.ed.sel = drag.i;
                else
                    root.ed.sel = root.inside(a);
            }
            onPositionChanged: e => {
                const a = art(e);
                if (root.ed.tool !== "move") {
                    if (pressed)
                        root.dab(last, a);
                    last = a;
                    return;
                }
                if (!drag)
                    return;
                const m = root.ed.mods[drag.i];
                const clamp = (v, hi) => Math.max(0, Math.min(hi, Math.round(v)));
                if (drag.what === "center")
                    root.ed.setMod(drag.i, "center", [clamp(a.x, root.ed.cw), clamp(a.y, root.ed.ch)]);
                else if (drag.what === "rx")
                    root.ed.setMod(drag.i, "radius", [Math.max(2, clamp(Math.abs(a.x - m.center[0]), root.ed.cw)), m.radius[1]]);
                else
                    root.ed.setMod(drag.i, "radius", [m.radius[0], Math.max(2, clamp(Math.abs(a.y - m.center[1]), root.ed.ch))]);
            }
            onReleased: {
                drag = null;
                if (root.ed.tool !== "move")
                    holdSave.restart();
            }
        }
    }

    function centerOf(m) {
        const z = m.zone ? ed.mods.find(b => b.id === m.zone) : null;
        return z ? z.center : m.center;
    }
    // what is under the pointer: the selected one's grips first, then any centre
    function grip(a) {
        const near = 7 * Theme.u / picture.k;
        const dist = (x, y) => Math.hypot(a.x - x, a.y - y);
        const m = ed.selected;
        if (m && m.type === "bulge") {
            if (dist(m.center[0] + m.radius[0], m.center[1]) < near)
                return {
                    "i": ed.sel,
                    "what": "rx"
                };
            if (dist(m.center[0], m.center[1] + m.radius[1]) < near)
                return {
                    "i": ed.sel,
                    "what": "ry"
                };
        }
        for (let i = ed.mods.length - 1; i >= 0; i--) {
            const c = centerOf(ed.mods[i]);
            // a wave that follows its zone has no place of its own
            if (!ed.mods[i].zone && c && dist(c[0], c[1]) < near)
                return {
                    "i": i,
                    "what": "center"
                };
        }
        return null;
    }
    function inside(a) {
        for (let i = ed.mods.length - 1; i >= 0; i--) {
            const m = ed.mods[i];
            if (m.type === "bulge" && Math.pow((a.x - m.center[0]) / m.radius[0], 2) + Math.pow((a.y - m.center[1]) / m.radius[1], 2) < 1)
                return i;
        }
        return -1;
    }
    // the brush from one art point to another, every half a brush
    function dab(from, to) {
        const s = hold.scale_, r = ed.brush * s;
        const n = Math.max(1, Math.ceil(Math.hypot(to.x - from.x, to.y - from.y) * s / Math.max(1, r / 2)));
        const list = hold.strokes.slice();
        for (let i = 0; i <= n; i++)
            list.push({
                "x": (from.x + (to.x - from.x) * i / n) * s,
                "y": (from.y + (to.y - from.y) * i / n) * s,
                "r": r,
                "erase": ed.tool === "erase"
            });
        hold.strokes = list;
        hold.requestPaint();
    }
    // undo (StudioModel): the mask as a PNG, and back (Canvas's putImageData draws nothing here)
    function holdPixels() {
        return hold.pixels;
    }
    function holdRestore(pixels) {
        hold.restore = pixels;
        hold.restoring = true;
        hold.undoing = true;
        if (pixels)
            hold.loadImage(pixels);
        hold.requestPaint();
    }
}
