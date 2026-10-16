pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.background.circles

// Heaven's look of RadialMenu: a harp standing on a cloud, around the pointer. Every entry is
// a string — the first by the pillar, the longest — with its icon on a pearl where the string
// meets the soundboard and its name hanging under the board, so the names climb with it like
// steps. The whole string listens: hover plucks it (it trembles and rings out), so a sweep of
// the pointer across the harp is a glissando; it opens string by string the same way, and as
// it opens a glissando runs up the strings. They sound (Sounds "harp", System sounds): C Lydian
// up from middle C, the first the lowest (scripts/y2k-sounds.py → harp1…16). Flyouts
// open beside the harp. The crown on the pillar (the logo) closes. ←/→ walk the strings.
// The frame is painted once in pixels of the shell's size, in the palette's accent; the
// pearls are pale in any palette, with dark ink.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property int n: Math.max(1, menu.slots.length)
    readonly property int px: Math.max(1, Math.round(Theme.u * k))          // the frame's pixel
    readonly property real hubS: Math.round(Theme.u * 18 * k)
    readonly property real pillarW: px * 9
    readonly property real neckH: px * 8
    readonly property real amp: px * 16                                     // the neck's S
    readonly property real knee: px * 7                                     // the post past the last string
    readonly property real minString: bead + px * 10
    readonly property real labelH: menu.labels ? Theme.sizeTiny + Theme.u * 3 : 0
    readonly property real labelW: menu.labels ? Math.ceil(metrics.width) + Theme.u * 2 : 0
    readonly property real cloudH: px * 17
    // between two strings: closer on a narrow screen, and the pearls (the icon on it) smaller
    readonly property real sp: Math.max(Theme.u * 9, Math.min(Math.round(Theme.u * 20 * k), Math.floor((width - Theme.u * 16 - pillarW - knee - labelW) / (n + 0.5))))
    readonly property real bead: Math.min(Math.round(Theme.u * 16 * k), sp - Theme.u * 2)      // the pearl holding an icon
    readonly property int iconPixel: Math.max(1, Math.min(Math.round(Theme.u * k * 0.85), Math.floor((bead - px * 2) / 12)))
    readonly property real frameW: pillarW + sp * (n + 0.5) + knee
    // the board climbs at least one name's height per string, so the names never overlap
    readonly property real fixedH: hubS / 2 + amp + neckH + minString + px * 14 + Math.max(labelH + px * 2, px * 4 + cloudH) + Theme.u * 8
    readonly property real dy: Math.max(menu.labels ? labelH : px * 2, Math.min(Math.round(sp * 0.55), (height - Theme.u * 16 - fixedH) / ((frameW - pillarW) / sp)))
    readonly property real slope: dy / sp
    readonly property real kneeY: neckTop(frameW) + neckH + minString
    readonly property real footY: kneeY + slope * (frameW - pillarW)
    readonly property real baseY: footY + boardThick(pillarW)
    // the last name may hang past the harp's end
    readonly property real overhang: Math.max(0, strX(n - 1) - sp * 0.3 + labelW - frameW)
    readonly property real upTo: -hubS / 2
    readonly property real downTo: Math.max(labelTop(0) + labelH, baseY + px * 4 + cloudH)
    readonly property real fx: Math.round(menu.cx - (frameW + overhang) / 2)
    readonly property real fy: Math.round(menu.cy - (upTo + downTo) / 2)
    readonly property real reachX: (frameW + overhang) / 2 + Theme.u * 4
    readonly property real reachY: (downTo - upTo) / 2 + Theme.u * 4
    readonly property real reach: Math.max(reachX, reachY)
    readonly property Item blurItem: null

    // the palette: the frame in the accent with a rim of its darker self; pale pearls in any
    // palette (the light surface, or the text's pale on dark ones) with dark ink on them; the
    // sounding string in the accent
    readonly property color wood: Theme.accent
    // the pale plate, its ink, the plate you're on (as much of the accent as still leaves the
    // ink at 4.5:1) and the names' ink, for a palette {dark, face, text, accent, surface} —
    // the self-test reads every heaven palette through it
    function coloursFor(t) {
        const plate = t.dark ? Theme.mix(t.text, t.surface, 0.12) : t.surface;
        const ink = readable(t.dark ? t.face : t.text, plate);
        let hot = Theme.mix(plate, t.accent, 0.05);
        for (const k of [0.42, 0.34, 0.26, 0.18, 0.1]) {
            const c = Theme.mix(plate, t.accent, k);
            if (HellLook.contrast(ink, c) >= 4.5) {
                hot = c;
                break;
            }
        }
        const label = readable(t.text, t.surface);
        return {
            "plate": plate,
            "ink": ink,
            "hot": hot,
            "label": label,
            "pairs": [[ink, plate], [ink, hot], [label, t.surface]]
        };
    }
    readonly property var tone: coloursFor({
        "dark": Theme.dark,
        "face": Theme.face,
        "text": Theme.text,
        "accent": Theme.accent,
        "surface": Theme.menuSurface
    })
    readonly property color pearl: tone.plate
    readonly property color ink: tone.ink
    readonly property color pearlHot: tone.hot
    readonly property color labelInk: tone.label
    readonly property color rim: Theme.mix(Theme.accent, ink, 0.55)
    readonly property color stringInk: Theme.mix(Theme.text, Theme.menuSurface, 0.45)
    // text on what it stands on, for the self-test (tests/ui): icons on the pearls, the names
    // on their outline
    readonly property var pairs: tone.pairs

    // a colour of the palette nudged away from `bg` (darker on a lighter one, lighter on a
    // darker one) until it reads at 4.5:1 — a few palettes (Solarized light) sit just under it
    function readable(fg, bg) {
        const lum = c => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        let c = Qt.color(fg);
        const down = lum(c) < lum(Qt.color(bg));
        for (let i = 0; i < 10 && HellLook.contrast(c, bg) < 4.5; i++)
            c = down ? Qt.darker(c, 1.12) : Qt.lighter(c, 1.12);
        return c;
    }
    // the frame, from its top left corner (the pillar's top): x of string i; the neck's top
    // edge, an S (down from the crown, up into a shoulder, down to the scroll); the
    // soundboard's top edge, climbing from the foot to the knee, thick at the foot
    function strX(i) {
        return pillarW + sp * (i + 0.75);
    }
    function neckTop(x) {
        const p = Math.max(0, Math.min(1, x / frameW));
        return amp * (0.15 + 0.6 * Math.pow(Math.sin(Math.PI * p), 2) + 0.4 * Math.sin(2 * Math.PI * p));
    }
    function boardTop(x) {
        return footY - slope * (x - pillarW);
    }
    function boardThick(x) {
        return px * (8 + 6 * Math.max(0, Math.min(1, 1 - (x - pillarW) / (frameW - pillarW))));
    }
    // where string i's name starts, under the board
    function labelTop(i) {
        const x = strX(i) - sp * 0.3;
        return boardTop(x) + boardThick(x) + px * 2;
    }
    function outOf(i) {
        return Math.max(0, Math.min(1, menu.reveal * 1.5 - i * 0.035));
    }
    function nav(e) {
        return menu.walk(e);
    }
    anchors.fill: parent

    // the strings' voices: loaded while the sounds are on (quiet in stream mode)
    readonly property bool voiced: Sounds.enabled("harp") && !StreamMode.quiet && Sounds.ready
    readonly property real voiceVolume: Sounds.volumeOf("harp")
    // opening: a glissando up the strings, one every 34 ms, each plucked as it sounds
    Connections {
        // (the self-test's menu is a plain object, without the signal)
        target: typeof look.menu.opened === "function" ? look.menu : null
        function onOpened() {
            if (!look.voiced || Sounds.quietNow())
                return;
            gliss.step = 0;
            gliss.restart();
        }
    }
    Timer {
        id: gliss
        property int step: 0
        interval: 34
        repeat: true
        onTriggered: {
            const s = strings.itemAt(step);
            if (s)
                s.ring();
            step++;
            if (step >= look.n || !look.menu.visible)
                stop();
        }
    }

    TextMetrics {
        id: metrics
        font.family: Theme.fontTitle
        font.pixelSize: Theme.sizeTiny
        font.bold: true
        text: {
            let best = "";
            for (const id of look.menu.slots) {
                const e = DeskMenu.entry(id);
                const s = e ? (e.short || e.label) : "";
                if (s.length > best.length)
                    best = s;
            }
            return best;
        }
    }

    // the frame — pillar, neck, scroll, soundboard — the light behind the strings and the cloud
    Canvas {
        id: frame
        // pixels side by side, no seams between them at a fractional scale
        antialiasing: false
        readonly property real spill: look.px * 42                         // the cloud drifts past the pillar
        readonly property var colours: [Qt.alpha(Theme.menuSurface, 0.86), look.wood, Qt.lighter(look.wood, 1.25), Qt.darker(look.wood, 1.3), look.rim, look.pearl, Theme.mix(look.pearl, Theme.accent, 0.16), Theme.mix(look.pearl, look.ink, 0.35)]
        readonly property string shape: [look.frameW, look.footY, look.sp, look.px, look.n].join(" ") + colours.join(" ")
        x: look.fx - spill
        y: look.fy
        width: look.frameW + spill + look.px * 4
        height: look.baseY + look.px * 6 + look.cloudH
        opacity: look.menu.reveal
        scale: 0.94 + 0.06 * look.menu.reveal
        onShapeChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const L = look, p = L.px, cols = Math.floor(width / p), rws = Math.floor(height / p);
            const W = L.frameW, pw = L.pillarW, base = L.baseY;
            const knob = [W - L.knee * 0.5, L.kneeY + p * 2, p * 5];
            // in the frame's own coordinates (x from the pillar's left edge)
            const wood = (x, y) => {
                if (x < -p * 3 || x > W + p * 3 || y < 0)
                    return false;
                if (x >= -p * 2 && x <= pw + p * 2 && (y <= p * 5 || (y >= base - p * 4 && y <= base)))
                    return true;                                                   // capital, base
                if (x >= 0 && x <= pw && y <= base)
                    return true;                                                   // pillar
                if (x >= 0 && x <= W && y >= L.neckTop(x) && y <= L.neckTop(x) + L.neckH)
                    return true;                                                   // neck
                if (x >= W - L.knee && x <= W && y >= L.neckTop(x) && y <= L.kneeY + L.boardThick(x))
                    return true;                                                   // the knee
                const kx = x - knob[0], ky = y - knob[1];
                if (kx * kx + ky * ky <= knob[2] * knob[2])
                    return true;                                                   // the scroll
                return x >= pw - p * 2 && x <= W && y >= L.boardTop(x) && y <= L.boardTop(x) + L.boardThick(x);   // soundboard
            };
            const air = (x, y) => x > pw && x < W - L.knee && y > L.neckTop(x) + L.neckH && y < L.boardTop(x);
            const cloud = (x, y) => {
                const cx = pw * 0.5 - p * 9, cy = base + p * 7;
                if ((y - cy) / p > 8)
                    return false;
                for (const c of [[-20, 3, 8], [-11, -1, 11], [0, 0, 11], [9, 3, 8], [-30, 5, 5]]) {
                    const dx = (x - cx) / p - c[0], dyy = (y - cy) / p - c[1];
                    if (dx * dx + dyy * dyy * 1.6 <= c[2] * c[2])
                        return true;
                }
                return false;
            };
            const at = (i, j) => [(i + 0.5) * p - spill, (j + 0.5) * p];
            const isWood = (i, j) => {
                const q = at(i, j);
                return wood(q[0], q[1]);
            };
            const isCloud = (i, j) => {
                const q = at(i, j);
                return cloud(q[0], q[1]) && !wood(q[0], q[1]);
            };
            const cells = [[], [], [], [], [], [], [], []];
            for (let j = 0; j < rws; j++) {
                for (let i = 0; i < cols; i++) {
                    const q = at(i, j);
                    let kind = -1;
                    if (wood(q[0], q[1])) {
                        if (!isWood(i - 1, j) || !isWood(i + 1, j) || !isWood(i, j - 1) || !isWood(i, j + 1))
                            kind = 4;
                        else if (!isWood(i, j - 2) || !isWood(i - 2, j))
                            kind = 2;
                        else if (!isWood(i, j + 2) || !isWood(i + 2, j))
                            kind = 3;
                        // the pillar's fluting
                        else if (q[0] < pw && q[1] > p * 6 && q[1] < base - p * 5 && i % 3 === 1)
                            kind = 3;
                        else
                            kind = 1;
                    } else if (air(q[0], q[1])) {
                        kind = 0;
                    } else if (cloud(q[0], q[1])) {
                        kind = !isCloud(i - 1, j) || !isCloud(i + 1, j) || !isCloud(i, j - 1) || !isCloud(i, j + 1) ? 7 : q[1] > base + p * 10 ? 6 : 5;
                    }
                    if (kind >= 0)
                        cells[kind].push(i, j);
                }
            }
            for (let kind = 0; kind < cells.length; kind++) {
                ctx.fillStyle = colours[kind];
                const l = cells[kind];
                for (let m = 0; m < l.length; m += 2)
                    ctx.fillRect(l[m] * p, l[m + 1] * p, p, p);
            }
        }
    }

    // the strings: each the whole strip from the neck to the board, its pearl and its name
    Repeater {
        id: strings
        model: look.menu.slots
        CircleEntry {
            id: entry
            menu: look.menu
            readonly property real sx: look.strX(index)
            readonly property real topY: look.neckTop(sx) + look.neckH
            readonly property real len: look.boardTop(sx) - topY
            readonly property real o: look.outOf(index)
            readonly property bool leftSide: look.fx + sx < look.menu.cx
            // plucked: it trembles and rings out (still while motion is off)
            property real pluck: 1
            readonly property real wobble: Math.round(Math.sin(pluck * Math.PI * 9) * (1 - pluck) * look.px * 2)
            onHotChanged: if (hot)
                ring()
            // plucked: it trembles and sounds its note; sfx-player mixes, so a string
            // plucked again rings over its own tail
            function ring() {
                pluckAnim.restart();
                if (!look.voiced || Sounds.quietNow())
                    return;
                Sounds.playFile(clip, look.voiceVolume);
            }
            readonly property string clip: look.voiced ? Sounds.dir + "/" + Sounds.harpStrings[index % Sounds.harpStrings.length] + ".wav" : ""
            // decoded ahead in sfx-player, so the first pluck isn't late
            onClipChanged: Sounds.playFile(clip, 0)
            NumberAnimation {
                id: pluckAnim
                target: entry
                property: "pluck"
                from: 0
                to: 1
                duration: Config.desktop.menuAnim !== false ? Motion.ms(620) : 0
            }
            x: look.fx + sx - look.sp / 2
            y: look.fy + topY
            width: look.sp
            height: len
            // a string in six pieces, the middle ones swing furthest
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    readonly property real seg: entry.len / 6
                    x: entry.width / 2 - width / 2 + Math.round(entry.wobble * Math.sin(Math.PI * (index + 0.5) / 6))
                    y: index * seg
                    width: entry.hot ? look.px : Math.max(1, Math.round(look.px / 2))
                    height: Math.max(0, Math.min(seg, entry.len * entry.o - index * seg))
                    color: entry.hot ? Theme.accent : look.stringInk
                }
            }
            Rectangle {
                id: pearlBox
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height - look.px * 2
                width: look.bead
                height: width
                radius: width / 2
                scale: (entry.hot ? 1.12 : 1) * (0.6 + 0.4 * entry.o)
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.ms(90)
                    }
                }
                opacity: entry.o
                color: entry.hot ? look.pearlHot : look.pearl
                border.width: look.px
                border.color: look.rim
                PxIcon {
                    anchors.centerIn: parent
                    name: entry.icon
                    pixel: look.iconPixel
                    ink: look.ink
                }
                // a flyout: a notch towards where it opens
                PxText {
                    visible: !!(entry.e && entry.e.flyout)
                    x: entry.leftSide ? -width + look.px : parent.width - look.px
                    y: -look.px * 2
                    kind: "tiny"
                    color: look.rim
                    text: entry.leftSide ? "◂" : "▸"
                }
            }
            PxText {
                visible: look.menu.labels
                x: look.sp / 2 - look.sp * 0.3
                y: look.labelTop(entry.index) - entry.topY
                opacity: entry.o
                kind: "tiny"
                font.bold: entry.hot
                color: look.labelInk
                style: Text.Outline
                styleColor: Qt.alpha(Theme.menuSurface, 0.9)
                text: entry.label
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: look.menu.hoverEntry(entry.index)
                    onClicked: look.menu.activate(entry.index)
                }
            }
        }
    }

    // the crown on the pillar: the logo on a pale pearl; closes
    Rectangle {
        x: look.fx + look.pillarW / 2 - width / 2
        y: look.fy - height / 2
        width: look.hubS
        height: width
        radius: width / 2
        scale: look.menu.reveal
        color: crownMouse.containsMouse ? look.pearlHot : look.pearl
        border.width: look.px
        border.color: look.rim
        AngelLogo {
            anchors.centerIn: parent
            emblemOnly: true
            pixel: Math.max(1, Math.round(Theme.u * look.k * 0.6))
        }
        MouseArea {
            id: crownMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                look.menu.current = -1;
                look.menu.fly = "";
            }
            onClicked: look.menu.close()
        }
    }
    // the hovered entry's full name, over the neck
    PxBox {
        visible: !!look.menu.hoveredEntry && look.menu.reveal > 0.6
        x: look.menu.clamp(look.fx + look.frameW / 2 - width / 2, look.fx + look.hubS, look.width - width - Theme.u * 2)
        y: look.fy - height - Theme.u * 2
        width: hoverName.implicitWidth + Theme.u * 8
        height: hoverName.implicitHeight + Theme.u * 4
        color: Qt.alpha(Theme.menuSurface, 0.92)
        PxText {
            id: hoverName
            anchors.centerIn: parent
            kind: "tiny"
            font.bold: true
            color: look.labelInk
            text: look.menu.hoveredEntry ? look.menu.hoveredEntry.label : ""
        }
    }

    // the column bends round a circle, the harp is a box: a little further out, past its corners
    CircleFly {
        hell: false
        menu: look.menu
        reach: look.reachX + Theme.u * 12
        at: look.menu.flyIndex >= 0 ? Qt.point(look.fx + look.strX(look.menu.flyIndex), look.fy + look.boardTop(look.strX(look.menu.flyIndex)) - look.bead / 2) : Qt.point(look.menu.cx, look.menu.cy)
    }
}
