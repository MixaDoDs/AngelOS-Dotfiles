pragma ComponentBehavior: Bound

import QtQuick
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
    // the area under the pointer (a window by its edge): what a tap takes
    readonly property var hovered: !drawing && !CircleSearch.box && at.x >= 0 && CircleSearch.mode !== "text" ? CircleSearch.areaAt(at.x, at.y) : null
    readonly property var target: windowPreview ? CircleSearch.targetWindow(at.x, at.y) : null
    readonly property bool editing: editor.input.activeFocus
    readonly property alias bar: bar
    readonly property alias card: card
    readonly property alias modeBox: modeBox

    function win(r) {   // a frame rect in window pixels
        return r ? Qt.rect(r.x * k, r.y * k, r.w * k, r.h * k) : Qt.rect(0, 0, width, height);
    }

    // ---- the keys (CircleOverlay's shortcuts and the test call this)
    function key(name) {
        switch (name) {
        case "Escape":
            if (drawing || corner >= 0) {
                drawing = false;
                corner = -1;
                adjust = null;
                stroke = [];
                veil.requestPaint();
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
        veil.requestPaint();
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
            veil.requestPaint();
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
            if (b >= 0)
                CircleSearch.selectWords(textFrom, b);
        }
        veil.requestPaint();
    }
    function release(x, y) {
        if (corner >= 0) {
            const how = CircleSearch.pickKind === "region" || CircleSearch.pickKind === "line" ? "rect" : CircleSearch.pickKind;
            const r = adjust, g = corner;
            corner = -1;
            adjust = null;
            if (g === 8 && !r)
                CircleSearch.tapAt(x / k, y / k);
            else if (r && r.w >= 4 && r.h >= 4)
                CircleSearch.adjustTo(r, how === "loop" ? "rect" : how);
            veil.requestPaint();
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
        else if (drawMode === "rect")
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
        veil.requestPaint();
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
            }
        }
        function onPolyChanged() {
            veil.requestPaint();
        }
        function onBoxChanged() {
            veil.requestPaint();
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
    onShownChanged: veil.requestPaint()
    property real dash: 0
    NumberAnimation on dash {
        from: 0
        to: 6
        duration: 400
        loops: Animation.Infinite
        running: canvas.drawing || CircleSearch.pickKind === "loop"
    }
    onDashChanged: veil.requestPaint()
    onWidthChanged: veil.requestPaint()
    Canvas {
        id: veil
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const kind = CircleSearch.pickKind, k = canvas.k;
            const s = canvas.stroke, last = s.length ? s[s.length - 1] : null;
            // the hole: a rectangle being drawn or dragged, else the pick's shape
            let hole = null, loop = null;
            if (canvas.corner >= 0 && canvas.adjust)
                hole = canvas.win(canvas.adjust);
            else if (canvas.drawing && canvas.drawMode === "rect" && s.length > 1)
                hole = Qt.rect(Math.min(s[0].x, last.x), Math.min(s[0].y, last.y), Math.abs(last.x - s[0].x), Math.abs(last.y - s[0].y));
            else if (canvas.drawing)
                loop = null;
            else if (kind === "loop" && CircleSearch.poly.length > 2)
                loop = CircleSearch.poly.map(p => Qt.point(p.x * k, p.y * k));
            else if (kind === "rect" || kind === "region" || kind === "line") {
                const p = kind === "line" ? canvas.u * 3 : 0;
                const r = canvas.win(CircleSearch.box);
                hole = Qt.rect(r.x - p, r.y - p, r.width + p * 2, r.height + p * 2);
            }
            ctx.fillStyle = Qt.rgba(0, 0, 0, (hole || loop ? 0.5 : kind === "words" ? 0.32 : 0.24) * canvas.shown);
            ctx.beginPath();
            ctx.rect(0, 0, width, height);
            if (hole) {
                // the other way round: the hole stays clear (non-zero fill)
                ctx.moveTo(hole.x, hole.y);
                ctx.lineTo(hole.x, hole.y + hole.height);
                ctx.lineTo(hole.x + hole.width, hole.y + hole.height);
                ctx.lineTo(hole.x + hole.width, hole.y);
                ctx.closePath();
            } else if (loop) {
                ctx.moveTo(loop[0].x, loop[0].y);
                for (let i = loop.length - 1; i >= 0; i--)
                    ctx.lineTo(loop[i].x, loop[i].y);
                ctx.closePath();
            }
            ctx.fill();
            // the loop's line: pixel steps on the grid, square ends, marching dashes
            const line = canvas.drawing && canvas.drawMode !== "rect" && canvas.drawMode !== "text" ? s : loop;
            if (!line || line.length < 2)
                return;
            const g = canvas.u;
            const snapTo = v => Math.round(v / g) * g;
            ctx.lineCap = "square";
            ctx.lineJoin = "miter";
            ctx.beginPath();
            ctx.moveTo(snapTo(line[0].x), snapTo(line[0].y));
            for (let i = 1; i < line.length; i++)
                ctx.lineTo(snapTo(line[i].x), snapTo(line[i].y));
            if (!canvas.drawing)
                ctx.closePath();
            ctx.lineWidth = g * 5;
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.18);
            ctx.setLineDash([]);
            ctx.stroke();
            ctx.lineWidth = g * 2;
            ctx.strokeStyle = Theme.edge;
            ctx.stroke();
            ctx.lineWidth = g;
            ctx.strokeStyle = "white";
            ctx.stroke();
            ctx.strokeStyle = Theme.accent;
            ctx.setLineDash([2, 4]);
            ctx.lineDashOffset = -canvas.dash;
            ctx.stroke();
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
            readonly property bool on: CircleSearch.picked.some(w => w.x === modelData.x && w.y === modelData.y)
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
        cursorShape: canvas.corner >= 0 ? canvas.gripCursor(canvas.corner) : canvas.cornerAt(mouseX, mouseY) >= 0 && canvas.cornerAt(mouseX, mouseY) < 8 ? canvas.gripCursor(canvas.cornerAt(mouseX, mouseY)) : CircleSearch.mode === "text" && CircleSearch.wordIndexAt(canvas.at.x, canvas.at.y) >= 0 ? Qt.IBeamCursor : canvas.hovered ? Qt.PointingHandCursor : Qt.CrossCursor
        onPressed: m => canvas.press(m.x, m.y, m.button, m.modifiers)
        onPositionChanged: m => canvas.move(m.x, m.y)
        onReleased: m => canvas.release(m.x, m.y)
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
                text: CircleSearch.error === "tesseract" ? I18n.t("Нужен tesseract — без него текст не прочитать", "Needs tesseract to read text") : (CircleSearch.mode === "text" ? I18n.t("Нажмите на слово или проведите по словам · Ctrl+A — весь текст", "Tap a word or drag over words · Ctrl+A for all") : CircleSearch.mode === "rect" ? I18n.t("Тяните рамку или нажмите на область", "Drag a rectangle or tap an area") : I18n.t("Область, строка или пустое место · край окна — окно · обведите", "An area, a line or an empty place · a window's edge: the window · circle it")) + (CircleSearch.reading ? I18n.t(" · читаю экран…", " · reading the screen…") : I18n.t(" · Enter — сохранить · Esc — назад", " · Enter saves · Esc goes back"))
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
        // under the pick, else over it, else beside it, else just above the bar
        readonly property point place: {
            const g = canvas.u * 6, m = canvas.u * 4;
            const top = modeBox.y + modeBox.height + canvas.u * 2, bottom = bar.y - m;
            const cx = Math.max(m, Math.min(canvas.width - width - m, (CircleSearch.box ? b.x + b.width / 2 : canvas.width / 2) - width / 2));
            if (!CircleSearch.box)
                return Qt.point(cx, bottom - height);
            if (b.y + b.height + g + height < bottom)
                return Qt.point(cx, b.y + b.height + g);
            if (b.y - g - height >= top)
                return Qt.point(cx, b.y - g - height);
            const sy = Math.max(top, Math.min(bottom - height, b.y));
            if (b.x + b.width + g + width < canvas.width - m)
                return Qt.point(b.x + b.width + g, sy);
            if (b.x - g - width >= m)
                return Qt.point(b.x - g - width, sy);
            return Qt.point(cx, Math.max(m, bottom - height));
        }
        x: place.x
        y: place.y
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

    // the actions, Pixel's bar at the bottom: the pick (nothing picked: the whole screen)
    PxBox {
        id: bar
        visible: !canvas.drawing && canvas.leaving === ""
        shadow: true
        anchors.horizontalCenter: parent.horizontalCenter
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
        readonly property real home: canvas.height - height - canvas.u * 12
        y: home + (1 - canvas.shown) * canvas.u * 30
        opacity: canvas.shown

        Flow {
            id: buttons
            x: Theme.pad
            y: Theme.pad
            width: parent.width - Theme.pad * 2
            spacing: Theme.u * 2
            PxButton {
                objectName: "act-save"
                compact: true
                icon: "camera"
                accent: true
                text: I18n.t("Сохранить", "Save")
                onClicked: CircleSearch.save()
            }
            PxButton {
                objectName: "act-copy"
                compact: true
                icon: "image"
                text: I18n.t("Копировать", "Copy")
                onClicked: CircleSearch.copyShot()
            }
            PxButton {
                objectName: "act-text"
                compact: true
                icon: "document"
                enabled: CircleSearch.hasText || CircleSearch.words.length > 0
                text: I18n.t("Текст", "Text")
                onClicked: CircleSearch.copyText()
            }
            PxButton {
                objectName: "act-search"
                compact: true
                icon: CircleSearch.kind === "text" ? "search" : "window"
                enabled: CircleSearch.hasText || !!CircleSearch.box
                text: CircleSearch.kind === "text" ? I18n.t("Найти", "Search") : I18n.t("Открыть", "Open")
                onClicked: CircleSearch.search()
            }
            PxButton {
                objectName: "act-lens"
                visible: Config.circle.lens
                compact: true
                icon: "eye"
                text: I18n.t("Найти картинкой", "Search the picture")
                onClicked: CircleSearch.searchPicture()
            }
            PxButton {
                objectName: "act-translate"
                compact: true
                icon: "chat"
                enabled: (CircleSearch.hasText || CircleSearch.words.length > 0) && !CircleSearch.translating
                text: I18n.t("Перевести", "Translate")
                onClicked: CircleSearch.translate()
            }
            PxButton {
                objectName: "act-share"
                visible: Config.quickshare.enabled
                compact: true
                icon: "plane"
                text: I18n.t("Отправить рядом", "Send nearby")
                onClicked: CircleSearch.shareNearby()
            }
            PxButton {
                objectName: "act-full"
                compact: true
                icon: "monitor"
                text: I18n.t("Весь экран", "Whole screen")
                onClicked: CircleSearch.saveFull()
            }
            PxButton {
                id: windowBtn
                objectName: "act-window"
                compact: true
                icon: "window"
                enabled: CircleSearch.windowsHere.length > 0
                text: I18n.t("Окно", "Window")
                onHoveredChanged: canvas.windowPreview = hovered
                onClicked: CircleSearch.saveWindow(canvas.at.x, canvas.at.y)
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
                to: 0.7
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
