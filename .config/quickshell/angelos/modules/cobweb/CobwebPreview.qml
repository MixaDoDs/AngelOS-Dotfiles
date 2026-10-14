pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "../../services/CobwebWeb.js" as Web

// Live preview of the cocoon (Settings → Windows → Cobwebs): a whole web — corners,
// drapes, cocoon — drawn the way the overlay draws it, in whichever look is picked.
// `live` holds uncommitted tuner values (part -> value, style included); empty once
// "Show me now" commits them, then the committed Config shows.
Column {
    id: root

    property var live: ({})
    property int seed: 7
    readonly property int aw: 200
    readonly property int ah: 124
    readonly property string effectiveStyle: live.style || Cobweb.cocoonStyle()

    function opts() {
        const o = Cobweb.cocoonOpts();
        for (const k in live)
            o[k] = live[k];
        o.style = root.effectiveStyle;
        return o;
    }
    function setLive(part, v) {
        const l = Object.assign({}, live);
        l[part] = v;
        live = l;
    }
    function clearLive() {
        live = ({});
    }
    // commit the staged tuner values into the real settings (Settings → "Show me
    // now" calls this first): unchanged values don't notify, so untouched parts
    // regenerate nothing
    function commitLive() {
        const o = opts();
        Config.windows.cobwebStyle = o.style;
        Config.windows.cobwebDensity = o.density;
        Config.windows.cobwebBundles = o.bundles;
        Config.windows.cobwebBridges = o.bridges;
        Config.windows.cobwebGravity = o.gravity;
        clearLive();
    }

    readonly property string _key: [opts().style, opts().density, opts().bundles, opts().bridges, opts().gravity, seed].join(",")
    // drags fire _key on every tick: wait until the hand stops, then generate once
    on_KeyChanged: refreshLater.restart()
    Timer {
        id: refreshLater
        interval: 120
        onTriggered: root.refresh()
    }

    property var shapes: []               // {kind, s, pts, dew}
    property int cocoonThreads: 0
    property int stepCount: 0
    function refresh() {
        const steps = Web.generate(seed, aw, ah, opts());
        let n = 0;
        const out = [];
        for (const st of steps) {
            if (st.phase === "cocoon")
                n += st.threads.length;
            for (const t of st.threads) {
                const sh = Web.restShape(t, aw, ah);
                out.push({
                    "kind": t.kind,
                    "s": sh,
                    "pts": Web.curvePoints(sh),
                    "dew": !!t.dew
                });
            }
        }
        shapes = out;
        cocoonThreads = n;
        stepCount = steps.length;
        canvas.requestPaint();
    }
    function fadeOf(kind) {
        if (kind === "strand")
            return 0.92;
        if (kind === "cross" || kind === "bridge" || kind === "wrap")
            return 0.6;
        return 1;
    }
    // the classic dotted haze (a 4×4 Bayer stand-in for Qt's Dense patterns)
    readonly property var bayer: [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    function haze(ctx, W, H) {
        const S = Math.min(W, H);
        ctx.fillStyle = "rgba(237,232,250,0.45)";
        const cell = (x, y, n) => {
            if (root.bayer[(y & 3) * 4 + (x & 3)] < n)
                ctx.fillRect(x, y, 1, 1);
        };
        const rim = (a, b, n) => {
            a = Math.round(a);
            b = Math.round(b);
            if (b <= a || 2 * b >= S)
                return;
            for (let y = a; y < H - a; y++)
                for (let x = a; x < W - a; x++) {
                    const inX = x >= b && x < W - b, inY = y >= b && y < H - b;
                    if (!(inX && inY))
                        cell(x, y, n);
                }
        };
        rim(S * 0.05, S * 0.16, 1);
        rim(S * 0.02, S * 0.05, 2);
        rim(0, S * 0.02, 4);
    }
    function stroke(ctx, polys, fade) {
        for (const pass of [0, 1]) {
            const d = pass ? 0.5 : 1.5;
            ctx.strokeStyle = pass ? Qt.rgba(236 / 255, 232 / 255, 250 / 255, 0.82 * fade) : Qt.rgba(12 / 255, 8 / 255, 24 / 255, 0.55 * fade);
            ctx.beginPath();
            for (const pts of polys) {
                if (pts.length < 2)
                    continue;
                ctx.moveTo(Math.round(pts[0].x) + d, Math.round(pts[0].y) + d);
                for (let k = 1; k < pts.length; k++)
                    ctx.lineTo(Math.round(pts[k].x) + d, Math.round(pts[k].y) + d);
            }
            ctx.stroke();
        }
    }

    spacing: Theme.u * 3

    PxBox {
        width: root.aw * 2 + Theme.u * 4
        height: root.ah * 2 + Theme.u * 4
        sunken: true
        Canvas {
            id: canvas
            x: Theme.u * 2
            y: Theme.u * 2
            width: root.aw
            height: root.ah
            transform: Scale {
                xScale: 2
                yScale: 2
            }
            smooth: false
            antialiasing: false
            renderTarget: Canvas.Image
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                // a dark window behind the silk, with a title strip
                ctx.fillStyle = "#171221";
                ctx.fillRect(0, 0, root.aw, root.ah);
                ctx.fillStyle = "#2b2038";
                ctx.fillRect(0, 0, root.aw, 10);
                ctx.fillStyle = Qt.rgba(240 / 255, 230 / 255, 250 / 255, 0.75);
                ctx.fillRect(5, 4, 34, 2);
                ctx.lineWidth = 1;
                // classic look: the dotted haze is drawn too (a full web is shown, so the
                // haze is fully closed). Qt's Dense7/6/5 ≈ 6% / 12% / 25% coverage here.
                if (root.effectiveStyle === "classic")
                    root.haze(ctx, root.aw, root.ah);
                const full = [], mid = [], soft = [];
                for (const t of root.shapes)
                    (root.fadeOf(t.kind) >= 1 ? full : root.fadeOf(t.kind) > 0.6 ? mid : soft).push(t.pts);
                if (root.effectiveStyle === "classic") {
                    root.stroke(ctx, full.concat(mid), 1);
                    root.stroke(ctx, soft, 0.5);
                } else {
                    root.stroke(ctx, full, 1);
                    root.stroke(ctx, mid, 0.92);
                    root.stroke(ctx, soft, 0.6);
                }
            }
        }
    }

    Row {
        spacing: Theme.u * 3
        PxButton {
            compact: true
            icon: "refresh"
            text: I18n.t("Другая", "Another")
            onClicked: {
                root.seed = Math.floor(Math.random() * 99999);
                refreshLater.stop();
                root.refresh();
            }
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            kind: "tiny"
            color: Theme.textDim
            text: I18n.t("кокон: ", "cocoon: ") + root.cocoonThreads + I18n.t(" нитей · шагов ", " threads · ") + root.stepCount + I18n.t(" · зерно ", " steps · seed ") + root.seed
        }
    }

    Component.onCompleted: refresh()
}
