pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The angel ↔ demon swap shakes the screen (Angel.quake): `grim` freezes her
// screen and the frozen frame jolts about for a moment. When the demon comes,
// 8-bit rocks tumble down from the top and bounce off the floor (Sounds
// "rocks") — the rocks are hers only. Then Angel goes on (Angel.quakeDone). The frame is grabbed by grim like
// SwitchFx does (ScreencopyView crashes Quickshell 0.3.1 on two monitors, 0.3.2 when one is made again).
// Mapped only while it shakes, never takes input. Settings → Y2K → Screen shake.
Scope {
    id: root

    property string screenName: ""
    property string kind: "hell"             // hell: with the demon's rocks | heaven: the shake alone
    property string phase: "idle"            // idle | capture | shake
    property int serial: 0                   // cache-buster for the frame file
    property real t: 0                       // 0..1 through the shake
    property int tick: 0
    readonly property int duration: 1000
    readonly property string shotPath: WorkspaceAnim.runtimeDir + "/quake-" + screenName.replace(/[^A-Za-z0-9_-]/g, "_") + ".ppm"

    Connections {
        target: Angel
        function onQuake(name, k) {
            root.start(name, k);
        }
    }
    function start(name, k) {
        if (phase !== "idle")
            finish(true);                    // the new swap owns Angel's callback now
        screenName = name;
        kind = k || "hell";
        t = 0;
        tick = 0;
        phase = "capture";
        grab.command = ["grim", "-o", name, "-t", "ppm", shotPath];
        grab.running = true;
        timeout.restart();
    }
    function captured() {
        if (phase !== "capture")
            return;
        serial++;
        frameUrl = "file://" + shotPath + "?" + serial;
    }
    property string frameUrl: ""
    // the frozen frame is on screen: shake it
    function frameReady() {
        if (phase !== "capture")
            return;
        timeout.stop();
        phase = "shake";
        if (kind === "hell")
            Sounds.play("rocks");
        clock.restart();
    }
    function finish(quiet) {
        clock.stop();
        timeout.stop();
        const was = phase;
        phase = "idle";
        frameUrl = "";
        remove.command = ["rm", "-f", shotPath];
        remove.running = true;
        if (was !== "idle" && !quiet)
            Angel.quakeDone();
    }

    Process {
        id: grab
        onExited: code => code === 0 ? root.captured() : root.finish()
    }
    Process {
        id: remove
    }
    // no frame in time (grim missing, capture refused): no shake, the swap goes on
    Timer {
        id: timeout
        interval: 400
        onTriggered: root.finish()
    }
    // stepped like everything pixel: 24 fps
    Timer {
        id: clock
        interval: 42
        repeat: true
        onTriggered: {
            root.tick++;
            root.t = Math.min(1, root.t + interval / root.duration);
            if (root.t >= 1)
                root.finish();
        }
    }

    LazyLoader {
        active: root.phase !== "idle" && !!Shell.screenByName(root.screenName)

        PanelWindow {
            id: win
            screen: Shell.screenByName(root.screenName)
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-quake"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property bool shaking: root.phase === "shake"
            readonly property int px: Math.max(2, Theme.u * 2)
            // a hard jolt that settles: random steps, a new one every frame
            readonly property real power: shaking ? Theme.u * 13 * Math.pow(1 - root.t, 1.5) : 0
            readonly property point jolt: {
                const i = root.tick;
                const r = n => {
                    const v = Math.sin(i * 12.9898 + n * 78.233) * 43758.5453;
                    return (v - Math.floor(v)) * 2 - 1;
                };
                return Qt.point(Math.round(r(1) * power / px) * px, Math.round(r(2) * power * 0.7 / px) * px);
            }

            // what the shaking frame uncovers at its edges
            Rectangle {
                anchors.fill: parent
                visible: win.shaking
                color: root.kind === "heaven" ? "#f4ecff" : "#0c0308"
            }
            Image {
                id: frame
                width: parent.width
                height: parent.height
                x: win.jolt.x
                y: win.jolt.y
                visible: win.shaking
                source: root.frameUrl
                asynchronous: false
                cache: false
                smooth: false
                onStatusChanged: {
                    if (status === Image.Ready)
                        root.frameReady();
                    else if (status === Image.Error)
                        root.finish();
                }
            }

            // the demon's 8-bit rocks: fall from the top with gravity, bounce once off the floor
            Canvas {
                id: rocks
                visible: win.shaking && root.kind === "hell"
                width: Math.ceil(win.width / win.px)
                height: Math.ceil(win.height / win.px)
                scale: win.px
                transformOrigin: Item.TopLeft
                x: win.jolt.x
                y: win.jolt.y
                smooth: false
                antialiasing: false
                renderTarget: Canvas.Image
                // the last moment: the stones fade out with the shake
                opacity: root.t > 0.82 ? Math.round((1 - root.t) / 0.18 * 4) / 4 : 1

                readonly property var stones: {
                    let s = root.serial * 7919 + 17;
                    const rnd = () => {
                        s = (s * 16807) % 2147483647;
                        return (s - 1) / 2147483646;
                    };
                    const out = [];
                    const n = Math.round(12 + width / 22);
                    for (let i = 0; i < n; i++)
                        out.push({
                            "x": rnd() * width,
                            "size": 4 + Math.floor(rnd() * 6),
                            "delay": rnd() * 0.3,
                            "vx": (rnd() - 0.5) * 30,
                            "spin": rnd() < 0.5
                        });
                    return out;
                }
                readonly property var colours: ["#1c0c10", "#6e5044", "#a8836c", "#ff8a3a"]
                onVisibleChanged: if (visible)
                    requestPaint()
                Connections {
                    target: root
                    function onTickChanged() {
                        rocks.requestPaint();
                    }
                }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const floor = height - Math.round(Theme.u * 20 / win.px) - 1;
                    const sec = root.t * root.duration / 1000;
                    const g = height * 5;                // pixels per s² at this scale
                    const [ink, dark, light, glow] = rocks.colours;
                    const mid = Qt.tint(dark, Qt.alpha(light, 0.45));
                    for (const st of stones) {
                        const tt = sec - st.delay;
                        if (tt <= 0)
                            continue;
                        const sz = st.size;
                        // fall, then one bounce at a third of the speed
                        let y = -sz + 0.5 * g * tt * tt, x = st.x + st.vx * tt;
                        const hitT = Math.sqrt(2 * floor / g);
                        if (y > floor - sz) {
                            const v = g * hitT * 0.33, after = tt - hitT;
                            y = floor - sz - Math.max(0, v * after - 0.5 * g * after * after);
                            x = st.x + st.vx * hitT + st.vx * 0.5 * after;
                        }
                        x = Math.round(x);
                        y = Math.round(y);
                        // a chunky pixel stone: outline with cut corners, a dark body, a lit
                        // top-left and a glowing ember
                        ctx.fillStyle = ink;
                        ctx.fillRect(x, y + 1, sz + 2, sz);
                        ctx.fillRect(x + 1, y, sz, sz + 2);
                        ctx.fillStyle = dark;
                        ctx.fillRect(x + 1, y + 1, sz, sz);
                        ctx.fillStyle = mid;
                        ctx.fillRect(x + 1, y + 1, sz - 1, sz - 2);
                        ctx.fillStyle = light;
                        ctx.fillRect(x + 2, y + 1, Math.max(1, Math.floor(sz / 2)), 1);
                        ctx.fillRect(x + 1, y + 2, 1, Math.max(1, Math.floor(sz / 3)));
                        ctx.fillStyle = glow;
                        ctx.fillRect(st.spin ? x + sz - 1 : x + 2, y + sz - 1, 1, 1);
                    }
                }
            }

            RightClickGuard {}
        }
    }
}
