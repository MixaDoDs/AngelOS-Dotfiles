pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "."

// The equalizer as a Golden Gate menu bar extra: three slider rails whose knobs follow the
// lows, the mids and the highs of EasyEffects' curve (services/Eq, the same bridge as the
// pixel bar's EQ face). The menu bar puts plugins left of the tray; this one moves itself
// right before the volume icon. In the pixel theme it is nothing: its bar cell hides itself.
Item {
    id: root

    property var plugin
    property string screenName
    property var barWindow
    readonly property bool mac: Skin.mac
    readonly property bool barOpen: pop.visible
    readonly property color ink: Skin.ink(screenName)

    implicitWidth: mac ? face.implicitWidth : 0
    implicitHeight: mac ? Skin.px(18) : 0
    visible: mac

    // ---- place: right before the volume (the status row runs right to left) ----
    readonly property Item extra: parent ? parent.parent : null
    readonly property bool inMenuBar: !!extra && extra.settingsSkin === "goldengate" && !!extra.parent
    // a Repeater takes no room in the row, and moving one makes it build its items again
    function isRepeater(c) {
        return String(c).startsWith("QQuickRepeater");
    }
    property int moves: 0
    function place() {
        if (!inMenuBar || moves >= 8)
            return;
        const row = extra.parent;
        const kids = Array.prototype.slice.call(row.children);
        const at = kids.findIndex(c => c.kind === "sound");
        if (at < 0)
            return;
        const after = kids.slice(at + 1).filter(c => !isRepeater(c));
        if (after[0] === extra)
            return;
        // stackAfter() isn't open to QML: the row's items after the volume (Bluetooth, Wi-Fi, the
        // tray's and the other plugins' items) go to its end in their order, after this one
        moves++;
        if (kids.indexOf(extra) < at) {
            extra.parent = null;
            extra.parent = row;
        }
        for (const c of after)
            if (c !== extra) {
                c.parent = null;
                c.parent = row;
            }
    }
    Connections {
        target: root.inMenuBar ? root.extra.parent : null
        function onChildrenChanged() {
            Qt.callLater(root.place);
        }
    }
    // the pixel bar: no cell at all (it has its own EQ face)
    function hidePixelCell() {
        if (mac)
            return;
        for (let p = parent; p; p = p.parent)
            if (p.wid !== undefined && p.bar !== undefined) {
                p.visible = false;
                return;
            }
    }

    // ---- the shared bridge: counted in while shown, as the pixel face does ----
    property bool watching: false
    property bool viewing: false
    property bool gone: false
    function count() {
        if (gone)
            return;
        const want = mac && inMenuBar;
        if (watching !== want) {
            watching = want;
            Eq.watchers += watching ? 1 : -1;
        }
        const open = !!pop.item && pop.item.visible;
        if (viewing !== open) {
            viewing = open;
            Eq.viewers += viewing ? 1 : -1;
        }
    }
    onMacChanged: count()
    onInMenuBarChanged: count()
    Component.onCompleted: {
        hidePixelCell();
        count();
        Qt.callLater(place);
    }
    Component.onDestruction: {
        gone = true;
        if (watching)
            Eq.watchers--;
        if (viewing)
            Eq.viewers--;
    }

    // ---- the face: the pixel bar's "EQ" + spectrum + curve, as a monochrome menu bar extra ----
    readonly property bool on: Eq.ready && Eq.active
    readonly property var spectrum: Eq.spectrumLevels
    readonly property var levels: Eq.levels
    Row {
        id: face
        anchors.centerIn: parent
        spacing: Skin.px(4)
        MacText {
            anchors.verticalCenter: parent.verticalCenter
            text: "EQ"
            size: Skin.px(11)
            semibold: true
            color: root.ink
            opacity: root.on ? 1 : 0.5
        }
        Canvas {
            id: thumb
            anchors.verticalCenter: parent.verticalCenter
            width: Skin.px(38)
            height: Skin.px(15)
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height, col = w / 10, pad = Skin.px(1.5);
                // the spectrum (cava): soft rounded bars from the bottom
                ctx.fillStyle = root.ink;
                ctx.globalAlpha = root.on ? 0.5 : 0.18;
                const bw = Math.max(1.5, col * 0.56);
                for (let i = 0; i < 10; i++) {
                    const a = Math.min(1, 1.15 * Math.sqrt(Math.max(0, Math.min(1, root.spectrum[i] || 0))));
                    if (a <= 0)
                        continue;
                    const bh = Math.max(bw, a * h);
                    ctx.beginPath();
                    ctx.roundedRect(col * (i + 0.5) - bw / 2, h - bh, bw, bh, bw / 2, bw / 2);
                    ctx.fill();
                }
                // 0 dB
                ctx.globalAlpha = root.on ? 0.3 : 0.18;
                ctx.fillRect(0, Math.round(h / 2), w, Math.max(1, Skin.px(0.6)));
                // the curve: smooth through the ten bands
                // scaled to the curve's own reach (at least ±6 dB), so a gentle curve still shows its shape
                let reach = 6;
                for (let i = 0; i < 10; i++)
                    reach = Math.max(reach, Math.abs(root.levels[i] || 0));
                const yOf = g => pad + (h - pad * 2) * (0.5 - Math.max(-reach, Math.min(reach, g)) / (reach * 2));
                const pts = [];
                for (let i = 0; i < 10; i++)
                    pts.push([col * (i + 0.5), yOf(root.levels[i] || 0)]);
                const p = i => pts[Math.max(0, Math.min(9, i))];
                ctx.beginPath();
                ctx.moveTo(pad, pts[0][1]);
                ctx.lineTo(pts[0][0], pts[0][1]);
                for (let i = 0; i < 9; i++) {
                    const p0 = p(i - 1), p1 = p(i), p2 = p(i + 1), p3 = p(i + 2);
                    ctx.bezierCurveTo(p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6, p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6, p2[0], p2[1]);
                }
                ctx.lineTo(w - pad, pts[9][1]);
                ctx.globalAlpha = root.on ? 1 : 0.5;
                ctx.strokeStyle = root.ink;
                ctx.lineWidth = Math.max(1.2, Skin.px(1.7));
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.stroke();
            }
            Connections {
                target: root
                function onSpectrumChanged() { thumb.requestPaint(); }
                function onLevelsChanged() { thumb.requestPaint(); }
                function onOnChanged() { thumb.requestPaint(); }
                function onInkChanged() { thumb.requestPaint(); }
            }
        }
    }

    MouseArea {
        id: hot
        anchors.fill: parent
        anchors.margins: -Skin.px(5)
        enabled: root.mac
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton) {
                if (Eq.ready)
                    Eq.send("toggle");
            } else {
                pop.toggle();
            }
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.t("Эквалайзер EasyEffects", "EasyEffects equalizer")
    Accessible.description: Eq.ready ? (Eq.active ? I18n.t("включён", "enabled") : I18n.t("выключен", "bypassed")) : Eq.error
    Accessible.onPressAction: pop.toggle()

    // built when the pointer comes to it, gone a while after it closed
    LazyPopup {
        id: pop
        panelId: "mac-eq"
        anchorItem: root
        warm: hot.containsMouse
        BarPopup {
            id: popup
            panelId: "mac-eq"
            anchorItem: root
            above: false
            title: I18n.t("Эквалайзер", "Equalizer")
            icon: "music"
            contentWidth: Skin.px(340)
            contentHeight: body.implicitHeight
            onVisibleChanged: {
                root.count();
                if (visible) {
                    Eq.send("status");
                    Eq.send("sources");
                }
            }
            MacEqPanel {
                id: body
                width: parent.width
                shown: popup.visible
            }
        }
    }
}
