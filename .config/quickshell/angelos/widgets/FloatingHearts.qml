import QtQuick
import qs.config

// Pixel hearts drifting upwards with a little sway: gliding frame by frame with the screen
// (`glide`, the default since Qt 6.12 renders on its own thread on NVIDIA too), or stepped
// at 12 fps (`glide: false`).
Item {
    id: root

    property int count: 16
    property bool running: visible
    property real speed: 1
    property real minOpacity: 0.12
    property real maxOpacity: 0.4
    property int interval: 83               // a step's length (ms); the speed stays the same
    // smooth instead: each heart glides on the render thread (animators), frame by frame with
    // the screen, whatever the GUI thread does (the setup wizard)
    property bool glide: true

    Repeater {
        id: rep
        model: root.count
        PxIcon {
            id: h
            required property int index
            property real vy: 0.5 + Math.random()
            property real phase: Math.random() * 6.28
            property real baseX: Math.random() * root.width
            readonly property real pxPerSec: vy * Theme.u * 18 * root.speed
            readonly property bool gliding: root.glide && root.running && root.width > 0
            onGlidingChanged: gliding ? lap(Math.random() * root.height) : (rise.stop(), sway.stop())
            function lap(fromY) {
                rise.from = fromY;
                rise.to = -height;
                rise.duration = Math.max(1, (fromY + height) / pxPerSec * 1000);
                rise.restart();
                sway.restart();
            }
            YAnimator {
                id: rise
                target: h
                onFinished: if (h.gliding) {
                    h.baseX = Math.random() * root.width;
                    h.lap(root.height + Theme.u * 6);
                }
            }
            SequentialAnimation {
                id: sway
                loops: Animation.Infinite
                XAnimator {
                    target: h
                    from: h.baseX - Theme.u * 4
                    to: h.baseX + Theme.u * 4
                    duration: 2100
                    easing.type: Easing.InOutSine
                }
                XAnimator {
                    target: h
                    from: h.baseX + Theme.u * 4
                    to: h.baseX - Theme.u * 4
                    duration: 2100
                    easing.type: Easing.InOutSine
                }
            }
            name: index % 4 === 0 ? "sparkle" : index % 3 === 0 ? "heartSmall" : "heart"
            pixel: Math.max(1, Theme.u * (1 + index % 3))
            hollow: index % 2 === 0
            fill: index % 2 ? Theme.accent : Theme.accent2
            opacity: root.minOpacity + (index % 5) / 4 * (root.maxOpacity - root.minOpacity)
            x: baseX
            y: Math.random() * root.height
        }
    }
    Timer {
        interval: root.interval
        repeat: true
        running: root.running && !root.glide && root.width > 0
        onTriggered: root.step()
    }
    // one step (a clock outside may drive it instead: the setup wizard's, so its pulse and the
    // hearts repaint together)
    function step() {
        if (glide)
            return;
        const k = interval / 83;
        for (let i = 0; i < rep.count; i++) {
            const h = rep.itemAt(i);
            if (!h)
                continue;
            h.y -= h.vy * Theme.u * 1.5 * speed * k;
            h.phase += 0.15 * k;
            h.x = Math.round(h.baseX + Math.sin(h.phase) * Theme.u * 4);
            if (h.y < -h.height) {
                h.y = height + Theme.u * 6;
                h.baseX = Math.random() * width;
            }
        }
    }
}
