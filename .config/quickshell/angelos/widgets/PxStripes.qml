import QtQuick
import qs.config

// RetroUI's striped fill: diagonal stripes of the colour on a lighter band of it, stepped on the
// art-pixel grid (no smooth slants). `running`: they crawl along, a step at a time, while the work
// goes on (a progress bar's fill, PxProgress and the Halo's downloads).
Canvas {
    id: root

    property color color: Theme.accent
    property color light: Theme.mix(color, "#ffffff", 0.35)
    property bool running: false
    property int pixel: Theme.u
    property int phase: 0

    readonly property int period: pixel * 6

    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()
    onPhaseChanged: requestPaint()

    Timer {
        running: root.running && root.visible && root.width > 0 && !Motion.calm
        repeat: true
        interval: 110
        onTriggered: root.phase = (root.phase + 1) % 6
    }

    onPaint: {
        const g = getContext("2d");
        const p = pixel;
        g.reset();
        g.fillStyle = root.light;
        g.fillRect(0, 0, width, height);
        g.fillStyle = root.color;
        const rows = Math.ceil(height / p);
        for (let r = 0; r < rows; r++) {
            // each row a step to the right: the slant is whole art pixels
            const shift = ((r + phase) % 6) * p;
            for (let x = -period + shift; x < width; x += period)
                g.fillRect(x, r * p, p * 3, p);
        }
    }
}
