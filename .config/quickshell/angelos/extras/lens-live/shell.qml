import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// angelOS's live lens, a process of its own (services/Lens starts it when Settings →
// Keyboard and mouse → Lens is "live"): a round (or square) glass beside the pointer
// that magnifies what is around it, frame by frame (ScreencopyView). Beside it, not on
// it: niri's frame of the screen has the lens in it too, so a glass over the very spot
// it shows would show itself — a tunnel. It moves to the other side near an edge.
// Its own process because ScreencopyView can take Quickshell down (Qt Wayland, two
// monitors; in 0.3.2 a view made again after one went) — one view per process lifetime,
// and if it falls only the lens goes, the shell stays. No angelOS modules here (they
// would read and write settings.json from a second process): all it needs comes in
// ANGELOS_LENS, JSON — screen, x, y, zoom, size, shape, crisp, colours, control, shot.
// Inside: the wheel zooms, Shift+wheel resizes, Esc / Q / a right click closes. The
// shell's keys (Mod+Alt+= / - / 0) reach it through the `control` file.
// shot: a test — no input, a picture of the overlay to that path after a moment, exit.
ShellRoot {
    id: root

    readonly property var cfg: {
        try {
            return JSON.parse(Quickshell.env("ANGELOS_LENS") || "{}");
        } catch (e) {
            return {};
        }
    }
    readonly property bool test: !!cfg.shot
    readonly property var steps: [1.5, 2, 3, 4, 6, 8, 12]
    property real zoom: Math.max(1.5, cfg.zoom || 2)
    property int size: cfg.size || 300
    readonly property bool square: cfg.shape === "square"
    readonly property bool crisp: cfg.crisp !== false
    readonly property int u: Math.max(1, cfg.u || 2)

    function zoomIn() {
        zoom = steps.find(s => s > zoom + 0.01) || steps[steps.length - 1];
    }
    function zoomOut() {
        const lower = steps.filter(s => s < zoom - 0.01);
        if (!lower.length)
            Qt.quit();
        else
            zoom = lower[lower.length - 1];
    }
    function resize(by) {
        size = Math.max(120, Math.min(900, size + by * 40));
    }

    // the shell's keys: {"serial": n, "cmd": "in" | "out" | "close"}
    property int seen: -1
    FileView {
        path: root.cfg.control || ""
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const m = JSON.parse(text());
                if (root.seen < 0) {
                    root.seen = m.serial;          // what was there before we started
                    return;
                }
                if (m.serial === root.seen)
                    return;
                root.seen = m.serial;
                if (m.cmd === "in")
                    root.zoomIn();
                else if (m.cmd === "out")
                    root.zoomOut();
                else if (m.cmd === "close")
                    Qt.quit();
            } catch (e) {}
        }
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === root.cfg.screen) || Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: root.test ? empty : null
        Region {
            id: empty
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "angelos-lens"
        WlrLayershell.keyboardFocus: root.test ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

        // the pointer: where the shell last saw it until it moves here
        property real px: root.cfg.x >= 0 ? root.cfg.x : width / 2
        property real py: root.cfg.y >= 0 ? root.cfg.y : height / 2
        readonly property real radius: root.size / 2
        readonly property real rim: Math.max(2, root.u * 1.5)
        // the glass beside the pointer, never over what it shows (+ its rim and a gap)
        readonly property real reach: radius + radius / root.zoom + rim * 2 + root.u * 8
        readonly property bool fitsRight: px + reach + radius + 4 <= width
        readonly property bool fitsLeft: px - reach - radius - 4 >= 0
        readonly property bool sideways: fitsRight || fitsLeft
        readonly property real gx: !sideways ? Math.max(radius + 4, Math.min(width - radius - 4, px)) : fitsRight ? px + reach : px - reach
        readonly property real gy: sideways ? Math.max(radius + 4, Math.min(height - radius - 4, py)) : (py - reach - radius - 4 >= 0 ? py - reach : py + reach)
        property real glassX: gx
        property real glassY: gy
        Behavior on glassX {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutCubic
            }
        }
        Behavior on glassY {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: stage
            anchors.fill: parent

        ScreencopyView {
            id: view
            width: win.width
            height: win.height
            captureSource: win.screen
            live: true
            paintCursor: false
        }
        ShaderEffectSource {
            id: frame
            sourceItem: view
            hideSource: true
            live: true
            smooth: !root.crisp
            width: 1
            height: 1
            visible: false
        }
        ShaderEffect {
            id: lens
            anchors.fill: parent
            visible: view.hasContent
            property var source: frame
            property point center: Qt.point(win.glassX, win.glassY)
            property point spot: Qt.point(win.px, win.py)
            property size itemSize: Qt.size(width, height)
            property size texSize: Qt.size(Math.max(1, view.sourceSize.width), Math.max(1, view.sourceSize.height))
            property real radius: win.radius
            property real zoom: root.zoom
            property real shape: root.square ? 1 : 0
            property real crisp: root.crisp ? 1 : 0
            property real rim: win.rim
            property color rimColor: root.cfg.accent || "#ff7eb6"
            property color edgeColor: root.cfg.edge || "#2b1b33"
            // a copy of shaders/lens.frag.qsb: this process may not read outside its folder
            fragmentShader: Qt.resolvedUrl("lens.frag.qsb")
        }
        // where the pointer is (the real one is hidden): a pixel cross — the glass shows it too
        Item {
            x: Math.round(win.px)
            y: Math.round(win.py)
            readonly property int arm: root.u * 4
            readonly property int t: Math.max(1, root.u / 2)
            Rectangle {
                x: -parent.arm
                y: -parent.t
                width: parent.arm * 2 + parent.t
                height: parent.t * 3
                color: root.cfg.edge || "#2b1b33"
            }
            Rectangle {
                x: -parent.t
                y: -parent.arm
                width: parent.t * 3
                height: parent.arm * 2 + parent.t
                color: root.cfg.edge || "#2b1b33"
            }
            Rectangle {
                x: -parent.arm + parent.t
                y: 0
                width: parent.arm * 2 - parent.t
                height: parent.t
                color: "#ffffff"
            }
            Rectangle {
                x: 0
                y: -parent.arm + parent.t
                width: parent.t
                height: parent.arm * 2 - parent.t
                color: "#ffffff"
            }
        }
        // ×3 · LIVE on the rim
        Rectangle {
            visible: lens.visible
            x: Math.round(win.glassX + win.radius * 0.62)
            y: Math.round(win.glassY + win.radius * 0.72)
            width: zoomText.implicitWidth + root.u * 6
            height: zoomText.implicitHeight + root.u * 2
            color: root.cfg.accent || "#ff7eb6"
            border.color: root.cfg.edge || "#2b1b33"
            border.width: Math.max(1, root.u / 2)
            Text {
                id: zoomText
                anchors.centerIn: parent
                font.family: root.cfg.font || "monospace"
                font.pixelSize: root.cfg.fontPx || 11
                font.bold: true
                color: root.cfg.selectText || "#ffffff"
                text: "×" + (Math.round(root.zoom * 10) / 10) + " · LIVE"
            }
        }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.test
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPositionChanged: m => {
                win.px = m.x;
                win.py = m.y;
            }
            onPressed: m => {
                if (m.button !== Qt.LeftButton)
                    Qt.quit();
            }
            onWheel: w => {
                const s = w.angleDelta.y > 0 ? 1 : w.angleDelta.y < 0 ? -1 : 0;
                if (!s)
                    return;
                if (w.modifiers & Qt.ShiftModifier)
                    root.resize(s);
                else if (s > 0)
                    root.zoomIn();
                else
                    root.zoomOut();
            }
        }
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape || e.key === Qt.Key_Q)
                    Qt.quit();
                else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal)
                    root.zoomIn();
                else if (e.key === Qt.Key_Minus)
                    root.zoomOut();
                else
                    return;
                e.accepted = true;
            }
        }
        // the shell's RightClickGuard (no angelOS modules in this process): Qt 6.11
        // segfaults on a right press on a window's very first pixel with nothing focused
        MouseArea {
            z: -1
            width: 1
            height: 1
            acceptedButtons: Qt.RightButton
        }

        Timer {
            running: root.test
            interval: 1600
            onTriggered: {
                console.log("LENS-LIVE hasContent=" + view.hasContent + " source=" + view.sourceSize.width + "x" + view.sourceSize.height);
                stage.grabToImage(r => {
                    r.saveToFile(root.cfg.shot);
                    console.log("LENS-LIVE saved");
                    Qt.quit();
                });
            }
        }
    }
}
