pragma ComponentBehavior: Bound


import QtQuick
import QtQuick.Shapes
import qs.config
import qs.services
import qs.widgets

// The scene editor's picture: the layers over it (one cell an art pixel, drawn in runs: a row
// of the grid is a handful of rectangles), the marks (event places, rings, a request's
// regions, the shape being drawn) and the tools under the pointer.
Item {
    id: root

    required property var ed
    clip: true

    // what is being drawn now: {rect: [x0, y0, x1, y1]} | {ring: [cx, cy, rx, ry]} | {poly: [[x, y]…]}
    property var ghost: null
    property var drag: null
    property real cursorX: -1
    property real cursorY: -1
    // (for the self-test: where the pointer works, and the view it scrolls)
    readonly property alias pointer: mouse
    readonly property alias view: flick

    function closeLasso() {
        if (ed.tool !== "lasso" || !ghost || !ghost.poly || ghost.poly.length < 3)
            return;
        ed.snapshot();
        ed.fillPoly(ghost.poly);
        ghost = null;
        ed.changed(I18n.t("лассо", "a lasso"));
    }
    function cancel() {
        ghost = null;
        drag = null;
    }
    Connections {
        target: root.ed
        function onToolChanged() {
            root.cancel();
        }
        function onPicChanged() {
            root.cancel();
            root.ed.zoom = 1;
            flick.contentX = 0;
            flick.contentY = 0;
        }
        function onFlashed() {
            flash.restart();
        }
        // the zoom keeps what is in the middle of the view in the middle
        function onZoomChanged() {
            const z = root.ed.zoom, k = z / root.zoomWas;
            root.zoomWas = z;
            const cx = (flick.contentX + flick.width / 2) * k - flick.width / 2, cy = (flick.contentY + flick.height / 2) * k - flick.height / 2;
            Qt.callLater(() => {
                if (!flick)
                    return;     // the window went meanwhile
                flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, cx));
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, cy));
            });
        }
    }
    property real zoomWas: 1

    PxBox {
        anchors.fill: parent
        sunken: true
        color: Theme.sunken
    }
    PxText {
        anchors.centerIn: parent
        width: parent.width - Theme.u * 20
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        dim: true
        visible: !root.ed.pic
        text: root.ed.busy ? I18n.t("смотрю на картинку…", "looking at the picture…") : root.ed.url ? I18n.t("Выбери обои слева", "Pick a wallpaper on the left") : I18n.t("запускаю редактор…", "starting the editor…")
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Theme.u * 2
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: Math.max(width, stage.width)
        contentHeight: Math.max(height, stage.height)
        visible: !!root.ed.pic && root.ed.gw > 0

        Item {
            id: stage
            // the whole picture in the view at 100 %, grown by the zoom
            readonly property real ar: root.ed.gh > 0 ? root.ed.gw / root.ed.gh : 16 / 9
            readonly property real fitW: Math.min(flick.width, flick.height * ar)
            width: Math.round(fitW * root.ed.zoom)
            height: Math.round(width / ar)
            x: Math.max(0, Math.round((flick.width - width) / 2))
            y: Math.max(0, Math.round((flick.height - height) / 2))

            Image {
                id: bg
                anchors.fill: parent
                source: root.ed.pictureUrl(root.ed.pic)
                asynchronous: true
                cache: false
                // pixel art stays crisp, a photo is smoothed
                smooth: !root.ed.info.pixelArt
            }

            Canvas {
                id: layers
                width: Math.max(1, root.ed.gw)
                height: Math.max(1, root.ed.gh)
                smooth: false
                opacity: root.ed.overlay
                renderStrategy: Canvas.Immediate
                transform: Scale {
                    xScale: stage.width / layers.width
                    yScale: stage.height / layers.height
                }
                property int y0: 0
                property int y1: -1
                function rows(a, b) {
                    if (y1 < y0) {
                        y0 = a;
                        y1 = b;
                    } else {
                        y0 = Math.min(y0, a);
                        y1 = Math.max(y1, b);
                    }
                    requestPaint();
                }
                function all() {
                    rows(0, Math.max(0, root.ed.gh - 1));
                }
                Connections {
                    target: root.ed
                    function onPaintRevChanged() {
                        layers.all();
                    }
                    function onRowsChanged(a, b) {
                        layers.rows(a, b);
                    }
                    function onViewChanged() {
                        layers.all();
                    }
                }
                onWidthChanged: all()
                onHeightChanged: all()
                onPaint: {
                    const ctx = getContext("2d");
                    const ed = root.ed, W = ed.gw, H = ed.gh, P = ed.paint, A = ed.found;
                    const a = Math.max(0, y0), b = Math.min(H - 1, y1);
                    y0 = 0;
                    y1 = -1;
                    if (!W || !P || !A || !ed.meta) {
                        ctx.clearRect(0, 0, width, height);
                        return;
                    }
                    ctx.clearRect(0, a, W, b - a + 1);
                    const view = ed.view;
                    if (view === "picture")
                        return;
                    // a cell's colour: the layer × how sure (painted 1, found .55, found still: barely)
                    const alpha = [1, 0.55, 0.19, 0.35], styles = {};
                    for (const l of ed.meta.layers)
                        for (let c = 0; c < 4; c++)
                            styles[l.id * 4 + c] = "rgba(" + l.rgb[0] + "," + l.rgb[1] + "," + l.rgb[2] + "," + alpha[c] + ")";
                    for (let y = a; y <= b; y++) {
                        const o = y * W;
                        let run = -1, start = 0;
                        for (let x = 0; x <= W; x++) {
                            let key = -1;
                            if (x < W) {
                                const p = P[o + x], f = A[o + x];
                                if (view === "final")
                                    key = p >= 0 ? p * 4 : f === 0 ? 2 : f * 4 + 1;
                                else if (view === "found")
                                    key = f === 0 && p < 0 ? 3 : f * 4;
                                else if (p >= 0)
                                    key = p * 4;
                            }
                            if (key !== run) {
                                if (run >= 0) {
                                    ctx.fillStyle = styles[run];
                                    ctx.fillRect(start, y, x - start, 1);
                                }
                                run = key;
                                start = x;
                            }
                        }
                    }
                }
            }

            // ---- the marks ----
            // event places: the author's own bright, the found ones pale until there are own
            Repeater {
                model: {
                    root.ed.rev;
                    const kinds = {
                        "rims": "#ffffff",
                        "eyes": "#ff5a5a",
                        "ponds": "#5affff",
                        "lights": "#ffff78"
                    };
                    const out = [];
                    for (const k in kinds) {
                        const own = Array.isArray(root.ed.scene[k]);
                        for (const p of own ? root.ed.scene[k] : (root.ed.places[k] || []))
                            out.push({
                                "x": p[0],
                                "y": p[1],
                                "color": kinds[k],
                                "size": k === "lights" ? 4 : 7,
                                "alpha": !own ? 0.35 : root.ed.pointKind === k ? 1 : 0.7
                            });
                    }
                    return out;
                }
                Rectangle {
                    required property var modelData
                    readonly property int half: modelData.size * Math.max(1, Math.floor(Theme.u / 2))
                    x: Math.round(modelData.x * stage.width) - half
                    y: Math.round(modelData.y * stage.height) - half
                    width: half * 2
                    height: half * 2
                    color: "transparent"
                    border.color: modelData.color
                    border.width: Math.max(2, Theme.u)
                    opacity: modelData.alpha
                }
            }
            // rings: the band the stone is looked for in, and its middle line
            Repeater {
                model: {
                    root.ed.rev;
                    return (root.ed.scene.rings || []).concat(root.ghost && root.ghost.ring ? [root.ghost.ring.concat([root.ed.ringT / 100])] : []);
                }
                Item {
                    id: ringMark
                    required property var modelData
                    readonly property real rx: Math.max(1, modelData[2] * stage.width)
                    readonly property real ry: Math.max(1, modelData[3] * stage.height)
                    x: modelData[0] * stage.width
                    y: modelData[1] * stage.height
                    Repeater {
                        model: 2
                        Rectangle {
                            required property int index
                            x: -ringMark.rx
                            y: -ringMark.rx
                            width: ringMark.rx * 2
                            height: ringMark.rx * 2
                            radius: ringMark.rx
                            color: "transparent"
                            border.color: "#ffd24a"
                            border.width: index === 0 ? Math.max(2, ringMark.modelData[4] * ringMark.rx * 2) : 2
                            opacity: index === 0 ? 0.4 : 1
                            transform: Scale {
                                origin.x: ringMark.rx
                                origin.y: ringMark.rx
                                yScale: ringMark.ry / ringMark.rx
                            }
                        }
                    }
                }
            }
            // a request's regions, numbered
            Repeater {
                model: root.ed.regions
                Rectangle {
                    id: regionMark
                    required property var modelData
                    required property int index
                    x: modelData.rect[0] * stage.width
                    y: modelData.rect[1] * stage.height
                    width: (modelData.rect[2] - modelData.rect[0]) * stage.width
                    height: (modelData.rect[3] - modelData.rect[1]) * stage.height
                    color: Qt.alpha("#ff8fb8", 0.13)
                    border.color: "#ff8fb8"
                    border.width: Math.max(2, Theme.u)
                    PxText {
                        x: Theme.u * 2
                        y: Theme.u
                        font.bold: true
                        color: "#ff8fb8"
                        text: regionMark.index + 1
                    }
                }
            }
            // a rectangle being dragged
            Rectangle {
                visible: !!root.ghost && !!root.ghost.rect
                readonly property var r: root.ghost && root.ghost.rect ? root.ghost.rect : [0, 0, 0, 0]
                x: Math.min(r[0], r[2]) * stage.width
                y: Math.min(r[1], r[3]) * stage.height
                width: Math.abs(r[2] - r[0]) * stage.width
                height: Math.abs(r[3] - r[1]) * stage.height
                color: Qt.alpha("#ffffff", 0.13)
                border.color: "#ffffff"
                border.width: Math.max(1, Math.floor(Theme.u / 2))
            }
            // a lasso being clicked together
            Shape {
                anchors.fill: parent
                visible: !!root.ghost && !!root.ghost.poly && root.ghost.poly.length > 0
                ShapePath {
                    strokeColor: "#ffffff"
                    strokeWidth: Math.max(1, Math.floor(Theme.u / 2))
                    fillColor: Qt.alpha("#ffffff", 0.13)
                    PathPolyline {
                        path: {
                            const pts = root.ghost && root.ghost.poly ? root.ghost.poly : [];
                            const out = pts.map(p => Qt.point(p[0] * stage.width, p[1] * stage.height));
                            if (root.cursorX >= 0 && out.length)
                                out.push(Qt.point(root.cursorX * stage.width, root.cursorY * stage.height));
                            return out;
                        }
                    }
                }
            }
            // the brush, as big as it paints
            Rectangle {
                visible: root.ed.tool === "brush" && root.cursorX >= 0
                readonly property real r: (root.ed.brush / 2 + 0.5) * stage.width / Math.max(1, root.ed.gw)
                x: root.cursorX * stage.width - r
                y: root.cursorY * stage.height - r
                width: r * 2
                height: r * 2
                radius: r
                color: "transparent"
                border.color: "#ffffff"
                border.width: Math.max(1, Math.floor(Theme.u / 2))
                opacity: 0.8
            }
            // Claude changed the scene: the picture's edge lights up for a moment
            Rectangle {
                id: flashBox
                anchors.fill: parent
                color: "transparent"
                border.color: "#c8a8ff"
                border.width: Theme.u * 2
                opacity: 0
                NumberAnimation on opacity {
                    id: flash
                    running: false
                    from: 1
                    to: 0
                    duration: 1200
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                // the middle button drags the zoomed picture about
                property var pan: null
                cursorShape: root.ed.tool === "pick" ? Qt.PointingHandCursor : Qt.CrossCursor
                function rel(m) {
                    return [Math.min(1, Math.max(0, m.x / width)), Math.min(1, Math.max(0, m.y / height))];
                }
                onPressed: m => {
                    const ed = root.ed, p = rel(m), t = ed.tool;
                    if (!ed.paint)
                        return;
                    if (m.button === Qt.MiddleButton) {
                        const g = mapToItem(root, m.x, m.y);
                        pan = [g.x, g.y, flick.contentX, flick.contentY];
                        return;
                    }
                    if (m.button === Qt.RightButton) {
                        ed.removeAt(p);
                        return;
                    }
                    if (t === "brush") {
                        ed.snapshot();
                        root.drag = {
                            "last": p
                        };
                        ed.strokeTo(p, p, ed.brush / 2);
                    } else if (t === "rect" || t === "region") {
                        root.drag = {
                            "start": p
                        };
                        root.ghost = {
                            "rect": [p[0], p[1], p[0], p[1]]
                        };
                    } else if (t === "ring") {
                        root.drag = {
                            "start": p
                        };
                        root.ghost = {
                            "ring": [p[0], p[1], 0, 0]
                        };
                    } else if (t === "lasso") {
                        root.ghost = {
                            "poly": (root.ghost && root.ghost.poly ? root.ghost.poly : []).concat([p])
                        };
                    } else if (t === "fill") {
                        ed.flood(p[0], p[1]);
                    } else if (t === "pick") {
                        ed.inLayer = ed.layerAt(p[0], p[1]);
                        ed.tool = "brush";
                    } else if (t === "points") {
                        ed.addPoint(p);
                    }
                }
                onPositionChanged: m => {
                    const ed = root.ed, p = rel(m);
                    root.cursorX = p[0];
                    root.cursorY = p[1];
                    if (pan) {
                        const g = mapToItem(root, m.x, m.y);
                        flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, pan[2] - (g.x - pan[0])));
                        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, pan[3] - (g.y - pan[1])));
                        return;
                    }
                    const d = root.drag;
                    if (!d || !pressed)
                        return;
                    if (ed.tool === "brush") {
                        ed.strokeTo(d.last, p, ed.brush / 2);
                        d.last = p;
                    } else if (root.ghost && root.ghost.rect) {
                        root.ghost = {
                            "rect": [d.start[0], d.start[1], p[0], p[1]]
                        };
                    } else if (root.ghost && root.ghost.ring) {
                        root.ghost = {
                            "ring": [d.start[0], d.start[1], Math.abs(p[0] - d.start[0]), Math.abs(p[1] - d.start[1])]
                        };
                    }
                }
                onExited: {
                    root.cursorX = -1;
                    root.cursorY = -1;
                }
                onReleased: m => {
                    const ed = root.ed, t = ed.tool, g = root.ghost;
                    pan = null;
                    if (!root.drag)
                        return;
                    root.drag = null;
                    if (t === "brush") {
                        ed.changed(I18n.t("кисть", "the brush"));
                    } else if (t === "rect" && g && g.rect) {
                        ed.snapshot();
                        ed.fillRect(g.rect);
                        ed.changed(I18n.t("прямоугольник", "a rectangle"));
                    } else if (t === "region" && g && g.rect) {
                        if (Math.abs(g.rect[2] - g.rect[0]) > 0.005 && Math.abs(g.rect[3] - g.rect[1]) > 0.005)
                            ed.addRegion(g.rect);
                    } else if (t === "ring" && g && g.ring) {
                        if (g.ring[2] > 0.01 && g.ring[3] > 0.005)
                            ed.addRing(g.ring[0], g.ring[1], g.ring[2], g.ring[3]);
                    }
                    if (t !== "lasso")
                        root.ghost = null;
                }
                onDoubleClicked: root.closeLasso()
                // the wheel scrolls the zoomed picture; with Ctrl it zooms
                onWheel: w => {
                    const ed = root.ed;
                    if (w.modifiers & Qt.ControlModifier) {
                        ed.zoom = Math.max(1, Math.min(8, ed.zoom * (w.angleDelta.y > 0 ? 1.25 : 0.8)));
                        return;
                    }
                    const dx = (w.modifiers & Qt.ShiftModifier) ? w.angleDelta.y : w.angleDelta.x, dy = (w.modifiers & Qt.ShiftModifier) ? 0 : w.angleDelta.y;
                    flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - dx));
                    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - dy));
                }
            }
        }
    }
}
