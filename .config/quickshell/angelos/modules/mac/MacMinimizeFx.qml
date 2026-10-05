pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Minimizing as macOS does it, Genie or Scale (Config.mac.minimizeEffect): the window's snapshot
// (services/Minimize took it with grim) bends and pours into its place in the Dock (shaders/genie.vert)
// or shrinks into it; a click in the Dock plays it backwards, out to where the window goes.
// A layer over everything on the window's screen, taking no input,
// up only while something flies (Minimize.flights). The Dock writes where its items are
// (Minimize.dockSlots); the place is read each frame, so the item that appears in the Dock a
// moment after the window has gone is where the snapshot lands.
PanelWindow {
    id: win

    required property var modelData
    readonly property string screenName: modelData.name
    readonly property var mine: Minimize.flights.filter(f => f.output === screenName)

    screen: modelData
    visible: mine.length > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-minimize"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Repeater {
        model: win.mine

        Item {
            id: fx
            required property var modelData
            readonly property bool genie: Minimize.effect === "genie"
            width: win.width
            height: win.height
            // where the window is, in this screen's coordinates
            readonly property var home: [modelData.rect[0] - win.modelData.x, modelData.rect[1] - win.modelData.y, modelData.rect[2], modelData.rect[3]]
            property real t: 0                 // 0 at the window .. 1 in the Dock
            property var dock: [win.width / 2, win.height - GoldenGate.px(40), GoldenGate.px(48)]

            function place() {
                dock = Minimize.slotOf(win.screenName, modelData.id) || [win.width / 2, win.height - GoldenGate.px(40), GoldenGate.px(48)];
                if (genie)
                    return;
                const h = home, d = dock;
                // the snapshot keeps its proportions, fitted into the Dock's square at the end
                const k = Math.min(d[2] * 0.82 / h[2], d[2] * 0.82 / h[3]);
                const w1 = h[2] * k, h1 = h[3] * k;
                const e = t;
                scaled.width = h[2] + (w1 - h[2]) * e;
                scaled.height = h[3] + (h1 - h[3]) * e;
                scaled.x = h[0] + h[2] / 2 + (d[0] - h[0] - h[2] / 2) * e - scaled.width / 2;
                // a curve on the way, like the Dock's: it sinks faster than it moves sideways
                const ey = 1 - Math.pow(1 - e, 1.6);
                scaled.y = h[1] + h[3] / 2 + (d[1] - h[1] - h[3] / 2) * ey - scaled.height / 2;
            }
            onTChanged: place()
            Component.onCompleted: {
                t = modelData.back ? 1 : 0;
                place();
                run.from = t;
                run.to = modelData.back ? 0 : 1;
                run.start();
            }

            Image {
                id: shot
                source: fx.modelData.shot || ""
                visible: false
                smooth: true
                mipmap: true
                cache: false
            }

            // Scale: the snapshot shrinks into the Dock
            Item {
                id: scaled
                visible: !fx.genie
                Image {
                    anchors.fill: parent
                    source: fx.genie ? "" : fx.modelData.shot || ""
                    fillMode: Image.Stretch
                    smooth: true
                    mipmap: true
                    cache: false
                    // a touch of see-through near the Dock, as on a Mac
                    opacity: 1 - 0.15 * fx.t
                }
            }

            // Genie: the snapshot on a mesh bent into the Dock's icon (shaders/genie.vert)
            ShaderEffect {
                visible: fx.genie && shot.status === Image.Ready
                anchors.fill: parent
                mesh: GridMesh {
                    resolution: Qt.size(4, 64)
                }
                property variant source: shot
                property real progress: fx.t
                property vector4d win: Qt.vector4d(fx.home[0], fx.home[1], fx.home[2], fx.home[3])
                // the item's middle, its top, its size (the Dock writes centres)
                property vector4d tgt: Qt.vector4d(fx.dock[0], fx.dock[1] - fx.dock[2] / 2, fx.dock[2] * 0.82, fx.dock[2] * 0.82)
                vertexShader: Qt.resolvedUrl("../../shaders/genie.vert.qsb")
                fragmentShader: Qt.resolvedUrl("../../shaders/genie.frag.qsb")
            }

            NumberAnimation {
                id: run
                target: fx
                property: "t"
                duration: Minimize.flightMs
                // Genie: even, as macOS pours it; Scale — away: slow start, fast into the Dock;
                // back: fast out, settling at the window
                easing.type: fx.genie ? Easing.InOutSine : fx.modelData.back ? Easing.OutCubic : Easing.InOutCubic
                onFinished: Minimize.landed(fx.modelData.key)
            }
        }
    }
}
