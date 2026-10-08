pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "../../services/CobwebLayout.js" as Lay

// Cobwebs over the windows (services/Cobweb): one see-through layer per screen above the
// windows. It takes the pointer only on the threads (cells of 8 art px, the views' `hits`; never
// a window's top strip, where it is dragged by): elsewhere the pointer and clicks go to the apps.
// A click that lands on a thread is handed on (scripts/vpointer.py) once the layer has let go;
// a drag that starts on one brushes through the web. During the shake's QTE the whole window is
// its: swipes with the mouse, arrows/WASD with the keyboard, Esc lets go.
Variants {
    model: Shell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property string name: modelData.name
        readonly property var list: (Cobweb.rev, Cobweb.rectsOn(name))
        readonly property var ids: list.map(r => r.id)
        readonly property var qrect: Cobweb.qte ? list.find(r => r.id === Cobweb.qte.id && r.active) || null : null
        readonly property bool hidden: Cobweb.hiddenOn(name)

        screen: modelData
        visible: Cobweb.inside && list.length > 0 && !hidden
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "angelos-cobweb"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: qrect ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        function rectFor(id) {
            return list.find(r => r.id === id) || null;
        }

        // the desk in view (niri's idx), sliding to another one the way niri switches desks: every
        // desk's webs stand a screen's height and a tenth apart (CobwebView.y)
        readonly property var activeWs: Niri.activeWorkspace(name)
        readonly property int wsTarget: activeWs ? activeWs.idx : 0
        property real wsPos: wsTarget
        property real _wsFrom: wsTarget
        property double _wsT0: 0
        property bool wsMoving: false
        onWsTargetChanged: {
            _wsFrom = wsPos;
            _wsT0 = Date.now() - Cobweb.lagMs;
            wsMoving = true;
            wsStep();
        }
        function wsStep() {
            const a = Lay.animAt(Cobweb.anims.ws, Date.now() - _wsT0, Cobweb.anims.slowdown);
            wsPos = a.done ? wsTarget : _wsFrom + (wsTarget - _wsFrom) * a.p;
            if (a.done)
                wsMoving = false;
        }
        FrameAnimation {
            running: win.wsMoving
            onTriggered: win.wsStep()
        }
        onWsMovingChanged: later.restart()

        // the input region: the threads, the QTE's window, nothing while a click is handed on
        property bool passing: false
        property var regs: []
        Component {
            id: regionC
            Region {}
        }
        function rebuild() {
            for (const r of regs)
                r.destroy();
            const out = [];
            if (!passing) {
                if (qrect)
                    out.push(regionC.createObject(win, {
                        "x": qrect.x,
                        "y": qrect.y,
                        "width": qrect.w,
                        "height": qrect.h
                    }));
                else if (!wsMoving)
                    for (let i = 0; i < holder.children.length; i++) {
                        const v = holder.children[i];
                        if (v.hits && !v.moving)
                            for (const h of v.hits)
                                out.push(regionC.createObject(win, {
                                    "x": h.x,
                                    "y": h.y,
                                    "width": h.w,
                                    "height": h.h
                                }));
                    }
            }
            regs = out;
        }
        Timer {
            id: later
            interval: 60
            onTriggered: win.rebuild()
        }
        onQrectChanged: later.restart()
        onPassingChanged: later.restart()
        mask: Region {
            regions: win.regs
        }

        Item {
            id: holder
            anchors.fill: parent
        }
        Variants {
            model: win.ids
            CobwebView {
                required property var modelData
                parent: holder
                winId: modelData
                rect: (Cobweb.rev, win.rectFor(modelData))
                shown: win.visible
                wsPos: win.wsPos
                screenH: win.height
                onHitsChanged: later.restart()
                onMovingChanged: later.restart()
            }
        }

        function viewAt(x, y) {
            for (let i = holder.children.length - 1; i >= 0; i--) {
                const v = holder.children[i];
                if (v.visible && !v.moving && v.rect && v.rect.active && x >= v.x && y >= v.y && x < v.x + v.width && y < v.y + v.height)
                    return v;
            }
            return null;
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            property real sx: 0
            property real sy: 0
            property bool flung: false
            property real lastX: -1
            property real lastY: -1
            onPositionChanged: m => {
                if (win.qrect) {
                    if (pressed && !flung) {
                        const dx = m.x - sx, dy = m.y - sy;
                        if (Math.hypot(dx, dy) > Theme.u * 20) {
                            flung = true;
                            Cobweb.swipe(Math.abs(dx) > Math.abs(dy) ? (dx < 0 ? "left" : "right") : (dy < 0 ? "up" : "down"));
                        }
                    }
                    return;
                }
                // only a pointer that moves touches: the input region changing under a resting
                // one (a thread snapped, the mask rebuilt) brings it back at the same place
                if (Math.abs(m.x - lastX) < 1 && Math.abs(m.y - lastY) < 1)
                    return;
                lastX = m.x;
                lastY = m.y;
                const v = win.viewAt(m.x, m.y);
                if (v)
                    v.touchAt(m.x - v.x, m.y - v.y);
            }
            // a press on a thread holds the web: dragged, it brushes through the threads (each
            // one crossed is touched; shaken back and forth, the quick-time event starts —
            // Cobweb.pressId); let go where it was pressed, it was a click: it goes on to the
            // window under it once the layer has let go
            onPressed: m => {
                sx = m.x;
                sy = m.y;
                flung = false;
                if (win.qrect)
                    return;
                const v = win.viewAt(m.x, m.y);
                Cobweb.pressId = v ? v.winId : -1;
            }
            onReleased: m => {
                Cobweb.pressId = -1;
                if (win.qrect || Math.hypot(m.x - sx, m.y - sy) > Theme.u * 4)
                    return;
                const b = m.button === Qt.RightButton ? 273 : m.button === Qt.MiddleButton ? 274 : 272;
                win.passing = true;
                win.rebuild();
                handOn.button = b;
                handOn.restart();
            }
            onCanceled: Cobweb.pressId = -1
            onWheel: w => {
                if (win.qrect)
                    return;
                win.passing = true;
                win.rebuild();
                Cobweb.wheel(-w.angleDelta.y / 120, w.angleDelta.x / 120);
                back.restart();
            }
        }
        Timer {
            id: handOn
            property int button: 272
            interval: 30
            onTriggered: {
                Cobweb.pass(button);
                back.restart();
            }
        }
        Timer {
            id: back
            interval: 500
            onTriggered: win.passing = false
        }

        Item {
            focus: !!win.qrect
            Keys.onPressed: e => {
                const k = {
                    [Qt.Key_Left]: "left",
                    [Qt.Key_A]: "left",
                    [Qt.Key_Right]: "right",
                    [Qt.Key_D]: "right",
                    [Qt.Key_Up]: "up",
                    [Qt.Key_W]: "up",
                    [Qt.Key_Down]: "down",
                    [Qt.Key_S]: "down"
                }[e.key];
                if (k)
                    Cobweb.swipe(k);
                else if (e.key === Qt.Key_Escape)
                    Cobweb.cancelQte();
                e.accepted = true;
            }
        }

        CobwebQte {
            visible: !!win.qrect
            // over its window, kept on the screen
            x: win.qrect ? Math.max(Theme.u * 4, Math.min(win.width - width - Theme.u * 4, win.qrect.x + (win.qrect.w - width) / 2)) : 0
            y: win.qrect ? win.qrect.y + (win.qrect.h - height) / 2 : 0
        }

        RightClickGuard {}
    }
}
