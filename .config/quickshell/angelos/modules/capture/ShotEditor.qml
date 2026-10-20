pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "ShotMarks.js" as Marks

// The screenshot editor (services/ShotEdit; ShotPreview puts it in a window of its own), ShareX /
// Flameshot-like: the tools down the left (select, pen, marker, line, arrow, box, oval, numbers,
// text, stickers, hide, crop), what the tool takes on the right (colour, size, the crop's ratio and
// turns), the shot in the middle (Ctrl + wheel zooms at the pointer, the middle button or Space
// drags it about, the wheel sizes the tool), the recent shots along the bottom. Marks stay shapes
// (ShotMark) until the picture is copied, saved or cropped: then the paper — the picture at its own
// size with the marks — is grabbed as one PNG. Crop, turn, flip and hide are steps of
// scripts/shot_edit.py. Every change is kept in ShotEdit.sessions: closed and opened again, the
// work and its undo are there.
Item {
    id: ed

    property var host: null                  // the window (its title bar moves it)

    // ---- the work on this shot (kept in ShotEdit.sessions)
    property string path: ""
    property string base: ""                 // the picture under the marks (the shot, or the last step)
    property var items: []                   // the marks (ShotMarks.js)
    property var undoList: []
    property var redoList: []
    property bool dirty: false               // changed since the last copy / save
    property bool busy: false
    property string toast: ""

    // ---- the tools
    property string tool: "arrow"
    property string lastTool: "arrow"
    property color ink: "#ff3b5c"
    property int level: 1                    // size, 0-4
    property bool fill: false
    property bool pixelFont: false
    property string sticker: "heart"
    property real aspect: 0                  // the crop's width / height, 0: free
    readonly property var inks: ["#ff3b5c", "#ff9f1c", "#ffd23f", "#3ddc84", "#3fa9ff", "#a259ff", "#ff6ec7", "#ffffff", "#111111"]
    readonly property var stickers: ["heart", "star", "sparkle", "sparkleStar", "fire", "skull", "ghost", "check", "close", "warn", "eye", "pentagram", "bot", "spider", "pin", "bell"]
    readonly property var tools: [["select", "cursor", I18n.t("Выбор", "Select"), "V"], ["pen", "pen", I18n.t("Перо", "Pen"), "P"], ["marker", "drop", I18n.t("Маркер", "Marker"), "M"], ["line", "minus", I18n.t("Линия", "Line"), "L"], ["arrow", "arrowRight", I18n.t("Стрелка", "Arrow"), "A"], ["rect", "window", I18n.t("Рамка", "Box"), "R"], ["ellipse", "cd", I18n.t("Овал", "Oval"), "E"], ["num", "note", I18n.t("Номер", "Number"), "N"], ["text", "keyboard", I18n.t("Текст", "Text"), "T"], ["sticker", "heart", I18n.t("Наклейка", "Sticker"), "S"], ["hide", "eye", I18n.t("Скрыть", "Hide"), "H"], ["crop", "grid", I18n.t("Обрезать", "Crop"), "C"]]
    // the sizes in the picture's pixels: a 4K shot gets thicker lines than a small one
    readonly property int unit: Math.max(1, Math.round(Math.max(paper.width, paper.height) / 1400))
    readonly property real lineW: [2, 4, 7, 11, 16][level] * unit
    readonly property real textSize: [16, 22, 30, 42, 60][level] * unit
    readonly property real numSize: [22, 30, 40, 54, 72][level] * unit
    readonly property real stickerSize: [30, 44, 64, 90, 130][level] * unit
    readonly property int nextNum: items.filter(m => m.t === "num").length + 1

    // ---- what the pointer is doing (the picture's pixels)
    property var live: null                  // the mark being drawn
    property var anchor: null
    property int selected: -1
    property var dragFrom: null
    property point dragD: Qt.point(0, 0)
    property var hideBox: null
    property var crop: null                  // the crop's box while cropping
    property int grip: -1
    property var cropFrom: null
    property var typing: null                // where text is being typed: {x, y}

    // ---- the view
    property real zoom: 1                    // × the whole picture fitted
    property real panX: 0
    property real panY: 0
    readonly property real fitK: paper.width > 1 ? Math.min(view.width / paper.width, view.height / paper.height, 1) : 1
    readonly property real k: fitK * zoom
    // (for the test)
    readonly property alias page: paper

    // ---- the work
    Connections {
        target: ShotEdit
        function onOpened(p) {
            ed.load(p);
        }
    }
    Component.onCompleted: if (ShotEdit.editing && ShotEdit.path)
        load(ShotEdit.path)
    Component.onDestruction: store()

    function load(p) {
        if (path && path !== p) {
            finishTyping(true);
            store();
        }
        const s = ShotEdit.sessions[p];
        path = p;
        base = s ? s.base : p;
        items = s ? s.items : [];
        undoList = s ? s.undo : [];
        redoList = s ? s.redo : [];
        dirty = s ? s.dirty : false;
        selected = -1;
        live = null;
        typing = null;
        hideBox = null;
        zoom = 1;
        panX = 0;
        panY = 0;
        if (tool === "crop")
            tool = lastTool;
        // the shot itself may be saved over: the work goes on a copy of it
        if (!s)
            ShotEdit.run(p, "copy", "-", f => {
                if (f && ed.path === p && ed.base === p) {
                    ed.base = f;
                    ed.store();
                }
            });
    }
    function store() {
        if (path)
            ShotEdit.keep(path, {
                "base": base,
                "items": items,
                "undo": undoList,
                "redo": redoList,
                "dirty": dirty
            });
    }
    function change(newBase, newItems) {
        undoList = undoList.concat([{
                "base": base,
                "items": items
            }]).slice(-80);
        redoList = [];
        base = newBase;
        items = newItems;
        dirty = true;
        store();
    }
    function add(m) {
        change(base, items.concat([m]));
    }
    function undo() {
        if (!undoList.length || busy)
            return;
        const u = undoList[undoList.length - 1];
        redoList = redoList.concat([{
                "base": base,
                "items": items
            }]);
        undoList = undoList.slice(0, -1);
        base = u.base;
        items = u.items;
        selected = -1;
        dirty = true;
        store();
    }
    function redo() {
        if (!redoList.length || busy)
            return;
        const r = redoList[redoList.length - 1];
        undoList = undoList.concat([{
                "base": base,
                "items": items
            }]);
        redoList = redoList.slice(0, -1);
        base = r.base;
        items = r.items;
        selected = -1;
        dirty = true;
        store();
    }
    function say(t) {
        toast = t;
        toastTimer.restart();
    }
    Timer {
        id: toastTimer
        interval: 2600
        onTriggered: ed.toast = ""
    }

    // the picture with its marks as one PNG: done(file)
    function flatten(done) {
        finishTyping(true);
        if (!items.length)
            return done(base);
        selected = -1;
        live = null;
        busy = true;
        Qt.callLater(() => paper.grabToImage(r => {
                const f = ShotEdit.newFile();
                ed.busy = false;
                if (r.saveToFile(f))
                    done(f);
                else
                    ed.say(I18n.t("Не получилось собрать картинку", "Could not make the picture"));
            }, Qt.size(paper.width, paper.height)));
    }
    // crop / turn / flip / hide: a step of scripts/shot_edit.py on the flattened picture
    function step(op, arg) {
        if (busy)
            return;
        flatten(f => {
            ed.busy = true;
            ShotEdit.run(f, op, arg, out => {
                ed.busy = false;
                if (out)
                    ed.change(out, []);
                else
                    ed.say(ShotEdit.error || I18n.t("Не получилось", "Did not work"));
            });
        });
    }
    // on the clipboard, and the changes over the shot in the folder too (what was copied is what is kept)
    function copy() {
        if (busy)
            return;
        const changed = dirty;
        flatten(f => {
            ShotEdit.copyFile(f);
            if (changed)
                ShotEdit.saveFile(f, true);
            ed.dirty = false;
            ed.store();
            ed.say(I18n.t("Скопировано — вставляйте куда нужно", "Copied — paste it anywhere"));
        });
    }
    function save() {
        if (busy)
            return;
        const toFolder = ShotEdit.temp;
        flatten(f => {
            ShotEdit.saveFile(f);
            ed.dirty = false;
            ed.store();
            ed.say(toFolder ? I18n.t("Сохранено в папку снимков", "Saved into the screenshots folder") : I18n.t("Сохранено", "Saved"));
        });
    }
    // under the shot's own name (not the step's 1792…-3.png): that is the name the phone gets
    function share() {
        if (!busy)
            flatten(f => ShotEdit.named(f, g => QuickShare.share([g], "")));
    }

    // ---- the tools at work
    onToolChanged: {
        finishTyping(true);
        live = null;
        hideBox = null;
        if (tool !== "select")
            selected = -1;
        if (tool === "crop")
            crop = Marks.fitAspect(paper.width, paper.height, aspect);
        else {
            crop = null;
            lastTool = tool;
        }
    }
    function setAspect(a) {
        aspect = a;
        crop = Marks.fitAspect(paper.width, paper.height, a);
    }
    function applyCrop() {
        const c = crop;
        if (!c || busy)
            return;
        tool = lastTool;
        if (c.x > 0.5 || c.y > 0.5 || c.w < paper.width - 1 || c.h < paper.height - 1)
            step("crop", [c.x, c.y, c.w, c.h].map(Math.round).join(","));
    }
    // the colour / size picked: the selected mark takes it too
    function restyle() {
        if (selected < 0 || selected >= items.length)
            return;
        const m = Object.assign({}, items[selected]);
        m.c = String(ink);
        if (m.t === "pen" || m.t === "line" || m.t === "arrow")
            m.w = lineW;
        else if (m.t === "marker")
            m.w = lineW * 3;
        else if (m.t === "rect" || m.t === "ellipse") {
            m.lw = lineW;
            m.fill = fill;
        } else if (m.t === "num")
            m.s = numSize;
        else if (m.t === "text") {
            m.size = textSize;
            m.pixel = pixelFont;
        } else if (m.t === "sticker")
            m.s = stickerSize;
        const list = items.slice();
        list[selected] = m;
        change(base, list);
    }
    function removeSelected() {
        if (selected < 0)
            return;
        const i = selected;
        selected = -1;
        change(base, items.filter((m, j) => j !== i));
    }
    function finishTyping(commit) {
        if (!typing)
            return;
        const t = typer.text, at = typing;
        typing = null;
        typer.text = "";
        if (commit && t.trim())
            add({
                "t": "text",
                "x": at.x,
                "y": at.y,
                "s": t,
                "c": String(ink),
                "size": textSize,
                "pixel": pixelFont
            });
    }
    function cancel() {
        if (typing)
            return finishTyping(false);
        if (live || hideBox) {
            live = null;
            hideBox = null;
            return;
        }
        if (tool === "crop")
            return tool = lastTool;
        selected = -1;
    }
    function cropGrip(p) {
        const r = crop, reach = 14 / k;
        if (!r)
            return -1;
        const pts = [[r.x, r.y], [r.x + r.w, r.y], [r.x + r.w, r.y + r.h], [r.x, r.y + r.h]];
        for (let i = 0; i < 4; i++)
            if (Math.abs(p[0] - pts[i][0]) < reach && Math.abs(p[1] - pts[i][1]) < reach)
                return i;
        const inX = p[0] > r.x && p[0] < r.x + r.w, inY = p[1] > r.y && p[1] < r.y + r.h;
        if (inX && Math.abs(p[1] - r.y) < reach)
            return 4;
        if (inY && Math.abs(p[0] - r.x - r.w) < reach)
            return 5;
        if (inX && Math.abs(p[1] - r.y - r.h) < reach)
            return 6;
        if (inY && Math.abs(p[0] - r.x) < reach)
            return 7;
        return inX && inY ? 8 : -1;
    }
    function press(p, mods) {
        const c = String(ink);
        switch (tool) {
        case "select":
            selected = Marks.hit(items, p[0], p[1], 6 / k);
            dragFrom = selected >= 0 ? p : null;
            dragD = Qt.point(0, 0);
            break;
        case "pen":
        case "marker":
            live = {
                "t": tool,
                "pts": [p],
                "c": c,
                "w": tool === "marker" ? lineW * 3 : lineW
            };
            break;
        case "line":
        case "arrow":
            live = {
                "t": tool,
                "a": p,
                "b": p,
                "c": c,
                "w": lineW
            };
            break;
        case "rect":
        case "ellipse":
            anchor = p;
            live = {
                "t": tool,
                "x": p[0],
                "y": p[1],
                "w": 0,
                "h": 0,
                "c": c,
                "lw": lineW,
                "fill": fill
            };
            break;
        case "num":
            add({
                "t": "num",
                "x": p[0],
                "y": p[1],
                "n": nextNum,
                "c": c,
                "s": numSize
            });
            break;
        case "sticker":
            add({
                "t": "sticker",
                "x": p[0],
                "y": p[1],
                "icon": sticker,
                "s": stickerSize
            });
            break;
        case "text":
            if (typing)
                finishTyping(true);
            else {
                typing = {
                    "x": p[0],
                    "y": p[1] - textSize * 0.6
                };
                Qt.callLater(() => typer.forceActiveFocus());
            }
            break;
        case "hide":
            anchor = p;
            hideBox = Marks.box(p, p, false);
            break;
        case "crop":
            grip = cropGrip(p);
            cropFrom = grip >= 0 ? {
                "p": p,
                "r": crop
            } : null;
            break;
        }
    }
    function move(p, mods) {
        const shift = mods & Qt.ShiftModifier;
        if (tool === "select" && dragFrom)
            dragD = Qt.point(p[0] - dragFrom[0], p[1] - dragFrom[1]);
        else if (live && live.pts) {
            const last = live.pts[live.pts.length - 1];
            if (Math.hypot(p[0] - last[0], p[1] - last[1]) >= Math.max(1, live.w / 4))
                live = Object.assign({}, live, {
                    "pts": live.pts.concat([p])
                });
        } else if (live && live.a)
            live = Object.assign({}, live, {
                "b": shift ? Marks.snap45(live.a, p) : p
            });
        else if (live && anchor)
            live = Object.assign({}, live, Marks.box(anchor, p, shift));
        else if (hideBox && anchor)
            hideBox = Marks.box(anchor, p, false);
        else if (tool === "crop" && cropFrom)
            crop = Marks.cropDrag(cropFrom.r, grip, p[0] - cropFrom.p[0], p[1] - cropFrom.p[1], paper.width, paper.height, aspect, 16 * unit);
    }
    function release(p, mods) {
        move(p, mods);
        if (tool === "select" && dragFrom) {
            if (selected >= 0 && (dragD.x || dragD.y)) {
                const list = items.slice();
                list[selected] = Marks.moved(list[selected], dragD.x, dragD.y);
                dragD = Qt.point(0, 0);
                change(base, list);
            }
            dragFrom = null;
            dragD = Qt.point(0, 0);
        } else if (live) {
            const m = live;
            live = null;
            anchor = null;
            const big = m.pts ? true : m.a ? Math.hypot(m.b[0] - m.a[0], m.b[1] - m.a[1]) >= 3 : m.w >= 3 && m.h >= 3;
            if (big)
                add(m);
        } else if (hideBox) {
            const b = hideBox;
            hideBox = null;
            anchor = null;
            if (b.w >= 4 && b.h >= 4)
                step("hide", [b.x, b.y, b.w, b.h].map(Math.round).join(","));
        } else if (tool === "crop") {
            grip = -1;
            cropFrom = null;
        }
    }
    // Ctrl + wheel: the point under the pointer stays under it
    function zoomAt(vx, vy, f) {
        const p = toPaper(vx, vy), z = Math.max(0.25, Math.min(12, zoom * f)), k2 = fitK * z;
        zoom = z;
        panX = vx - p[0] * k2 - (view.width - paper.width * k2) / 2;
        panY = vy - p[1] * k2 - (view.height - paper.height * k2) / 2;
    }
    function fit() {
        zoom = 1;
        panX = 0;
        panY = 0;
    }
    function toPaper(x, y) {
        const q = paper.mapFromItem(view, x, y);
        return [q.x, q.y];
    }

    // ---- the keys (the same keys on the Russian layout too)
    component Key: Shortcut {
        context: Qt.WindowShortcut
        enabled: !ed.typing
    }
    Key {
        sequences: ["Ctrl+Z", "Ctrl+Я"]
        onActivated: ed.undo()
    }
    Key {
        sequences: ["Ctrl+Shift+Z", "Ctrl+Shift+Я", "Ctrl+Y", "Ctrl+Н"]
        onActivated: ed.redo()
    }
    Key {
        sequences: ["Ctrl+C", "Ctrl+С"]
        onActivated: ed.copy()
    }
    Key {
        sequences: ["Ctrl+S", "Ctrl+Ы"]
        onActivated: ed.save()
    }
    Key {
        sequences: ["Return", "Enter"]
        onActivated: ed.tool === "crop" ? ed.applyCrop() : ed.copy()
    }
    Key {
        sequence: "Escape"
        onActivated: ed.cancel()
    }
    Key {
        sequences: ["Delete", "Backspace"]
        onActivated: ed.removeSelected()
    }
    Key {
        sequences: ["Ctrl+0", "0"]
        onActivated: ed.fit()
    }
    Key {
        sequences: ["Ctrl+=", "Ctrl++", "+", "="]
        onActivated: ed.zoomAt(view.width / 2, view.height / 2, 1.25)
    }
    Key {
        sequences: ["Ctrl+-", "-"]
        onActivated: ed.zoomAt(view.width / 2, view.height / 2, 0.8)
    }
    Key {
        sequences: ["[", "Х"]
        onActivated: {
            ed.level = Math.max(0, ed.level - 1);
            ed.restyle();
        }
    }
    Key {
        sequences: ["]", "Ъ"]
        onActivated: {
            ed.level = Math.min(4, ed.level + 1);
            ed.restyle();
        }
    }
    Repeater {
        model: ed.tools
        Item {
            id: tk
            required property var modelData
            readonly property string ru: ({
                    "V": "М",
                    "P": "З",
                    "M": "Ь",
                    "L": "Д",
                    "A": "Ф",
                    "R": "К",
                    "E": "У",
                    "N": "Т",
                    "T": "Е",
                    "S": "Ы",
                    "H": "Р",
                    "C": "С"
                })[modelData[3]]
            Key {
                sequences: [tk.modelData[3], tk.ru]
                onActivated: ed.tool = tk.modelData[0]
            }
        }
    }

    PxWindow {
        id: frame
        anchors.fill: parent
        anchors.rightMargin: Theme.u * 2
        anchors.bottomMargin: Theme.u * 2
        skin: ""
        translucent: false
        title: I18n.t("Правка снимка", "Screenshot editor") + (ed.path ? " · " + ed.path.split("/").pop() : "")
        icon: "image"
        onCloseClicked: ShotEdit.close()
        onTitlePressed: if (ed.host)
            ed.host.startSystemMove()

        Item {
            id: body
            readonly property string settingsSkin: "classic"
            readonly property int gap: Theme.u * 3
            width: parent.width
            height: parent.height

            // ---- along the top: undo, the zoom, what to do with the result
            Item {
                id: top
                width: parent.width
                height: copyBtn.height
                Row {
                    spacing: Theme.u * 2
                    anchors.verticalCenter: parent.verticalCenter
                    PxButton {
                        compact: true
                        icon: "arrowLeft"
                        text: I18n.t("Назад", "Undo")
                        enabled: ed.undoList.length > 0 && !ed.busy
                        onClicked: ed.undo()
                    }
                    PxButton {
                        compact: true
                        icon: "arrowRight"
                        text: I18n.t("Вперёд", "Redo")
                        enabled: ed.redoList.length > 0 && !ed.busy
                        onClicked: ed.redo()
                    }
                    Item {
                        width: Theme.u * 6
                        height: 1
                    }
                    PxButton {
                        compact: true
                        icon: "minus"
                        onClicked: ed.zoomAt(view.width / 2, view.height / 2, 0.8)
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u * 22
                        horizontalAlignment: Text.AlignHCenter
                        text: Math.round(ed.k * 100) + "%"
                    }
                    PxButton {
                        compact: true
                        icon: "plus"
                        onClicked: ed.zoomAt(view.width / 2, view.height / 2, 1.25)
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Вписать", "Fit")
                        onClicked: ed.fit()
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.u * 2
                    PxButton {
                        visible: Config.quickshare.enabled
                        compact: true
                        icon: "plane"
                        text: I18n.t("Отправить рядом", "Send nearby")
                        enabled: !ed.busy
                        onClicked: ed.share()
                    }
                    PxButton {
                        objectName: "editor-save"
                        compact: true
                        icon: "folder"
                        // a shot only copied is not in the folder yet
                        text: ShotEdit.temp ? I18n.t("В папку", "To the folder") : I18n.t("Сохранить", "Save")
                        enabled: !ed.busy
                        onClicked: ed.save()
                    }
                    // the clipboard: what a shot is mostly for
                    PxButton {
                        id: copyBtn
                        objectName: "editor-copy"
                        compact: true
                        accent: true
                        icon: "check"
                        text: I18n.t("Копировать", "Copy")
                        enabled: !ed.busy
                        onClicked: ed.copy()
                    }
                }
            }

            // ---- the tools down the left
            Column {
                id: toolCol
                anchors.top: top.bottom
                anchors.topMargin: body.gap
                width: Theme.u * 56
                spacing: Theme.u
                Repeater {
                    model: ed.tools
                    PxButton {
                        required property var modelData
                        objectName: "tool-" + modelData[0]
                        width: toolCol.width
                        compact: true
                        icon: modelData[1]
                        text: modelData[2] + "  " + modelData[3]
                        checked: ed.tool === modelData[0]
                        onClicked: ed.tool = modelData[0]
                    }
                }
            }

            // ---- what the tool takes, on the right
            Column {
                id: side
                anchors.top: top.bottom
                anchors.topMargin: body.gap
                anchors.right: parent.right
                width: Theme.u * 84
                spacing: Theme.u * 4

                PxText {
                    width: parent.width
                    font.bold: true
                    text: (ed.tools.find(t => t[0] === ed.tool) || ["", "", ""])[2]
                }
                // colours: every drawing tool (and a selected mark)
                Flow {
                    visible: ["hide", "crop", "sticker"].indexOf(ed.tool) < 0
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: ed.inks
                        Rectangle {
                            id: sw
                            required property string modelData
                            readonly property bool on: Qt.colorEqual(ed.ink, modelData)
                            width: Theme.u * 12
                            height: width
                            color: modelData
                            border.width: on ? Theme.u : 1
                            border.color: on ? Theme.accent : Theme.edge
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ed.ink = sw.modelData;
                                    ed.restyle();
                                }
                            }
                        }
                    }
                }
                // size: five dots (the wheel and [ ] too)
                Row {
                    visible: ["hide", "crop"].indexOf(ed.tool) < 0
                    spacing: Theme.u * 2
                    Repeater {
                        model: 5
                        Rectangle {
                            id: dot
                            required property int index
                            width: Theme.u * 14
                            height: width
                            color: ed.level === index ? Qt.alpha(Theme.accent, 0.3) : Theme.sunken
                            border.width: 1
                            border.color: ed.level === index ? Theme.accent : Theme.edge
                            Rectangle {
                                anchors.centerIn: parent
                                width: 3 + dot.index * 2.5
                                height: width
                                radius: width / 2
                                color: Theme.text
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ed.level = dot.index;
                                    ed.restyle();
                                }
                            }
                        }
                    }
                }
                PxCheck {
                    visible: ed.tool === "rect" || ed.tool === "ellipse" || ed.tool === "select"
                    text: I18n.t("Заливка", "Filled")
                    checked: ed.fill
                    onToggled: c => {
                        ed.fill = c;
                        ed.restyle();
                    }
                }
                PxCheck {
                    visible: ed.tool === "text" || ed.tool === "select"
                    text: I18n.t("Пиксельный шрифт", "Pixel font")
                    checked: ed.pixelFont
                    onToggled: c => {
                        ed.pixelFont = c;
                        ed.restyle();
                    }
                }
                // stickers: angelOS's pixel icons
                Grid {
                    visible: ed.tool === "sticker"
                    columns: 4
                    spacing: Theme.u * 2
                    Repeater {
                        model: ed.stickers
                        Rectangle {
                            id: st
                            required property string modelData
                            width: Theme.u * 18
                            height: width
                            color: ed.sticker === modelData ? Qt.alpha(Theme.accent, 0.3) : Theme.sunken
                            border.width: 1
                            border.color: ed.sticker === modelData ? Theme.accent : Theme.edge
                            PxIcon {
                                anchors.centerIn: parent
                                name: st.modelData
                                pixel: Theme.u + 1
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ed.sticker = st.modelData
                            }
                        }
                    }
                }
                // the crop: its ratio, the turns, done
                Flow {
                    visible: ed.tool === "crop"
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: [[0, I18n.t("Свободно", "Free")], [-1, I18n.t("Как было", "Original")], [1, "1:1"], [4 / 3, "4:3"], [16 / 9, "16:9"], [9 / 16, "9:16"]]
                        PxButton {
                            required property var modelData
                            readonly property real a: modelData[0] < 0 ? paper.width / Math.max(1, paper.height) : modelData[0]
                            compact: true
                            text: modelData[1]
                            checked: Math.abs(ed.aspect - a) < 0.001
                            onClicked: ed.setAspect(a)
                        }
                    }
                }
                Flow {
                    visible: ed.tool === "crop"
                    width: parent.width
                    spacing: Theme.u * 2
                    PxButton {
                        compact: true
                        icon: "rotate"
                        text: I18n.t("Влево", "Left")
                        enabled: !ed.busy
                        onClicked: ed.step("rotate", "ccw")
                    }
                    PxButton {
                        compact: true
                        icon: "rotate"
                        text: I18n.t("Вправо", "Right")
                        enabled: !ed.busy
                        onClicked: ed.step("rotate", "cw")
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Отразить ↔", "Flip ↔")
                        enabled: !ed.busy
                        onClicked: ed.step("flip", "h")
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Отразить ↕", "Flip ↕")
                        enabled: !ed.busy
                        onClicked: ed.step("flip", "v")
                    }
                }
                Row {
                    visible: ed.tool === "crop"
                    spacing: Theme.u * 2
                    PxButton {
                        objectName: "crop-done"
                        compact: true
                        accent: true
                        icon: "check"
                        text: I18n.t("Готово", "Done")
                        enabled: !ed.busy
                        onClicked: ed.applyCrop()
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("Отмена", "Cancel")
                        onClicked: ed.tool = ed.lastTool
                    }
                }
                PxButton {
                    visible: ed.tool === "select" && ed.selected >= 0
                    compact: true
                    danger: true
                    icon: "trash"
                    text: I18n.t("Удалить", "Delete")
                    onClicked: ed.removeSelected()
                }
                PxText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    kind: "tiny"
                    dim: true
                    text: ({
                            "select": I18n.t("Нажмите на метку — выбрать, тяните — двигать. Цвет и размер меняют выбранную. Delete — удалить.", "Click a mark to pick it, drag to move it. Colour and size change the picked one. Delete removes it."),
                            "pen": I18n.t("Рисуйте от руки.", "Draw freehand."),
                            "marker": I18n.t("Полупрозрачный маркер — выделить строку.", "A see-through marker to highlight a line."),
                            "line": I18n.t("Shift — по 45°.", "Shift: 45° steps."),
                            "arrow": I18n.t("Тяните от хвоста к острию. Shift — по 45°.", "Drag from the tail to the tip. Shift: 45° steps."),
                            "rect": I18n.t("Shift — квадрат.", "Shift: a square."),
                            "ellipse": I18n.t("Shift — круг.", "Shift: a circle."),
                            "num": I18n.t("Клик — следующий номер, шаги по порядку. Следующий: ", "Click: the next number, steps in order. Next: ") + ed.nextNum,
                            "text": I18n.t("Клик — пишите. Enter — готово, Shift+Enter — новая строка.", "Click and type. Enter: done, Shift+Enter: a new line."),
                            "sticker": I18n.t("Клик — наклейка. Колесо — размер.", "Click: a sticker. The wheel sizes it."),
                            "hide": I18n.t("Тяните рамку по личному — закроется крупными пикселями, их не вернуть.", "Drag a box over what is private: big pixels cover it, no way back."),
                            "crop": I18n.t("Тяните углы и края рамки, внутри — двигать. Enter — готово, Esc — отмена.", "Drag the corners and sides, inside moves it. Enter: done, Esc: cancel.")
                        })[ed.tool] + I18n.t("\n\nКолесо — размер · Ctrl+колесо — масштаб · средняя кнопка или пробел — двигать · буква на кнопке — инструмент", "\n\nWheel: size · Ctrl+wheel: zoom · the middle button or Space drags · the letter on a button picks it")
                }
            }

            // ---- the recent shots along the bottom
            Item {
                id: strip
                anchors.bottom: parent.bottom
                width: parent.width
                height: Theme.u * 34
                PxText {
                    id: stripLabel
                    kind: "tiny"
                    dim: true
                    text: I18n.t("Недавние", "Recent")
                }
                ListView {
                    anchors.top: stripLabel.bottom
                    anchors.topMargin: Theme.u
                    anchors.bottom: parent.bottom
                    width: parent.width
                    orientation: ListView.Horizontal
                    spacing: Theme.u * 2
                    clip: true
                    model: ShotEdit.recentShots
                    delegate: Rectangle {
                        id: shot
                        required property string modelData
                        readonly property bool here: modelData === ed.path
                        width: Theme.u * 44
                        height: ListView.view.height
                        color: Theme.sunken
                        border.width: here ? Theme.u : 1
                        border.color: here ? Theme.accent : Theme.edge
                        Image {
                            anchors.fill: parent
                            anchors.margins: Theme.u * 1.5
                            source: FileSearch.uri(shot.modelData)
                            sourceSize: Qt.size(Theme.u * 88, Theme.u * 56)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        // work left on it (kept while the shell runs)
                        Rectangle {
                            visible: !!ShotEdit.sessions[shot.modelData] && ShotEdit.sessions[shot.modelData].dirty
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.u * 2
                            width: Theme.u * 4
                            height: width
                            color: Theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ShotEdit.edit(shot.modelData)
                        }
                    }
                }
            }

            PxText {
                id: status
                anchors.bottom: strip.top
                anchors.bottomMargin: body.gap
                anchors.left: view.left
                width: view.width
                elide: Text.ElideRight
                kind: "tiny"
                dim: !ed.toast
                text: ed.toast || (ed.busy ? I18n.t("Секунду…", "A moment…") : (paper.width > 1 ? Math.round(paper.width) + " × " + Math.round(paper.height) : "") + (ed.dirty ? I18n.t(" · есть правки", " · edited") : "") + I18n.t(" · Enter / Ctrl+C — копировать · Ctrl+S — сохранить · Ctrl+Z — назад", " · Enter / Ctrl+C copies · Ctrl+S saves · Ctrl+Z undo"))
            }

            // ---- the shot
            PxBox {
                anchors.fill: view
                anchors.margins: -Theme.u
                sunken: true
                color: Theme.sunken
            }
            Item {
                id: view
                anchors.top: top.bottom
                anchors.topMargin: body.gap
                anchors.left: toolCol.right
                anchors.leftMargin: body.gap
                anchors.right: side.left
                anchors.rightMargin: body.gap
                anchors.bottom: status.top
                anchors.bottomMargin: Theme.u * 2
                clip: true
                focus: true

                Item {
                    id: sheet
                    x: (view.width - paper.width * ed.k) / 2 + ed.panX
                    y: (view.height - paper.height * ed.k) / 2 + ed.panY
                    width: paper.width
                    height: paper.height
                    scale: ed.k
                    transformOrigin: Item.TopLeft

                    // the picture at its own size with its marks: what is grabbed as the result
                    Item {
                        id: paper
                        width: Math.max(1, pic.implicitWidth)
                        height: Math.max(1, pic.implicitHeight)
                        onWidthChanged: if (ed.tool === "crop")
                            ed.crop = Marks.fitAspect(width, height, ed.aspect)
                        onHeightChanged: if (ed.tool === "crop")
                            ed.crop = Marks.fitAspect(width, height, ed.aspect)
                        Image {
                            id: pic
                            source: ed.base ? FileSearch.uri(ed.base) : ""
                            cache: false
                            smooth: true
                            mipmap: true
                        }
                        Repeater {
                            model: ed.items
                            ShotMark {
                                required property var modelData
                                required property int index
                                mark: modelData
                                selected: index === ed.selected
                                offset: index === ed.selected ? ed.dragD : Qt.point(0, 0)
                            }
                        }
                        ShotMark {
                            visible: !!ed.live
                            mark: ed.live || ({})
                        }
                        // text being typed, where it will be
                        TextEdit {
                            id: typer
                            visible: !!ed.typing
                            x: ed.typing ? ed.typing.x : 0
                            y: ed.typing ? ed.typing.y : 0
                            color: ed.ink
                            font.family: ed.pixelFont ? Theme.fontTitle : Theme.macFont
                            font.bold: true
                            font.pixelSize: ed.textSize
                            cursorVisible: visible
                            Keys.onReturnPressed: e => {
                                if (e.modifiers & Qt.ShiftModifier)
                                    e.accepted = false;
                                else
                                    ed.finishTyping(true);
                            }
                            Keys.onEnterPressed: ed.finishTyping(true)
                            Keys.onEscapePressed: ed.finishTyping(false)
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                z: -1
                                color: "transparent"
                                border.width: 2
                                border.color: Qt.alpha("white", 0.8)
                                visible: typer.visible
                            }
                        }
                    }

                    // the box to hide, being dragged
                    Rectangle {
                        visible: !!ed.hideBox
                        x: ed.hideBox ? ed.hideBox.x : 0
                        y: ed.hideBox ? ed.hideBox.y : 0
                        width: ed.hideBox ? ed.hideBox.w : 0
                        height: ed.hideBox ? ed.hideBox.h : 0
                        color: Qt.alpha(Theme.shadow, 0.6)
                        border.width: 2 / ed.k
                        border.color: "white"
                    }

                    // the crop: the rest dimmed, thirds, grips at the corners and sides (screen-sized)
                    Item {
                        id: cropFace
                        visible: !!ed.crop
                        anchors.fill: parent
                        readonly property var r: ed.crop || ({
                                "x": 0,
                                "y": 0,
                                "w": 0,
                                "h": 0
                            })
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                readonly property var r: cropFace.r
                                color: Qt.alpha("black", 0.55)
                                x: index === 1 ? r.x + r.w : 0
                                y: index === 0 ? 0 : index === 3 ? r.y + r.h : r.y
                                width: index === 0 || index === 3 ? paper.width : index === 1 ? paper.width - r.x - r.w : r.x
                                height: index === 0 ? r.y : index === 3 ? paper.height - r.y - r.h : r.h
                            }
                        }
                        Rectangle {
                            id: cropBox
                            x: cropFace.r.x
                            y: cropFace.r.y
                            width: cropFace.r.w
                            height: cropFace.r.h
                            color: "transparent"
                            border.width: 2 / ed.k
                            border.color: "white"
                            Repeater {
                                model: 4
                                Rectangle {
                                    required property int index
                                    readonly property bool across: index < 2
                                    color: Qt.alpha("white", 0.45)
                                    x: across ? 0 : cropBox.width * (index - 1) / 3
                                    y: across ? cropBox.height * (index + 1) / 3 : 0
                                    width: across ? cropBox.width : 1 / ed.k
                                    height: across ? 1 / ed.k : cropBox.height
                                }
                            }
                        }
                        Repeater {
                            model: 8
                            Rectangle {
                                required property int index
                                readonly property var r: cropFace.r
                                readonly property real s: (index < 4 ? 14 : 10) / ed.k
                                readonly property var at: [[r.x, r.y], [r.x + r.w, r.y], [r.x + r.w, r.y + r.h], [r.x, r.y + r.h], [r.x + r.w / 2, r.y], [r.x + r.w, r.y + r.h / 2], [r.x + r.w / 2, r.y + r.h], [r.x, r.y + r.h / 2]][index]
                                x: at[0] - s / 2
                                y: at[1] - s / 2
                                width: s
                                height: s
                                color: "white"
                                border.width: 1 / ed.k
                                border.color: Qt.alpha("black", 0.5)
                            }
                        }
                    }
                }

                PxText {
                    anchors.centerIn: parent
                    visible: !ed.base
                    dim: true
                    text: I18n.t("Откройте снимок снизу", "Open a shot below")
                }

                // the pointer: the tool; the middle button / Space drags the view; the wheel sizes, Ctrl+wheel zooms
                property bool space: false
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Space && !e.isAutoRepeat)
                        view.space = true;
                }
                Keys.onReleased: e => {
                    if (e.key === Qt.Key_Space && !e.isAutoRepeat)
                        view.space = false;
                }
                MouseArea {
                    id: pointer
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    hoverEnabled: true
                    property bool panning: false
                    property point last
                    property real mx: 0
                    property real my: 0
                    property int mods: 0
                    property bool moved: false
                    cursorShape: panning || view.space ? Qt.ClosedHandCursor : ed.tool === "select" ? Qt.ArrowCursor : ed.tool === "text" ? Qt.IBeamCursor : ed.tool === "crop" ? Qt.SizeAllCursor : Qt.CrossCursor
                    function flush() {
                        if (moved) {
                            moved = false;
                            ed.move(ed.toPaper(mx, my), mods);
                        }
                    }
                    onPressed: m => {
                        if (!ed.typing)
                            view.forceActiveFocus();
                        if (m.button === Qt.MiddleButton || view.space) {
                            panning = true;
                            last = Qt.point(m.x, m.y);
                            return;
                        }
                        if (m.button === Qt.RightButton)
                            return ed.cancel();
                        ed.press(ed.toPaper(m.x, m.y), m.modifiers);
                    }
                    onPositionChanged: m => {
                        if (panning) {
                            ed.panX += m.x - last.x;
                            ed.panY += m.y - last.y;
                            last = Qt.point(m.x, m.y);
                            return;
                        }
                        if (!(pressedButtons & Qt.LeftButton))
                            return;
                        // an 8 kHz mouse: its moves handled once a frame
                        mx = m.x;
                        my = m.y;
                        mods = m.modifiers;
                        moved = true;
                    }
                    onReleased: m => {
                        if (panning) {
                            panning = false;
                            return;
                        }
                        if (m.button !== Qt.LeftButton)
                            return;
                        flush();
                        ed.release(ed.toPaper(m.x, m.y), m.modifiers);
                    }
                    onWheel: w => {
                        const up = w.angleDelta.y > 0;
                        if (w.modifiers & Qt.ControlModifier)
                            ed.zoomAt(w.x, w.y, up ? 1.15 : 1 / 1.15);
                        else {
                            ed.level = Math.max(0, Math.min(4, ed.level + (up ? 1 : -1)));
                            ed.restyle();
                        }
                    }
                }
                FrameAnimation {
                    running: pointer.moved
                    onTriggered: pointer.flush()
                }
            }
        }
    }
}
