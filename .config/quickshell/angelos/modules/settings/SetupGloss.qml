import QtQuick
import qs.config

// The gloss passing over a card or a button of the setup wizard, in pixels: three hard stripes
// (3, 2 and 1 art pixels wide), slanted 45° as a staircase of whole art pixels, no blur. Drawn
// once for its size (a Canvas: baked, then only moved) and sampled without smoothing, it glides
// across in ⅔ s on the render thread, frame by frame with the screen. Its host (SetupFx) sends it
// now and then — one at a time — and it passes whenever the pointer comes over it. Never while
// motion is off.
Item {
    id: root

    property var host: null                  // the SetupFx that times it
    property bool hovered: false
    property real strength: Theme.dark ? 0.2 : 0.4
    readonly property bool passing: across.running
    clip: true

    function pass() {
        if (!host || !host.live || !host.moving || width <= 0 || passing || host.chroma)
            return;
        across.restart();
    }
    onHoveredChanged: if (hovered)
        pass()
    Component.onCompleted: if (host)
        host.addGloss(root)
    Component.onDestruction: if (host)
        host.removeGloss(root)

    Canvas {
        id: band
        readonly property int u: Theme.u
        readonly property int rows: Math.ceil(root.height / u)
        // the stripes, in art pixels from the band's edge: [from, width]
        readonly property var stripes: [[0, 3], [5, 2], [8, 1]]
        // painted once while parked out of sight (a Canvas out of view would wait to be
        // painted until it shows: the first frame of a pass would be empty)
        width: (rows + 9) * u
        height: rows * u
        x: -width
        opacity: root.strength
        smooth: false
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "#ffffff";
            for (let r = 0; r < rows; r++)
                for (const s of stripes)
                    ctx.fillRect((rows - 1 - r + s[0]) * u, r * u, s[1] * u, u);
        }
    }
    XAnimator {
        id: across
        target: band
        from: -band.width
        to: root.width
        duration: 640
        easing.type: Easing.InOutQuad
    }
}
