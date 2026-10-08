pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The angel shows up: sun rays pour in from the top-right corner of her screen
// for 1.5 s and a little choir sings (Settings → Y2K → Angel or demon). Soft
// rays: each one fades out towards its end and the whole fan fades before the
// window's edge, they sway a little, no flicker. Drawn at 1/4 resolution for
// a light pixel feel; never takes input.
Scope {
    id: root

    property string screenName: ""
    property real t: 0                       // 0..1 through the show

    Connections {
        target: Angel
        function onHeaven(name) {
            root.screenName = name;
            root.t = 0;
            run.restart();
            Sounds.play("choir");
        }
    }
    FrameAnimation {
        id: run
        onTriggered: {
            root.t = Math.min(1, root.t + Math.min(frameTime, 0.1) / 1.5);
            if (root.t >= 1) {
                stop();
                root.screenName = "";
            }
        }
    }

    LazyLoader {
        active: root.screenName !== "" && !!Shell.screenByName(root.screenName)

        PanelWindow {
            id: win
            screen: Shell.screenByName(root.screenName)
            anchors {
                top: true
                bottom: true
                right: true
            }
            implicitWidth: Math.round(screen ? screen.width * 0.5 : 700)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-rays"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property int px: Math.max(2, Theme.u * 2)
            Canvas {
                id: canvas
                width: Math.ceil(win.width / win.px)
                height: Math.ceil(win.height / win.px)
                scale: win.px
                transformOrigin: Item.TopLeft
                smooth: false
                antialiasing: false
                renderTarget: Canvas.Image
                readonly property real t: root.t
                onTChanged: requestPaint()
                function ease(x) {
                    return x < 0 ? 0 : x > 1 ? 1 : 1 - Math.pow(1 - x, 3);
                }
                onPaint: {
                    const ctx = getContext("2d");
                    const w = width, h = height, t = root.t;
                    ctx.globalCompositeOperation = "source-over";
                    ctx.clearRect(0, 0, w, h);
                    // soft in, hold, soft out
                    const alpha = ease(t / 0.22) * (t > 0.62 ? Math.max(0, 1 - ease((t - 0.62) / 0.38)) : 1);
                    if (alpha <= 0.001)
                        return;
                    const sx = w + 4, sy = -6;             // the sun, just off the top-right corner
                    const reach = Math.hypot(w, h) * (0.55 + 0.4 * ease(t / 0.4));
                    const rays = [[0.54, 0.042, 1.0], [0.60, 0.032, 0.8], [0.655, 0.05, 1.0], [0.72, 0.03, 0.7], [0.775, 0.042, 0.9], [0.84, 0.034, 0.75], [0.9, 0.044, 0.6]];
                    for (let i = 0; i < rays.length; i++) {
                        const [a, spread, strength] = rays[i];
                        const ang = Math.PI * a + Math.sin(t * 5 + i * 1.7) * 0.012;
                        const len = reach * (0.75 + 0.25 * strength);
                        // the ray fades out along its length: no hard end
                        const g = ctx.createRadialGradient(sx, sy, 0, sx, sy, len);
                        g.addColorStop(0, Qt.rgba(1, 0.97, 0.82, 0.5 * strength * alpha));
                        g.addColorStop(0.45, Qt.rgba(1, 0.95, 0.75, 0.26 * strength * alpha));
                        g.addColorStop(1, Qt.rgba(1, 0.93, 0.7, 0));
                        ctx.fillStyle = g;
                        ctx.beginPath();
                        ctx.moveTo(sx, sy);
                        ctx.lineTo(sx + Math.cos(ang - spread) * len, sy + Math.sin(ang - spread) * len);
                        ctx.lineTo(sx + Math.cos(ang + spread) * len, sy + Math.sin(ang + spread) * len);
                        ctx.closePath();
                        ctx.fill();
                    }
                    // the sun's glow in the corner
                    const glow = ctx.createRadialGradient(sx, sy, 0, sx, sy, Math.min(w, h) * 0.35);
                    glow.addColorStop(0, Qt.rgba(1, 0.98, 0.86, 0.45 * alpha));
                    glow.addColorStop(1, Qt.rgba(1, 0.98, 0.86, 0));
                    ctx.fillStyle = glow;
                    ctx.fillRect(0, 0, w, h);
                    // a few slow sparkles drifting down, twinkling softly
                    for (let k = 0; k < 16; k++) {
                        const x = w * (0.25 + ((k * 0.37) % 0.75));
                        const y = (h * ((k * 0.23) % 1) + t * h * (0.08 + (k % 3) * 0.03)) % h;
                        const tw = 0.5 + 0.5 * Math.sin(t * 9 + k * 2.1);
                        ctx.fillStyle = Qt.rgba(1, 1, 1, alpha * (0.25 + 0.55 * tw));
                        ctx.fillRect(Math.round(x), Math.round(y), 1, 1);
                        if (k % 4 === 0 && tw > 0.6) {
                            ctx.fillStyle = Qt.rgba(1, 1, 1, alpha * 0.35 * tw);
                            ctx.fillRect(Math.round(x) - 1, Math.round(y), 3, 1);
                            ctx.fillRect(Math.round(x), Math.round(y) - 1, 1, 3);
                        }
                    }
                    // the mask: everything fades out well before the window's left
                    // and bottom edges, so nothing ends on a straight line
                    ctx.globalCompositeOperation = "destination-out";
                    const left = ctx.createLinearGradient(0, 0, w * 0.55, 0);
                    left.addColorStop(0, Qt.rgba(0, 0, 0, 1));
                    left.addColorStop(1, Qt.rgba(0, 0, 0, 0));
                    ctx.fillStyle = left;
                    ctx.fillRect(0, 0, w, h);
                    const bottom = ctx.createLinearGradient(0, h * 0.55, 0, h);
                    bottom.addColorStop(0, Qt.rgba(0, 0, 0, 0));
                    bottom.addColorStop(1, Qt.rgba(0, 0, 0, 1));
                    ctx.fillStyle = bottom;
                    ctx.fillRect(0, 0, w, h);
                    ctx.globalCompositeOperation = "source-over";
                }
            }
            RightClickGuard {}
        }
    }
}
