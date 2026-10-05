pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import qs.config
import qs.services
import qs.widgets

// One desktop widget in its frame. Every widget lives twice (Background):
//   face   in the backdrop (angelos-wallpaper): what you see. niri never slides
//          the backdrop, so the widget stays put while workspaces switch —
//          however the switch starts — and shows in the overview. No input there.
//   input  on angelos-desktop, which niri draws inside every workspace: the
//          same widget at opacity 0 that takes the pointer (Qt delivers input to
//          invisible items). It shows itself only where it has something the
//          face can't: hover and presses on buttons (NowPlaying) — while hovered,
//          dragged or in edit mode — and steps aside while workspaces slide.
//          Widgets with nothing to click (clock, sysmon, cava, the companions'
//          orbs) keep their input copy empty: one set of timers and processes.
// Dragged by the title bar, double click on the title toggles edit mode, Ctrl +
// wheel (or the wheel in edit mode) resizes it, a right click on a bare spot
// opens the desktop menu.
// macOS look (DesktopWidgets.macLook, Settings → Widgets → Style): a Golden Gate card
// (MacWidgetCard) with no title bar — in edit mode the whole card is the handle, a double
// click on a bare spot of it toggles edit mode, its face blurs the wallpaper (`backdrop`).
// Heaven and hell (Theme.realm): in hell the frame is the circle's, with its rim
// (PxWindow.hell, HellEdge) and the built-in widgets draw their own hell look; a plugin
// that doesn't ("realms" in its manifest) is re-inked by shaders/hell_widget.
// Going over, the widget burns (into hell) or turns to ash (back to heaven) —
// not on streamed screens, where it simply changes.
Item {
    id: host

    required property string uid
    required property string screenName
    required property Item area
    // the face's wallpaper (Background: WallpaperView), blurred under a macOS card
    property Item backdrop: null
    // a macOS card instead of the pixel window (not in hell: the circle's look stays)
    readonly property bool mac: DesktopWidgets.macLook
    property string role: "input"            // input | face
    readonly property bool face: role === "face"
    readonly property var body: content.item
    // the content has something to click or hover (a button): see scanInput()
    property bool interactive: false
    readonly property var widget: DesktopWidgets.byUid(uid)
    readonly property var info: widget ? DesktopWidgets.typeInfo(widget.type) : null
    readonly property bool wants: !content.item || content.item.wantVisible === undefined || content.item.wantVisible
    readonly property bool dragging: DesktopWidgets.drag.uid === uid
    // the frame on show: the pixel window or the macOS card
    readonly property Item frame: mac ? macFrame : pxFrame
    // what drags it: the pixel window's title bar, or the macOS card (in edit mode)
    readonly property MouseArea grip: mac ? macFrame.dragArea : pxFrame.titleMouse
    readonly property Item gripBar: mac ? macFrame : pxFrame.titleBar
    // ---- heaven / hell ----
    readonly property bool selfHell: !info || !info.plugin || (info.plugin.realms || []).includes("hell")
    readonly property bool fxOn: StreamMode.effectsOn(screenName)
    readonly property bool burningHere: DesktopWidgets.burning && fxOn
    readonly property real recolor: Theme.hell && !selfHell ? 1 : 0
    // 70–130 %: the frame is drawn scaled, the host takes the scaled size
    readonly property real zoom: DesktopWidgets.scaleOf(widget)
    signal contextMenu(real x, real y)

    function clampX(v) {
        return Math.max(0, Math.min(area.width - width, v));
    }
    function clampY(v) {
        return Math.max(0, Math.min(area.height - height, v));
    }

    visible: !!widget && (wants || DesktopWidgets.editMode)
    readonly property real baseOpacity: wants ? 1 : 0.45

    // ---- which copy shows ----
    // input: over the face while it matters (hover, a drag, edit mode), and a
    // moment longer so the face (a later frame on another surface) is back first
    readonly property bool engaged: interactive && (hover.hovered || dragging || DesktopWidgets.editMode)
    property bool lingering: false
    onEngagedChanged: if (!engaged && !face) {
        lingering = true;
        linger.restart();
    }
    Timer {
        id: linger
        interval: 160
        onTriggered: host.lingering = false
    }
    readonly property bool shown: !face && (engaged || lingering) && !DesktopWidgets.steppedAside(screenName)
    // face: always, except while its input copy is dragged around on top of it —
    // and only if that copy is on show (not stepped aside): otherwise the face
    // itself follows the drag (x/y below), so the widget never vanishes
    readonly property var twin: face ? DesktopWidgets.hosts[uid] || null : null
    opacity: face ? (twin && twin.shown && twin.dragging ? 0 : baseOpacity) : (shown ? baseOpacity : 0)
    // input over its face: the face already draws the translucent body and the
    // shadow — twice they'd darken the widget — so the copy adds only what's on
    // top (text, buttons and their hover). The face reaches the screen a frame or
    // two later than the copy, so the body goes away a moment after it is back.
    readonly property var faceTwin: face ? null : DesktopWidgets.faces[uid] || null
    readonly property bool faceShowing: !!faceTwin && faceTwin.visible && faceTwin.opacity > 0
    property bool overFace: false
    onFaceShowingChanged: {
        if (faceShowing)
            faceLag.restart();
        else {
            faceLag.stop();
            overFace = false;
        }
    }
    Timer {
        id: faceLag
        interval: 60
        onTriggered: host.overFace = host.faceShowing
    }
    width: Math.round(frame.width * zoom)
    height: Math.round(frame.height * zoom)
    // where it was put (negative: from the right or the bottom), then clear of the widgets
    // before it (DesktopWidgets.settledPlace: sizes grow with the art pixel and the fonts)
    readonly property point place: widget ? DesktopWidgets.settledPlace(uid, screenName, clampX(widget.x < 0 ? area.width + widget.x - width : widget.x), clampY(widget.y < 0 ? area.height + widget.y - height : widget.y), width, height, area.width, area.height) : Qt.point(0, 0)
    x: dragging ? DesktopWidgets.drag.x : place.x
    y: dragging ? DesktopWidgets.drag.y : place.y

    Component.onCompleted: {
        face ? DesktopWidgets.registerFace(uid, host) : DesktopWidgets.registerHost(uid, host);
        overFace = faceShowing;
    }
    Component.onDestruction: face ? DesktopWidgets.unregisterFace(uid, host) : DesktopWidgets.unregisterHost(uid, host)

    HoverHandler {
        id: hover
        enabled: !host.face
    }

    // under the widget: right click on a bare spot → the desktop menu; the wheel
    // resizes in edit mode or with Ctrl
    ContextClick {
        anchors.fill: parent
        enabled: !host.face
        z: -1
        onMenu: (x, y) => {
            const p = mapToItem(host.area, x, y);
            host.contextMenu(p.x, p.y);
        }
        onWheel: w => {
            if (DesktopWidgets.editMode || (w.modifiers & Qt.ControlModifier)) {
                const notch = (w.angleDelta.y || w.angleDelta.x) / 120;
                if (notch)
                    DesktopWidgets.setScale(host.uid, host.zoom + notch * 0.05);
            } else {
                w.accepted = false;
            }
        }
    }

    // ---- dragging by the title bar (PxWindow's own title MouseArea), or by the whole
    // macOS card in edit mode (MacWidgetCard.dragArea) ----
    property point dragStart
    property point dragOrigin
    function endDrag() {
        const d = DesktopWidgets.drag;
        if (d.uid !== uid)
            return;
        if (Math.abs(d.x - dragOrigin.x) + Math.abs(d.y - dragOrigin.y) > 1)
            DesktopWidgets.move(uid, d.x, d.y);
        // the saved position is already in place, stop following the pointer
        Qt.callLater(() => DesktopWidgets.drag = {
                "uid": "",
                "x": 0,
                "y": 0
            });
    }
    Connections {
        target: host.grip
        enabled: !host.face
        function onPressed(m) {
            // a card moves only in edit mode (outside it the press is the content's)
            if (host.mac && !DesktopWidgets.editMode)
                return;
            host.dragStart = host.grip.mapToItem(host.area, m.x, m.y);
            host.dragOrigin = Qt.point(host.x, host.y);
            DesktopWidgets.drag = {
                "uid": host.uid,
                "x": host.x,
                "y": host.y
            };
        }
        function onPositionChanged(m) {
            if (!host.dragging)
                return;
            const p = host.grip.mapToItem(host.area, m.x, m.y);
            DesktopWidgets.drag = {
                "uid": host.uid,
                "x": host.clampX(host.dragOrigin.x + p.x - host.dragStart.x),
                "y": host.clampY(host.dragOrigin.y + p.y - host.dragStart.y)
            };
        }
        function onReleased() {
            host.endDrag();
        }
        // the grab was taken mid-drag (hot corner, a compositor grab)
        function onCanceled() {
            host.endDrag();
        }
        function onDoubleClicked() {
            DesktopWidgets.editMode = !DesktopWidgets.editMode;
        }
    }
    Binding {
        target: pxFrame.titleMouse
        property: "cursorShape"
        value: host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }
    Binding {
        target: macFrame.dragArea
        property: "cursorShape"
        value: host.dragging ? Qt.ClosedHandCursor : DesktopWidgets.editMode ? Qt.OpenHandCursor : Qt.ArrowCursor
    }

    // Anything clickable in the content? Buttons (PxButton), MouseAreas and tap
    // handlers all have a `clicked` or `tapped` signal. A content item may say
    // so itself: `readonly property bool passive: true`.
    function scanInput(item, depth) {
        if (!item || depth > 12)
            return false;
        if (typeof item.clicked === "function" || typeof item.tapped === "function")
            return true;
        for (const c of item.children || [])
            if (scanInput(c, depth + 1))
                return true;
        return false;
    }
    function checkInput() {
        const it = content.item;
        interactive = !!it && (it.passive === undefined ? scanInput(it, 0) : !it.passive);
    }

    // ---- scripted input for `angelos widgetClick/widgetProbe` (tests) ----
    // The deepest visible, enabled item under the point that has `signalName`.
    function targetAt(px, py, signalName) {
        let item = host, x = px, y = py, found = null;
        while (item) {
            if (item !== host && item.visible && item.enabled !== false && typeof item[signalName] === "function")
                found = {
                    "item": item,
                    "x": x,
                    "y": y
                };
            const child = item.childAt(x, y);
            if (!child)
                break;
            const p = item.mapToItem(child, x, y);
            item = child;
            x = p.x;
            y = p.y;
        }
        return found;
    }
    function isTitleDrag(px, py) {
        if (mac && !DesktopWidgets.editMode)
            return false;
        const p = host.mapToItem(gripBar, px, py);
        const t = targetAt(px, py, "clicked");
        return p.x >= 0 && p.y >= 0 && p.x < gripBar.width && p.y < gripBar.height && (!t || t.item === grip);
    }
    function takes(px, py, button) {
        const t = targetAt(px, py, "clicked");
        return !!t && t.item !== grip && (t.item.acceptedButtons === undefined || !!(t.item.acceptedButtons & button));
    }
    function press(px, py, button) {
        sim.mousePress(host, px, py, button, Qt.NoModifier, -1);
    }
    function release(px, py, button) {
        sim.mouseRelease(host, px, py, button, Qt.NoModifier, -1);
    }
    function cursorAt(px, py) {
        if (isTitleDrag(px, py))
            return Qt.OpenHandCursor;
        const t = targetAt(px, py, "clicked");
        return t && t.item.cursorShape !== undefined ? t.item.cursorShape : Qt.ArrowCursor;
    }
    TestEvent {
        id: sim
    }
    // dev (`angelos widgetDrag uid dx dy ms`): a real drag by the title bar, replayed
    function devDrag(dx, dy, ms) {
        // in the desk's coordinates: the widget itself moves under the pointer
        const p = gripBar.mapToItem(host.area, gripBar.width / 3, Math.min(gripBar.height / 2, Theme.u * 8));
        const n = Math.max(2, Math.round(ms / 16));
        const path = [];
        for (let i = 1; i <= n; i++)
            path.push({
                "x": p.x + dx * i / n,
                "y": p.y + dy * i / n
            });
        path.push({
            "x": p.x + dx,
            "y": p.y + dy,
            "up": true
        });
        sim.mousePress(host.area, p.x, p.y, Qt.LeftButton, Qt.NoModifier, -1);
        dragReplay.path = path;
        dragReplay.start();
    }
    Timer {
        id: dragReplay
        property var path: []
        interval: 16
        repeat: true
        onTriggered: {
            const q = path.shift();
            if (q.up)
                sim.mouseRelease(host.area, q.x, q.y, Qt.LeftButton, Qt.NoModifier, -1);
            else
                sim.mouseMove(host.area, q.x, q.y, -1, Qt.LeftButton, Qt.NoModifier);
            if (!path.length)
                stop();
        }
    }

    // room around the frame for its shadow and the burn; the frame itself sits at the
    // host's (0, 0)
    Item {
        id: canvas
        readonly property int pad: host.mac ? DesktopWidgets.mpx(44) : Theme.u * 12
        x: -pad
        y: -pad
        width: host.width + pad * 2
        height: host.height + pad * 2
        layer.enabled: host.burningHere || host.recolor > 0
        layer.smooth: false
        layer.effect: ShaderEffect {
            readonly property real burn: host.burningHere ? DesktopWidgets.burn : 1
            readonly property real mode: DesktopWidgets.burnTo === "heaven" ? 1 : 0
            readonly property real recolor: host.recolor
            readonly property real seed: (host.uid.length * 7.31) % 13
            readonly property size cell: Qt.size(Theme.u * host.zoom / Math.max(1, canvas.width), Theme.u * host.zoom / Math.max(1, canvas.height))
            readonly property rect box: Qt.rect(canvas.pad / canvas.width, canvas.pad / canvas.height, (canvas.pad + host.width) / canvas.width, (canvas.pad + host.height) / canvas.height)
            readonly property color cDark: Theme.hellBody
            readonly property color cBlood: Theme.hellBlood
            readonly property color cAccent: Theme.hellAccent
            readonly property color cFlame: Theme.hellFlame
            readonly property color cBone: Theme.hellText
            fragmentShader: Qt.resolvedUrl("../../shaders/hell_widget.frag.qsb")
        }

        PxWindow {
            id: pxFrame
            visible: !host.mac
            x: canvas.pad
            y: canvas.pad
            hell: Theme.hell
            flamesLive: !host.mac && (host.face ? !Shell.hiddenScreen(host.screenName) : host.shown)
            trim: !host.overFace
            scale: host.zoom
            transformOrigin: Item.TopLeft
            width: Math.max(Theme.u * 70, content.implicitWidth + (inset + bodyPadding) * 2)
            height: titleHeight + content.implicitHeight + bodyPadding * 2 + inset * 2 + Theme.u * 2
            readonly property int inset: Theme.u * 2
            title: DesktopWidgets.titleOf(host.info)
            icon: host.info ? host.info.icon : "heart"
            compact: true
            decor: false
            bodyColor: host.overFace ? "transparent" : Theme.panel
            shadow: Config.appearance.shadows && !host.overFace
            closable: DesktopWidgets.editMode
            active: !host.dragging
            onCloseClicked: DesktopWidgets.remove(host.uid)

            Loader {
                id: content
                // the pixel window's body, or the card's
                parent: host.mac ? macFrame.bodyItem : pxFrame.bodyItem
                width: implicitWidth
                height: implicitHeight
                // the input copy of a widget with nothing to click runs nothing: the face shows it
                visible: host.face || host.interactive
                onLoaded: host.checkInput()
                // a plugin changed by Plugin Studio comes back through a new path
                readonly property string src: host.info && host.info.plugin ? Plugins.url(host.info.plugin, host.info.plugin.desktopWidget) : ""
                onSrcChanged: if (item) {
                    source = "";
                    load();
                }
                Component.onCompleted: load()
                function load() {
                    if (!host.widget || !host.info)
                        return;
                    const props = {
                        "screenName": host.screenName,
                        "widget": Qt.binding(() => host.widget)
                    };
                    if (host.info.plugin) {
                        props.plugin = Plugins.context(host.info.plugin);
                        setSource(src, props);
                    } else {
                        const name = host.info.type.charAt(0).toUpperCase() + host.info.type.slice(1);
                        setSource(Qt.resolvedUrl("widgets/" + ({
                                "Nowplaying": "NowPlaying"
                            }[name] || name) + "Widget.qml"), props);
                    }
                }
            }
        }

        MacWidgetCard {
            id: macFrame
            visible: host.mac
            x: canvas.pad
            y: canvas.pad
            scale: host.zoom
            transformOrigin: Item.TopLeft
            width: content.implicitWidth + padding * 2
            height: content.implicitHeight + padding * 2
            editing: DesktopWidgets.editMode && !host.face
            closable: DesktopWidgets.editMode
            glassBody: !host.overFace
            shadow: Config.appearance.shadows && !host.overFace
            backdrop: host.face ? host.backdrop : null
            backdropOrigin: Qt.point(host.x, host.y)
            backdropScale: host.zoom
            onCloseClicked: DesktopWidgets.remove(host.uid)
        }
    }
}
