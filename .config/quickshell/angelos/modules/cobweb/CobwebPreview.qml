pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "../../services/CobwebWeb.js" as Web

// Live preview of the cocoon (Settings → Windows → Cobwebs): a whole web — corners,
// drapes, cocoon — drawn the way the overlay draws it (CobwebView), in the picked look.
// `live` holds a slider's value while it is dragged (part -> value); on release it is
// saved (commit) and the saved Config shows again.
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
            o[k] = k === "style" ? live[k] : Cobweb.tuned(k, live[k]);
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
    // a slider let go: the value is saved. Real windows don't follow it live — a web is
    // built once; the new values reach a window with "Show me now", the next start or a
    // new web (services/Cobweb)
    function commit(part, v) {
        const key = {
            "style": "cobwebStyle",
            "density": "cobwebDensity",
            "bundles": "cobwebBundles",
            "bridges": "cobwebBridges",
            "gravity": "cobwebGravity"
        }[part];
        if (!key)
            return;
        Config.windows[key] = part === "style" ? (v === "silk" ? "silk" : "classic") : Cobweb.tuned(part, v);
        const l = Object.assign({}, live);
        delete l[part];
        live = l;
    }
    // whatever is still held (a drag the pointer let go of outside) is saved too
    function commitLive() {
        for (const k in live)
            commit(k, live[k]);
    }

    readonly property string _key: {
        const o = opts();
        return [o.style, o.density, o.bundles, o.bridges, o.gravity, seed].join(",");
    }
    // drags fire _key on every tick: wait until the hand stops, then generate once
    on_KeyChanged: refreshLater.restart()
    Timer {
        id: refreshLater
        interval: 120
        onTriggered: root.refresh()
    }

    property var shapes: []               // {kind, wrap, s, pts, dew}
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
                    "wrap": t.kind === "wrap",
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
    // the same fades as CobwebView.fadeOf
    function fadeOf(t) {
        if (root.effectiveStyle !== "silk")
            return t.wrap ? 0.5 : 1;
        if (t.kind === "strand")
            return 0.92;
        if (t.kind === "cross" || t.kind === "bridge" || t.wrap)
            return 0.6;
        return 1;
    }
    // the classic dotted haze of a closed cocoon, with Qt's own dither patterns as the
    // overlay paints it (CobwebView: the haze at cocooned() = 1)
    function haze(ctx, W, H) {
        const S = Math.min(W, H);
        const silk = Qt.rgba(0.93, 0.91, 0.98, 0.45);
        const rim = (a, b, pattern) => {
            a = Math.round(a);
            b = Math.round(b);
            if (b <= a || 2 * b >= S)
                return;
            ctx.fillStyle = ctx.createPattern(silk, pattern);
            ctx.fillRect(a, a, W - 2 * a, b - a);
            ctx.fillRect(a, H - b, W - 2 * a, b - a);
            ctx.fillRect(a, b, b - a, H - 2 * b);
            ctx.fillRect(W - b, b, b - a, H - 2 * b);
        };
        rim(S * 0.05, S * 0.16, Qt.Dense7Pattern);
        rim(S * 0.02, S * 0.05, Qt.Dense6Pattern);
        rim(0, S * 0.02, Qt.Dense5Pattern);
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
                // classic look: the dotted haze too (a full web is shown, so it is closed)
                if (root.effectiveStyle !== "silk")
                    root.haze(ctx, root.aw, root.ah);
                const by = {};
                for (const t of root.shapes)
                    (by[root.fadeOf(t)] = by[root.fadeOf(t)] || []).push(t.pts);
                for (const f of Object.keys(by).map(Number).sort((a, b) => b - a))
                    root.stroke(ctx, by[f], f);
                for (const t of root.shapes)
                    if (t.dew) {
                        const m = Web.bezier(t.s, 0.5);
                        ctx.fillStyle = Qt.rgba(12 / 255, 8 / 255, 24 / 255, 0.6);
                        ctx.fillRect(Math.round(m.x) + 1, Math.round(m.y) + 1, 1, 1);
                        ctx.fillStyle = "#ffffff";
                        ctx.fillRect(Math.round(m.x), Math.round(m.y), 1, 1);
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
