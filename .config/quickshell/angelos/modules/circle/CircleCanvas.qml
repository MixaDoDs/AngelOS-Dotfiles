pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.services
import qs.widgets

// The screenshot overlay's face (services/CircleSearch), Pixel's Circle to Search: the frozen
// frame, a light sweeping it while it is read, the areas found outlined (the one under the
// pointer lit, with its kind), the words of Live Text, the pick (a loop, a rectangle with
// corners to drag, a run of words) with the rest dimmed, the modes at the top, the text card at
// the pick and the bar of actions at the bottom. Closing: a fade; a picture taken: a shutter
// flash and the piece flying into the corner. CircleOverlay hosts it in a layer window; the
// offscreen test (tests/circle) hosts it in a plain one and drives press/move/release/key.
Item {
    id: canvas

    // frame pixels → window pixels (a scaled screen: the frame is bigger than the window)
    readonly property real k: width / Math.max(1, CircleSearch.frameW)
    readonly property int u: Theme.u
    property var stroke: []                  // the loop / rectangle being drawn, window pixels
    property bool drawing: false
    property string drawMode: "auto"         // this drag's mode (Shift: a rectangle)
    property real travel: 0
    property int textFrom: -1                // a text drag's first word
    property int corner: -1                  // the pick's grip being dragged: 0 tl, 1 tr, 2 br, 3 bl corners,
                                             // 4 top, 5 right, 6 bottom, 7 left sides, 8 the whole frame
    property var adjust: null                // the pick while a grip is dragged, frame pixels
    property point grabbed: Qt.point(0, 0)   // where the drag of a grip began, frame pixels
    property point at: Qt.point(-1, -1)      // the pointer, frame pixels
    property string leaving: ""              // "shot": the shutter plays while it fades
    property var shotRect: null
    property bool windowPreview: false       // the pointer on "Window": what it will take
    property point up: Qt.point(-1, -1)      // where the pointer let go of the last pick: the bar comes there
    property bool fresh: true                // the bar was hidden (a drag, opening): it appears in place, no glide
    property int textTo: -1                  // a text drag's last word (the pick changes only when it does)
    // the pointer's newest place, handled once a frame (an 8 kHz mouse sends 8000 moves a second)
    property real px: 0
    property real py: 0
    property bool dirty: false
    // the area under the pointer (a window by its edge): what a tap takes
    readonly property var hovered: !drawing && !CircleSearch.box && at.x >= 0 && CircleSearch.mode !== "text" ? CircleSearch.areaAt(at.x, at.y) : null
    readonly property var target: windowPreview ? CircleSearch.targetWindow(at.x, at.y) : null
    readonly property bool editing: editor.input.activeFocus
    readonly property alias bar: bar
    readonly property alias card: card
    readonly property alias modeBox: modeBox

    // a drag that encloses next to nothing (corner to corner, as every other screenshot tool
    // takes a rectangle): a rectangle, not a loop
    function lineLike(s) {
        if (s.length < 2)
            return false;
        let a = 0, x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (let i = 0; i < s.length; i++) {
            const p = s[i], q = s[(i + 1) % s.length];
            a += p.x * q.y - q.x * p.y;
            x0 = Math.min(x0, p.x);
            y0 = Math.min(y0, p.y);
            x1 = Math.max(x1, p.x);
            y1 = Math.max(y1, p.y);
        }
        return Math.abs(a) / 2 < (x1 - x0) * (y1 - y0) * 0.25;
    }
    function win(r) {   // a frame rect in window pixels
        return r ? Qt.rect(r.x * k, r.y * k, r.w * k, r.h * k) : Qt.rect(0, 0, width, height);
    }

    // ---- where the bar and the card go (window pixels). Not a binding: worked out once a pick
    // settles (a drag let go, the OCR text in), never per frame of a drag.
    function overlaps(a, b) {
        return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
    }
    function layout() {
        const m = u * 4, g = u * 6, W = width, H = height;
        const bw = bar.width, bh = bar.height, cw = card.width, ch = card.height;
        const mode = modeBox.visible ? Qt.rect(modeBox.x, modeBox.y, modeBox.width, modeBox.height + u * 2) : Qt.rect(0, 0, 0, 0);
        const clampX = (x, w) => Math.max(m, Math.min(W - w - m, x)), clampY = (y, h) => Math.max(m, Math.min(H - h - m, y));
        const fits = r => r.x >= m - 0.5 && r.y >= m - 0.5 && r.x + r.width <= W - m + 0.5 && r.y + r.height <= H - m + 0.5 && !overlaps(r, mode);
        const home = Qt.rect((W - bw) / 2, H - bh - u * 12, bw, bh);
        if (!CircleSearch.box)
            return {
                "bar": home,
                "rtl": false,
                "card": Qt.point(clampX(W / 2 - cw / 2, cw), home.y - m - ch)
            };
        const b = win(CircleSearch.box);
        // the pointer if it let go at this pick (a loop's end, a corner, a tap), else its bottom middle
        const near = up.x >= b.x - u * 40 && up.x <= b.x + b.width + u * 40 && up.y >= b.y - u * 40 && up.y <= b.y + b.height + u * 40;
        const p = near ? up : Qt.point(b.x + b.width / 2, b.y + b.height);
        // the first (likeliest) button under the pointer: the bar starts there, or ends there right to left
        const first = buttons.children.find(c => c.visible && c.implicitWidth > 0);
        const lead = Theme.pad + bar.inset + (first ? first.implicitWidth / 2 : 0);
        const along = (y, rtl) => {
            const x = clampX(rtl ? p.x + lead - bw : p.x - lead, bw);
            return {
                "r": Qt.rect(x, y, bw, bh),
                "rtl": rtl,
                "side": y > b.y ? "below" : "above"
            };
        };
        // right to left only when clamping at the right edge pushes the first button further away
        const rtlFree = Math.abs(clampX(p.x + lead - bw, bw) + bw - lead - p.x) < Math.abs(clampX(p.x - lead, bw) + lead - p.x);
        const sideY = clampY(p.y - bh / 2, bh);
        const slots = [along(b.y + b.height + g, rtlFree), along(b.y - g - bh, rtlFree), {
                "r": Qt.rect(b.x + b.width + g, sideY, bw, bh),
                "rtl": false,
                "side": "right"
            }, {
                "r": Qt.rect(b.x - g - bw, sideY, bw, bh),
                "rtl": true,
                "side": "left"
            }].filter(c => fits(c.r) && !overlaps(c.r, b));
        const dist = c => {
            const fx = c.rtl ? c.r.x + c.r.width - lead : c.r.x + lead;
            return Math.hypot(fx - p.x, c.r.y + c.r.height / 2 - p.y);
        };
        slots.sort((a, c) => dist(a) - dist(c));
        // no room round it (most of the screen picked): inside it, at the edge the pointer is at
        const B = slots.length ? slots[0] : along(p.y > b.y + b.height / 2 ? Math.min(home.y, b.y + b.height - m - bh) : Math.max(mode.y + mode.height, b.y + m), rtlFree);
        // the card: the other side of the pick, else past the bar, else beside the pick, else by the bar
        const cx = clampX(b.x + b.width / 2 - cw / 2, cw), cy = clampY(b.y, ch);
        const R = B.r, past = B.side === "above" ? R.y - m - ch : R.y + R.height + m;
        const opposite = B.side === "below" ? [b.y - g - ch] : B.side === "above" ? [b.y + b.height + g] : [b.y + b.height + g, b.y - g - ch];
        const tries = opposite.map(y => Qt.rect(cx, y, cw, ch)).concat([Qt.rect(cx, past, cw, ch), Qt.rect(b.x + b.width + g, cy, cw, ch), Qt.rect(b.x - g - cw, cy, cw, ch)]);
        const C = tries.find(r => fits(r) && !overlaps(r, b) && !overlaps(r, R)) || Qt.rect(cx, clampY(R.y > H / 2 ? R.y - m - ch : R.y + R.height + m, ch), cw, ch);
        return {
            "bar": R,
            "rtl": B.rtl,
            "card": Qt.point(C.x, C.y)
        };
    }
    function relayout() {
        if (drawing || corner >= 0)
            return;
        const L = layout();
        bar.glide = !fresh;
        if (fresh)
            settle.restart();
        bar.rtl = L.rtl;
        bar.at = Qt.point(L.bar.x, L.bar.y);
        if (!editing)   // not under the user's typing
            card.at = L.card;
    }
    // the first moments after a pick: the bar's rows and the card's text still settle, it moves without a glide
    Timer {
        id: settle
        interval: 150
        onTriggered: canvas.fresh = false
    }
    onDrawingChanged: Qt.callLater(relayout)
    onCornerChanged: Qt.callLater(relayout)
    onHeightChanged: Qt.callLater(relayout)
    onWidthChanged: Qt.callLater(relayout)
    Component.onCompleted: Qt.callLater(relayout)

    // ---- the keys (CircleOverlay's shortcuts and the test call this)
    function key(name) {
        switch (name) {
        case "Escape":
            if (drawing || corner >= 0) {
                drawing = false;
                corner = -1;
                adjust = null;
                stroke = [];
                return true;
            }
            CircleSearch.back();
            return true;
        case "Enter":
            CircleSearch.enter();
            return true;
        case "Ctrl+Enter":
            CircleSearch.search();
            return true;
        case "Ctrl+C":
            CircleSearch.ctrlC();
            return true;
        case "Ctrl+S":
            CircleSearch.save();
            return true;
        case "Ctrl+A":
            CircleSearch.selectAll();
            return true;
        case "Tab":
            CircleSearch.nextMode();
            return true;
        }
        return false;
    }

    // ---- the pointer, window pixels
    // the grip of the pick under a point (window pixels): a corner, a side, inside it; -1 none
    function cornerAt(x, y) {
        if (!CircleSearch.box || CircleSearch.pickKind === "words")
            return -1;
        const r = win(CircleSearch.box), reach = Math.max(18, u * 7);
        const pts = [[r.x, r.y], [r.x + r.width, r.y], [r.x + r.width, r.y + r.height], [r.x, r.y + r.height]];
        for (let i = 0; i < 4; i++)
            if (Math.abs(x - pts[i][0]) < reach && Math.abs(y - pts[i][1]) < reach)
                return i;
        const inX = x > r.x && x < r.x + r.width, inY = y > r.y && y < r.y + r.height, side = Math.max(10, u * 4);
        if (inX && Math.abs(y - r.y) < side)
            return 4;
        if (inY && Math.abs(x - r.x - r.width) < side)
            return 5;
        if (inX && Math.abs(y - r.y - r.height) < side)
            return 6;
        if (inY && Math.abs(x - r.x) < side)
            return 7;
        return inX && inY ? 8 : -1;
    }
    function gripCursor(g) {
        return g === 0 || g === 2 ? Qt.SizeFDiagCursor : g === 1 || g === 3 ? Qt.SizeBDiagCursor : g === 4 || g === 6 ? Qt.SizeVerCursor : g === 5 || g === 7 ? Qt.SizeHorCursor : Qt.SizeAllCursor;
    }
    function press(x, y, button, mods) {
        if (button === Qt.RightButton) {
            key("Escape");
            return;
        }
        at = Qt.point(x / k, y / k);
        travel = 0;
        fresh = true;
        textTo = -1;
        corner = cornerAt(x, y);
        if (corner >= 0) {
            // (inside the frame it only moves once the pointer travels: a tap there stays a tap)
            adjust = corner === 8 ? null : CircleSearch.box;
            grabbed = at;
            return;
        }
        drawMode = (mods & Qt.ShiftModifier) ? "rect" : CircleSearch.mode;
        textFrom = drawMode === "text" ? CircleSearch.wordIndexAt(x / k, y / k) : -1;
        stroke = [Qt.point(x, y)];
        drawing = true;
    }
    function move(x, y) {
        at = Qt.point(x / k, y / k);
        if (corner >= 0) {
            const b = CircleSearch.box, fx = Math.max(0, Math.min(CircleSearch.frameW, x / k)), fy = Math.max(0, Math.min(CircleSearch.frameH, y / k));
            if (corner === 8) {
                // the whole frame, kept on the screen
                if (!adjust && Math.hypot(fx - grabbed.x, fy - grabbed.y) * k < 6)
                    return;
                adjust = {
                    "x": Math.max(0, Math.min(CircleSearch.frameW - b.w, b.x + fx - grabbed.x)),
                    "y": Math.max(0, Math.min(CircleSearch.frameH - b.h, b.y + fy - grabbed.y)),
                    "w": b.w,
                    "h": b.h
                };
            } else if (corner >= 4) {
                // one side; the others stay
                let x0 = b.x, y0 = b.y, x1 = b.x + b.w, y1 = b.y + b.h;
                if (corner === 4)
                    y0 = fy;
                else if (corner === 5)
                    x1 = fx;
                else if (corner === 6)
                    y1 = fy;
                else
                    x0 = fx;
                adjust = {
                    "x": Math.min(x0, x1),
                    "y": Math.min(y0, y1),
                    "w": Math.abs(x1 - x0),
                    "h": Math.abs(y1 - y0)
                };
            } else {
                // the opposite corner stays
                const ox = corner === 0 || corner === 3 ? b.x + b.w : b.x, oy = corner < 2 ? b.y + b.h : b.y;
                adjust = {
                    "x": Math.min(fx, ox),
                    "y": Math.min(fy, oy),
                    "w": Math.abs(fx - ox),
                    "h": Math.abs(fy - oy)
                };
            }
            return;
        }
        if (!drawing)
            return;
        const last = stroke[stroke.length - 1];
        const d = Math.hypot(x - last.x, y - last.y);
        if (d < 3)
            return;
        travel += d;
        stroke = stroke.concat([Qt.point(x, y)]);
        if (drawMode === "text" && textFrom >= 0 && travel >= 6) {
            const b = CircleSearch.wordNear(x / k, y / k);
            // the pick changes only when the word under the pointer does
            if (b >= 0 && b !== textTo) {
                textTo = b;
                CircleSearch.selectWords(textFrom, b);
            }
        }
    }
    function release(x, y) {
        up = Qt.point(x, y);
        if (corner >= 0) {
            const how = CircleSearch.pickKind === "region" || CircleSearch.pickKind === "line" ? "rect" : CircleSearch.pickKind;
            const r = adjust, g = corner;
            corner = -1;
            adjust = null;
            if (g === 8 && !r)
                CircleSearch.tapAt(x / k, y / k);
            else if (r && r.w >= 4 && r.h >= 4)
                CircleSearch.adjustTo(r, how === "loop" ? "rect" : how);
            return;
        }
        if (!drawing)
            return;
        drawing = false;
        const a = stroke[0];
        const r = {
            "x": Math.min(a.x, x) / k,
            "y": Math.min(a.y, y) / k,
            "w": Math.abs(x - a.x) / k,
            "h": Math.abs(y - a.y) / k
        };
        if (travel < 14)
            CircleSearch.tapAt(x / k, y / k);
        else if (drawMode === "rect" || drawMode === "auto" && lineLike(stroke))
            CircleSearch.pickRect(r, "rect");
        else if (drawMode === "text") {
            if (textFrom < 0)
                CircleSearch.selectWordsIn(r);
        } else
            CircleSearch.pickLoop(stroke.map(p => ({
                        "x": p.x / k,
                        "y": p.y / k
                    })));
        stroke = [];
    }

    opacity: CircleSearch.open ? 1 : 0
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation {
                duration: canvas.leaving === "shot" ? 300 : 0
            }
            NumberAnimation {
                duration: 170
                easing.type: Easing.InCubic
            }
        }
    }
    Connections {
        target: CircleSearch
        function onShot(rect) {
            canvas.shotRect = rect;
            canvas.leaving = "shot";
            shutter.restart();
        }
        function onOpenChanged() {
            if (CircleSearch.open) {
                canvas.leaving = "";
                canvas.windowPreview = false;
                canvas.fresh = true;
                bar.glide = false;
                Qt.callLater(canvas.relayout);
            }
        }
        function onBoxChanged() {
            Qt.callLater(canvas.relayout);
            if (CircleSearch.box)
                pop.restart();
        }
    }

    Image {
        id: snap
        anchors.fill: parent
        source: CircleSearch.frameUrl
        cache: true
        smooth: false
        fillMode: Image.Stretch
        onStatusChanged: {
            if (status === Image.Ready && CircleSearch.frameW <= 1) {
                CircleSearch.frameW = implicitWidth;
                CircleSearch.frameH = implicitHeight;
            }
        }
    }

    // the dim: everywhere but the pick
    property real shown: 0
    NumberAnimation on shown {
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }
    property real dash: 0
    NumberAnimation on dash {
        from: 0
        to: 6
        duration: 400
        loops: Animation.Infinite
        running: canvas.line.length > 1
    }
    // the hole in the dim (window pixels, closed): a rectangle being drawn or dragged, else the pick's shape
    readonly property var hole: {
        const kind = CircleSearch.pickKind, s = stroke, last = s.length ? s[s.length - 1] : null;
        const box = r => [Qt.point(r.x, r.y), Qt.point(r.x + r.width, r.y), Qt.point(r.x + r.width, r.y + r.height), Qt.point(r.x, r.y + r.height), Qt.point(r.x, r.y)];
        if (corner >= 0 && adjust)
            return box(win(adjust));
        if (drawing && (drawMode === "rect" || drawMode === "auto" && lineLike(s)) && s.length > 1)
            return box(Qt.rect(Math.min(s[0].x, last.x), Math.min(s[0].y, last.y), Math.abs(last.x - s[0].x), Math.abs(last.y - s[0].y)));
        if (drawing)
            return [];
        if (kind === "loop" && CircleSearch.poly.length > 2) {
            const p = CircleSearch.poly.map(q => Qt.point(q.x * k, q.y * k));
            return p.concat([p[0]]);
        }
        if (kind === "rect" || kind === "region" || kind === "line") {
            const p = kind === "line" ? u * 3 : 0, r = win(CircleSearch.box);
            return box(Qt.rect(r.x - p, r.y - p, r.width + p * 2, r.height + p * 2));
        }
        return [];
    }
    // the loop's line, in pixel steps on the grid: the stroke while a loop is drawn, else the loop picked
    readonly property var line: {
        const src = drawing ? (drawMode !== "rect" && drawMode !== "text" ? stroke : []) : CircleSearch.pickKind === "loop" && !(corner >= 0 && adjust) ? hole : [];
        return src.length > 1 ? src.map(p => Qt.point(Math.round(p.x / u) * u, Math.round(p.y / u) * u)) : [];
    }
    // the dim and the line are Shapes: the GPU draws them (a screen-sized Canvas was painted by
    // the CPU and uploaded again on every move)
    Shape {
        anchors.fill: parent
        ShapePath {
            fillColor: Qt.rgba(0, 0, 0, (canvas.hole.length ? 0.5 : CircleSearch.pickKind === "words" ? 0.32 : 0.24) * canvas.shown)
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathMultiline {
                paths: [[Qt.point(0, 0), Qt.point(canvas.width, 0), Qt.point(canvas.width, canvas.height), Qt.point(0, canvas.height), Qt.point(0, 0)]].concat(canvas.hole.length ? [canvas.hole] : [])
            }
        }
    }
    Shape {
        anchors.fill: parent
        visible: canvas.line.length > 1
        asynchronous: true
        ShapePath {
            strokeWidth: canvas.u * 5
            strokeColor: Qt.rgba(1, 1, 1, 0.18)
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: canvas.line
            }
        }
        ShapePath {
            strokeWidth: canvas.u * 2
            strokeColor: Theme.edge
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: canvas.line
            }
        }
        ShapePath {
            strokeWidth: canvas.u
            strokeColor: "white"
            fillColor: "transparent"
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: canvas.line
            }
        }
        // marching dashes (the pattern is in line widths: 2 px on, 4 off)
        ShapePath {
            strokeWidth: canvas.u
            strokeColor: Theme.accent
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [2 / canvas.u, 4 / canvas.u]
            dashOffset: -canvas.dash / canvas.u
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            PathPolyline {
                path: canvas.line
            }
        }
    }

    // while the screen is read: a soft light sweeps down it (Pixel's shimmer)
    Rectangle {
        id: sweep
        visible: (CircleSearch.reading || CircleSearch.finding) && !canvas.drawing && CircleSearch.open
        width: parent.width
        height: canvas.height * 0.18
        opacity: 0.55
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.8
                color: Qt.alpha(Theme.accent, 0.24)
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
        NumberAnimation on y {
            running: sweep.visible
            from: -sweep.height
            to: canvas.height
            duration: 1400
            loops: Animation.Infinite
            easing.type: Easing.InOutSine
        }
    }

    // the areas found: faint until the pointer is over one, then its frame and its kind
    Repeater {
        id: areas
        model: CircleSearch.regions
        Rectangle {
            id: area
            required property var modelData
            required property int index
            readonly property bool hot: !!canvas.hovered && canvas.hovered.x === modelData.x && canvas.hovered.y === modelData.y && canvas.hovered.w === modelData.w && canvas.hovered.h === modelData.h
            property real appear: 0
            SequentialAnimation on appear {
                PauseAnimation {
                    duration: Math.min(area.index, 20) * 28
                }
                NumberAnimation {
                    to: 1
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            visible: !canvas.drawing && !CircleSearch.box && CircleSearch.mode !== "text" && canvas.corner < 0
            x: Math.round(modelData.x * canvas.k)
            y: Math.round(modelData.y * canvas.k)
            width: Math.round(modelData.w * canvas.k)
            height: Math.round(modelData.h * canvas.k)
            opacity: appear
            scale: 0.97 + 0.03 * appear
            radius: Theme.macLook ? canvas.u * 3 : 0
            color: hot ? Qt.alpha(Theme.accent, 0.14) : Qt.alpha(Theme.accent, 0.04)
            border.width: hot ? Math.max(2, canvas.u) : Math.max(1, canvas.u / 2)
            border.color: hot ? Qt.alpha("white", 0.95) : Qt.alpha(Theme.accent, 0.5)
            Behavior on color {
                ColorAnimation {
                    duration: 110
                }
            }
            PxBox {
                visible: area.hot
                x: canvas.u * 2
                y: area.height > height * 3 ? canvas.u * 2 : -height - canvas.u
                width: kindText.implicitWidth + Theme.pad * 2
                height: kindText.implicitHeight + canvas.u * 3
                PxText {
                    id: kindText
                    anchors.centerIn: parent
                    kind: "tiny"
                    readonly property string what: ({
                            "window": I18n.t("Окно", "Window"),
                            "image": I18n.t("Картинка", "Picture"),
                            "text": I18n.t("Текст", "Text"),
                            "ui": I18n.t("Элемент", "Element")
                        })[area.modelData.kind] || I18n.t("Область", "Area")
                    text: what + (area.modelData.label ? " · " + String(area.modelData.label).slice(0, 40) : "")
                }
            }
        }
    }

    // Live Text: every word found (faint; clearer in text mode), the picked ones filled
    Repeater {
        id: wordMarks
        model: CircleSearch.words
        Rectangle {
            id: mark
            required property var modelData
            readonly property bool on: !!CircleSearch.pickedKeys[modelData.x + "," + modelData.y]
            readonly property bool textMode: CircleSearch.mode === "text"
            x: Math.round(modelData.x * canvas.k) - canvas.u
            y: Math.round(modelData.y * canvas.k) - canvas.u
            width: Math.round(modelData.w * canvas.k) + canvas.u * 2
            height: Math.round(modelData.h * canvas.k) + canvas.u * 2
            radius: Theme.macLook ? canvas.u : 0
            color: on ? Qt.alpha(Theme.accent, 0.34) : textMode ? Qt.alpha(Theme.accent2, 0.12) : "transparent"
            border.width: Math.max(1, canvas.u / 2)
            border.color: Qt.alpha(on ? Theme.accent : Theme.accent2, on ? 0.95 : textMode ? 0.55 : 0.3)
            visible: !(canvas.drawing && canvas.drawMode !== "text")
            opacity: 0
            NumberAnimation on opacity {
                to: 1
                duration: 260
            }
        }
    }

    // the pick: four corners (drag one to change it), popping in
    Item {
        id: pick
        readonly property rect r: canvas.win(canvas.adjust || CircleSearch.box)
        visible: (!!CircleSearch.box && CircleSearch.pickKind !== "words" && !canvas.drawing) || canvas.corner >= 0
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        NumberAnimation on scale {
            id: pop
            from: 1.05
            to: 1
            duration: 200
            easing.type: Easing.OutBack
        }
        Repeater {
            model: 4
            Item {
                id: cornerMark
                required property int index
                readonly property int arm: Math.min(Math.max(canvas.u * 8, 14), pick.width / 2, pick.height / 2)
                readonly property int thick: Math.max(3, canvas.u * 2)
                x: index === 1 || index === 2 ? pick.width - arm : 0
                y: index >= 2 ? pick.height - arm : 0
                width: arm
                height: arm
                Rectangle {
                    color: "white"
                    width: cornerMark.arm
                    height: cornerMark.thick
                    y: cornerMark.index >= 2 ? cornerMark.arm - height : 0
                    border.width: 1
                    border.color: Qt.alpha("black", 0.35)
                }
                Rectangle {
                    color: "white"
                    width: cornerMark.thick
                    height: cornerMark.arm
                    x: cornerMark.index === 1 || cornerMark.index === 2 ? cornerMark.arm - width : 0
                    border.width: 1
                    border.color: Qt.alpha("black", 0.35)
                }
            }
        }
    }

    // the sides' grips: a short bar in the middle of each (drag one to move that side)
    Repeater {
        model: 4
        Rectangle {
            required property int index
            readonly property bool across: index === 0 || index === 2
            readonly property int len: Math.min(Math.max(canvas.u * 10, 18), (across ? pick.width : pick.height) / 3)
            readonly property int thick: Math.max(3, canvas.u * 2)
            visible: pick.visible && pick.width > canvas.u * 30 && pick.height > canvas.u * 30
            width: across ? len : thick
            height: across ? thick : len
            x: pick.x + (across ? (pick.width - len) / 2 : index === 1 ? pick.width - thick : 0)
            y: pick.y + (across ? (index === 2 ? pick.height - thick : 0) : (pick.height - len) / 2)
            color: "white"
            border.width: 1
            border.color: Qt.alpha("black", 0.35)
        }
    }

    // the window under the pointer by its edge (a tap there takes it) that no area stands for: lit
    Rectangle {
        readonly property var w: canvas.hovered && !canvas.hovered.kind ? canvas.hovered : null
        readonly property rect r: canvas.win(w)
        visible: !!w
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        color: Qt.alpha(Theme.accent, 0.14)
        border.width: Math.max(2, canvas.u)
        border.color: Qt.alpha("white", 0.95)
    }

    // "Window": the window it will take, outlined while the pointer is on the button
    Rectangle {
        readonly property rect r: canvas.win(canvas.target)
        visible: canvas.windowPreview
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        color: Qt.alpha(Theme.accent, 0.10)
        border.width: Math.max(2, canvas.u)
        border.color: "white"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        // from canvas.at (once a frame), not mouseX (every move of the mouse)
        cursorShape: {
            const g = canvas.corner >= 0 ? canvas.corner : canvas.cornerAt(canvas.at.x * canvas.k, canvas.at.y * canvas.k);
            return g >= 0 && (canvas.corner >= 0 || g < 8) ? canvas.gripCursor(g) : CircleSearch.mode === "text" && CircleSearch.wordIndexAt(canvas.at.x, canvas.at.y) >= 0 ? Qt.IBeamCursor : canvas.hovered ? Qt.PointingHandCursor : Qt.CrossCursor;
        }
        onPressed: m => {
            canvas.flush();
            canvas.press(m.x, m.y, m.button, m.modifiers);
        }
        onPositionChanged: m => {
            canvas.px = m.x;
            canvas.py = m.y;
            canvas.dirty = true;
        }
        onReleased: m => {
            canvas.flush();
            canvas.release(m.x, m.y);
        }
    }
    function flush() {
        if (dirty) {
            dirty = false;
            move(px, py);
        }
    }
    FrameAnimation {
        running: canvas.dirty
        onTriggered: canvas.flush()
    }

    // the modes and what to do, at the top
    PxBox {
        id: modeBox
        visible: !canvas.drawing && canvas.leaving === ""
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(canvas.width - canvas.u * 8, Math.max(modes.implicitWidth, hintText.implicitWidth) + Theme.pad * 2)
        height: modeCol.implicitHeight + Theme.pad * 2
        shadow: true
        y: Theme.u * 10
        NumberAnimation on y {
            from: -Theme.u * 40
            to: Theme.u * 10
            duration: 320
            easing.type: Easing.OutCubic
        }
        Column {
            id: modeCol
            x: Theme.pad
            y: Theme.pad
            width: parent.width - Theme.pad * 2
            spacing: Theme.u * 2
            Row {
                id: modes
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.u * 2
                Repeater {
                    model: [
                        {
                            "id": "auto",
                            "icon": "cursor",
                            "label": I18n.t("Обвести", "Circle")
                        },
                        {
                            "id": "rect",
                            "icon": "maximize",
                            "label": I18n.t("Рамка", "Rectangle")
                        },
                        {
                            "id": "text",
                            "icon": "document",
                            "label": I18n.t("Текст", "Text")
                        }
                    ]
                    PxButton {
                        required property var modelData
                        objectName: "mode-" + modelData.id
                        compact: true
                        checkable: true
                        checked: CircleSearch.mode === modelData.id
                        icon: modelData.icon
                        text: modelData.label
                        onClicked: CircleSearch.setMode(modelData.id)
                    }
                }
            }
            PxText {
                id: hintText
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, modeCol.width)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                kind: "tiny"
                dim: true
                text: CircleSearch.error === "tesseract" ? I18n.t("Нужен tesseract — без него текст не прочитать", "Needs tesseract to read text") : (CircleSearch.mode === "text" ? I18n.t("Нажмите на слово или проведите по словам · Ctrl+A — весь текст", "Tap a word or drag over words · Ctrl+A for all") : CircleSearch.mode === "rect" ? I18n.t("Тяните рамку или нажмите на область", "Drag a rectangle or tap an area") : I18n.t("Нажмите на область или строку · тяните рамку · обведите", "Tap an area or a line · drag a rectangle · circle it")) + (CircleSearch.reading ? I18n.t(" · читаю экран…", " · reading the screen…") : CircleSearch.box ? (CircleSearch.textPick && CircleSearch.hasText ? I18n.t(" · Ctrl+C — копировать текст", " · Ctrl+C copies the text") : I18n.t(" · Ctrl+C — копировать картинку", " · Ctrl+C copies the picture")) + I18n.t(" · Enter — сохранить выделенное · Esc — снять", " · Enter saves the pick · Esc lets go") : I18n.t(" · Enter — сохранить экран · Esc — закрыть", " · Enter saves the screen · Esc closes"))
            }
        }
    }

    // the text of the pick (or its translation), at the pick
    PxBox {
        id: card
        readonly property bool wanted: CircleSearch.hasText || CircleSearch.translating || CircleSearch.translation !== "" || CircleSearch.translateError !== "" || (!!CircleSearch.box && CircleSearch.pickBusy)
        visible: wanted && !canvas.drawing && canvas.corner < 0 && canvas.leaving === ""
        shadow: true
        readonly property rect b: canvas.win(CircleSearch.box)
        width: Math.min(canvas.width - canvas.u * 8, Math.max(canvas.u * 150, Math.min(canvas.u * 260, b.width)))
        height: cardCol.implicitHeight + Theme.pad * 2
        property point at                    // canvas.layout(): the other side of the pick from the bar
        onWantedChanged: Qt.callLater(canvas.relayout)
        onHeightChanged: Qt.callLater(canvas.relayout)
        onWidthChanged: Qt.callLater(canvas.relayout)
        x: at.x
        y: at.y
        Behavior on x {
            enabled: bar.glide
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: bar.glide
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Column {
            id: cardCol
            x: Theme.pad
            y: Theme.pad
            width: parent.width - Theme.pad * 2
            spacing: Theme.u * 3
            PxText {
                visible: !CircleSearch.hasText && CircleSearch.pickBusy
                dim: true
                text: I18n.t("Читаю…", "Reading…")
            }
            PxTextArea {
                id: editor
                visible: CircleSearch.hasText
                width: parent.width
                height: Math.min(canvas.u * 80, Math.max(canvas.u * 18, input.contentHeight + canvas.u * 12))
                spell: false
                text: CircleSearch.text
                onTextChanged: if (text !== CircleSearch.text)
                    CircleSearch.text = text
            }
            PxText {
                visible: CircleSearch.translating || CircleSearch.translation !== "" || CircleSearch.translateError !== ""
                width: parent.width
                wrapMode: Text.Wrap
                dim: CircleSearch.translating || CircleSearch.translateError !== ""
                text: CircleSearch.translating ? I18n.t("Перевожу…", "Translating…") : CircleSearch.translateError || CircleSearch.translation
            }
            // the links in it, each its own chip; the translation's own copy button
            Flow {
                visible: CircleSearch.links.length > 0 && CircleSearch.kind === "text" || CircleSearch.translation !== ""
                width: parent.width
                spacing: Theme.u * 2
                Repeater {
                    model: CircleSearch.kind === "text" ? CircleSearch.links : []
                    PxButton {
                        required property var modelData
                        compact: true
                        icon: modelData.kind === "mail" ? "chat" : modelData.kind === "phone" ? "phone" : "window"
                        text: modelData.text.length > 34 ? modelData.text.slice(0, 33) + "…" : modelData.text
                        onClicked: CircleSearch.openLink(modelData)
                    }
                }
                PxButton {
                    objectName: "act-copy-translation"
                    visible: CircleSearch.translation !== ""
                    compact: true
                    icon: "document"
                    text: I18n.t("Копировать перевод", "Copy translation")
                    onClicked: {
                        CircleSearch.copy(CircleSearch.translation);
                        CircleSearch.close();
                    }
                }
            }
        }
    }

    // the actions, Pixel's bar: at the bottom with nothing picked (the whole screen), else by the
    // pick where the pointer let go, the likeliest action first, the rest behind "More"
    PxBox {
        id: bar
        visible: !canvas.drawing && !canvas.adjust && canvas.leaving === ""
        shadow: true
        property point at                    // canvas.layout(): by the pick, its first button at the pointer
        property bool rtl: false             // the bar ends at the pointer (no room to its right)
        property bool glide: false           // moved while shown: a short glide; back after a drag: in place
        onWidthChanged: Qt.callLater(canvas.relayout)
        onHeightChanged: Qt.callLater(canvas.relayout)
        onVisibleChanged: if (visible)
            appear.restart()
        x: at.x
        Behavior on x {
            enabled: bar.glide
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: bar.glide
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        NumberAnimation on scale {
            id: appear
            from: 0.94
            to: 1
            duration: 140
            easing.type: Easing.OutCubic
        }
        property bool more: false
        readonly property bool textFirst: CircleSearch.textPick && CircleSearch.hasText || CircleSearch.kind !== "text"
        readonly property var order: !CircleSearch.box ? ["save", "copy", "text", "search", "lens", "translate", "share", "full", "window"] : CircleSearch.kind !== "text" ? ["search", "text", "translate", "more", "save", "copy", "lens", "share", "full", "window"] : textFirst ? ["text", "search", "translate", "more", "save", "copy", "lens", "share", "full", "window"] : ["save", "copy", Config.circle.lens ? "lens" : "search"].concat(CircleSearch.hasText ? ["text"] : [], ["more", Config.circle.lens ? "search" : "lens", "translate", "share", "full", "window"])
        readonly property int fold: order.indexOf("more")    // -1: everything shown
        onOrderChanged: more = false
        readonly property var acts: {
            const behind = id => fold >= 0 && !more && order.indexOf(id) > fold;
            const t = CircleSearch.hasText || CircleSearch.words.length > 0;
            return {
                "save": {
                    "icon": "camera",
                    "text": I18n.t("Сохранить", "Save"),
                    "on": true,
                    "shown": !behind("save"),
                    "run": () => CircleSearch.save()
                },
                "copy": {
                    "icon": "image",
                    "text": I18n.t("Копировать", "Copy"),
                    "on": true,
                    "shown": !behind("copy"),
                    "run": () => CircleSearch.copyShot()
                },
                "text": {
                    "icon": "document",
                    "text": CircleSearch.hasText ? I18n.t("Копировать текст", "Copy text") : I18n.t("Копировать весь текст", "Copy all the text"),
                    "on": t,
                    "shown": !behind("text"),
                    "run": () => CircleSearch.copyText()
                },
                "search": {
                    "icon": CircleSearch.kind === "text" ? "search" : "window",
                    "text": CircleSearch.kind === "text" ? I18n.t("Найти", "Search") : I18n.t("Открыть", "Open"),
                    "on": CircleSearch.hasText || !!CircleSearch.box,
                    "shown": !behind("search"),
                    "run": () => CircleSearch.search()
                },
                // only a pick goes to Google: the whole screen may have private messages on it
                "lens": {
                    "icon": "eye",
                    "text": I18n.t("Найти картинкой", "Search the picture"),
                    "on": !!CircleSearch.box,
                    "shown": Config.circle.lens && !behind("lens"),
                    "run": () => CircleSearch.searchPicture()
                },
                "translate": {
                    "icon": "chat",
                    "text": CircleSearch.hasText ? I18n.t("Перевести", "Translate") : I18n.t("Перевести всё", "Translate all"),
                    "on": t && !CircleSearch.translating,
                    "shown": !behind("translate"),
                    "run": () => CircleSearch.translate()
                },
                "share": {
                    "icon": "plane",
                    "text": I18n.t("Отправить рядом", "Send nearby"),
                    "on": true,
                    "shown": Config.quickshare.enabled && !behind("share"),
                    "run": () => CircleSearch.shareNearby()
                },
                "full": {
                    "icon": "monitor",
                    "text": I18n.t("Сохранить экран", "Save the screen"),
                    "on": true,
                    "shown": !behind("full"),
                    "run": () => CircleSearch.saveFull()
                },
                "window": {
                    "icon": "window",
                    "text": I18n.t("Сохранить окно", "Save the window"),
                    "on": CircleSearch.windowsHere.length > 0,
                    "shown": !behind("window"),
                    "run": () => CircleSearch.saveWindow(canvas.at.x, canvas.at.y)
                },
                "more": {
                    "icon": "plus",
                    "text": I18n.t("Ещё", "More"),
                    "on": true,
                    "shown": !more,
                    "run": () => bar.more = true
                }
            };
        }
        readonly property real natural: {
            let s = 0, n = 0;
            for (const c of buttons.children)
                if (c.visible && c.implicitWidth > 0) {
                    s += c.implicitWidth;
                    n++;
                }
            return s + Math.max(0, n - 1) * buttons.spacing;
        }
        readonly property real widest: {
            let w = 0;
            for (const c of buttons.children)
                if (c.visible)
                    w = Math.max(w, c.implicitWidth);
            return w;
        }
        // too long for one row: rows of about the same length, not a full one and a stub
        // the box's own edge (PxBox.inset) is inside its width too
        readonly property real avail: canvas.width - canvas.u * 8 - Theme.pad * 2 - inset * 2 - 2
        readonly property int rows: Math.max(1, Math.ceil(natural / Math.max(1, avail)))
        width: (rows === 1 ? natural : Math.min(avail, natural / rows + widest)) + Theme.pad * 2 + inset * 2 + 2
        height: buttons.implicitHeight + Theme.pad * 2 + inset * 2
        y: at.y + (1 - canvas.shown) * canvas.u * 30
        opacity: canvas.shown

        Flow {
            id: buttons
            layoutDirection: bar.rtl ? Qt.RightToLeft : Qt.LeftToRight
            x: Theme.pad
            y: Theme.pad
            width: parent.width - Theme.pad * 2
            spacing: Theme.u * 2
            Repeater {
                model: bar.order
                PxButton {
                    required property string modelData
                    required property int index
                    readonly property var a: bar.acts[modelData]
                    objectName: "act-" + modelData
                    visible: a.shown
                    compact: true
                    accent: index === 0 && modelData !== "more"
                    icon: a.icon
                    text: a.text
                    enabled: a.on
                    onHoveredChanged: if (modelData === "window")
                        canvas.windowPreview = hovered
                    onClicked: a.run()
                }
            }
        }
    }

    // a picture taken: a flash, then the piece shrinks into the corner
    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0
    }
    Item {
        id: thumb
        readonly property rect r: canvas.win(canvas.shotRect)
        visible: canvas.leaving === "shot"
        clip: true
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        transformOrigin: Item.BottomRight
        Image {
            x: -thumb.r.x
            y: -thumb.r.y
            width: canvas.width
            height: canvas.height
            source: CircleSearch.frameUrl
            cache: true
            smooth: true
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: Math.max(2, canvas.u)
            border.color: "white"
        }
    }
    ParallelAnimation {
        id: shutter
        SequentialAnimation {
            NumberAnimation {
                target: flash
                property: "opacity"
                from: 0
                // a soft one; none in calm motion or on stream (viewers see it full screen)
                to: Motion.calm || StreamMode.active ? 0 : 0.2
                duration: 60
            }
            NumberAnimation {
                target: flash
                property: "opacity"
                to: 0
                duration: 220
            }
        }
        NumberAnimation {
            target: thumb
            property: "scale"
            from: 1
            to: Math.min(0.3, canvas.width * 0.22 / Math.max(1, thumb.width))
            duration: 420
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: thumb
            property: "x"
            from: thumb.r.x
            to: canvas.width - thumb.width - canvas.u * 12
            duration: 420
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: thumb
            property: "y"
            from: thumb.r.y
            to: canvas.height - thumb.height - canvas.u * 12
            duration: 420
            easing.type: Easing.InOutCubic
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: canvas.key("Escape")
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: !canvas.editing
        onActivated: canvas.key("Enter")
    }
    Shortcut {
        sequences: ["Ctrl+Return", "Ctrl+Enter"]
        onActivated: canvas.key("Ctrl+Enter")
    }
    Shortcut {
        sequence: "Ctrl+C"
        enabled: !canvas.editing
        onActivated: canvas.key("Ctrl+C")
    }
    Shortcut {
        sequence: "Ctrl+S"
        onActivated: canvas.key("Ctrl+S")
    }
    Shortcut {
        sequence: "Ctrl+A"
        enabled: !canvas.editing
        onActivated: canvas.key("Ctrl+A")
    }
    Shortcut {
        sequence: "Tab"
        enabled: !canvas.editing
        onActivated: canvas.key("Tab")
    }
}
