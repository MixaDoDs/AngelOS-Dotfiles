pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.kit

// One line of the P5 window's card: a group's caption, or a setting from the catalog (an
// entry) as a game's option line — the name on the left, the value on the right (◀ value ▶,
// ВКЛ/ВЫКЛ, a bar), the selected line inverted. The window moves the selection; step(±1) is ←/→,
// activate() is Enter or a click. A value just set shows until the owner's binding answers
// (as the pixel controls do: the binding is never cut).
Item {
    id: root

    required property var line          // {t: "group"|"entry"|"more", g, e, title, count}
    property bool selected: false
    property var pal: ({})
    property int order: 0               // its place for the rows' entrance
    property real enter: 1              // 0 → 1: the rows slide in one after another
    signal pick
    // asked with the pointer's place on screen: did it really move (P5View.pointerMoved)
    property var gate: null
    signal moved(int dir)
    signal follow(var link)

    readonly property var e: line.e || null
    readonly property string kind: line.t === "entry" && e ? e.kind : line.t
    // what can take the selection
    readonly property bool selectable: shown && kind !== "group" && kind !== "note" && kind !== "embed" && !(kind === "custom" && !e.label && !e.keys)
    // (a custom part with nothing in it right now takes no line)
    // (an entry of a group that isn't there now isn't either)
    readonly property bool inPlace: line.t !== "entry" || !!e && e.present && (!line.g || line.g.present)
    readonly property bool shown: line.t === "group" ? !!line.g && line.g.present && line.g.entries.some(x => x.present) : line.t === "entry" ? inPlace && (kind !== "custom" || !!e.label || host.height > 0) : true
    readonly property bool live: !e || e.enabled
    // an empty custom part stays visible, unseen and without height: hidden, its items would
    // never lay out again and it would stay empty (a gamepad plugged in after the page opened)
    readonly property bool waiting: !shown && line.t === "entry" && inPlace && kind === "custom"
    visible: shown || waiting
    opacity: shown ? 1 : 0
    width: parent ? parent.width : 0
    height: shown ? body.height : 0

    // ---- a value just set, shown until the binding answers ----
    property var held: undefined
    Timer {
        id: letGo
        interval: 2000
        onTriggered: root.held = undefined
    }
    function hold(v) {
        held = v;
        letGo.restart();
    }
    Connections {
        target: root.e
        ignoreUnknownSignals: true
        function onCheckedChanged() {
            root.held = undefined;
        }
        function onCurrentValueChanged() {
            root.held = undefined;
        }
        function onValueChanged() {
            root.held = undefined;
        }
    }
    readonly property bool checkedNow: held !== undefined && kind === "toggle" ? held : !!e && e.checked === true
    readonly property var valueNow: held !== undefined ? held : e ? (kind === "choice" ? e.currentValue : e.value) : undefined
    readonly property int choiceIndex: kind === "choice" ? e.items.findIndex(i => i.value === valueNow) : -1
    readonly property string choiceLabel: kind !== "choice" ? "" : choiceIndex >= 0 ? String(e.items[choiceIndex].label) : e.placeholder
    function numberText(v) {
        return (v * (e.valueScale || 1)).toFixed(e.decimals || 0) + (e.suffix || "");
    }

    // ←/→ on it
    function step(dir) {
        if (!e || !live)
            return false;
        if (kind === "custom" && e.keys) {
            e.keys.step(dir);
            moved(dir);
            return true;
        }
        if (kind === "toggle") {
            const next = !checkedNow;
            hold(next);
            e.toggled(next);
        } else if (kind === "choice") {
            const n = e.items.length;
            if (!n)
                return false;
            const i = choiceIndex < 0 ? (dir > 0 ? 0 : n - 1) : (choiceIndex + dir + n) % n;
            const v = e.items[i].value;
            hold(v);
            e.activated(v);
        } else if (kind === "slider" || kind === "spin") {
            const stepSize = e.stepSize > 0 ? e.stepSize : (e.to - e.from) / 50;
            const cur = valueNow;
            const v = Number(Math.max(Math.min(e.from, e.to), Math.min(Math.max(e.from, e.to), cur + dir * stepSize)).toFixed(Math.max(e.decimals || 0, 3)));
            if (v === cur)
                return true;
            hold(v);
            e.moved(v);
            if (kind === "slider")
                e.released(v);
        } else {
            return false;
        }
        pop.restart();
        Sounds.playSoft("toggle", 0.5);
        moved(dir);
        return true;
    }
    // Enter or a click
    function activate() {
        if (kind === "result") {
            follow({
                "result": line.r
            });
            Sounds.playSoft("click", 0.6);
            return true;
        }
        if (kind === "more") {
            line.open();
            Sounds.playSoft("click", 0.6);
            return true;
        }
        if (!e || !live)
            return false;
        if (kind === "custom" && e.keys) {
            e.keys.ok();
            Sounds.playSoft("click", 0.6);
        } else if (kind === "toggle") {
            hold(!checkedNow);
            e.toggled(held);
            pop.restart();
            moved(checkedNow ? 1 : -1);
            Sounds.playSoft("toggle", 0.6);
        } else if (kind === "choice" || kind === "spin" || kind === "slider") {
            return step(1);
        } else if (kind === "button") {
            e.clicked();
            pop.restart();
            Sounds.playSoft("click", 0.6);
        } else if (kind === "link") {
            follow({
                "page": e.page,
                "group": e.group
            });
            Sounds.playSoft("click", 0.6);
        } else if (kind === "field") {
            input.forceActiveFocus();
        } else {
            return false;
        }
        return true;
    }
    readonly property bool editing: input.activeFocus
    onSelectedChanged: {
        if (kind === "custom" && e && e.keys && e.keys.focus)
            e.keys.focus(selected);
        previewShut = false;
    }

    // ---- under the selected line: its hint, then its preview (decisions №30, 32: 25.10) ----
    readonly property string hintText: kind === "more" ? I18n.t("Редкие настройки этой страницы", "This page's rarer settings") : kind === "custom" && e && e.keys ? e.keys.hint || "" : kind !== "result" && e ? e.hint : ""
    readonly property string previewScene: e && e.preview ? e.preview : ""
    property string previewVariant: ""
    property string previewCaption: ""
    property bool previewShut: false
    readonly property bool opened: selected && (hintText !== "" || previewScene !== "" && !previewShut)
    Connections {
        target: root.e
        ignoreUnknownSignals: true
        function onShowPreview(value, caption) {
            root.previewVariant = String(value);
            root.previewCaption = caption;
            root.previewShut = false;
            if (preview.item)
                preview.item.restart();
        }
    }

    // the value's little jump when it changes
    property real popT: 1
    NumberAnimation {
        id: pop
        target: root
        property: "popT"
        from: 0
        to: 1
        duration: Motion.ms(180)
    }
    readonly property real popScale: popT >= 1 ? 1 : popT < 0.34 ? 1.25 : popT < 0.67 ? 1.1 : 1

    // the entrance: in from the left, leaning, one after another
    // (the first fourteen one after another, the rest with the fourteenth: all of them land)
    readonly property real inT: Math.max(0, Math.min(1, enter * 8 - Math.min(order, 14) * 0.45))
    readonly property real inQ: Math.floor(inT * 4) / 4

    // a custom part keeps its paper when picked (its own controls are ink on paper): an
    // accent edge and rim say it is picked
    readonly property bool inverted: selected && kind !== "custom"
    readonly property color ink: inverted ? pal.paper : pal.black
    readonly property real px: Theme.u

    Item {
        id: body
        width: root.width
        readonly property real lineH: root.kind === "group" ? groupText.height + px * 6 : root.kind === "note" ? noteText.height + px * 3 : root.kind === "custom" ? customCol.y + customCol.height + px * 3 : root.kind === "embed" ? embedBox.height + px * 6 : Math.max(label.height, valueBox.height) + px * 6
        height: lineH + (root.opened ? under.height + px * 3 : 0)
        x: (1 - root.inQ) * -px * 18
        opacity: root.inQ
        transform: Shear {
            xFactor: (1 - root.inQ) * -0.35
        }

        // ---- a group's caption ----
        PxText {
            id: groupText
            font.bold: true
            visible: root.kind === "group"
            y: px * 4
            x: px * 2
            text: root.line.title ? "▸ " + root.line.title : ""
            // (not the accent: that is only for what is picked, decision №15)
            color: Theme.mix(root.pal.black, root.pal.paper, 0.3)
            kind: "title"
            font.capitalization: Font.AllUppercase
            font.letterSpacing: px / 2
        }
        // ---- a note between the settings ----
        PxText {
            id: noteText
            visible: root.kind === "note"
            x: px * 4
            y: px
            width: root.width - px * 8
            text: root.e && root.kind === "note" ? root.e.text : ""
            // an explanation (dim) reads smaller and paler than the settings around it (decision №22, 25.10); a status stays as loud as a line
            readonly property bool quiet: root.kind === "note" && !!root.e && root.e.dim
            color: quiet ? Theme.mix(root.pal.dim, root.pal.paper, 0.2) : root.pal.dim
            kind: "title"
            font.family: Theme.fontP5Body
            font.pixelSize: quiet ? Math.round(Theme.p5LabelPx * 0.7) : Theme.p5LabelPx
            wrapMode: Text.Wrap
        }

        // ---- a line ----
        P5Plate {
            id: plate
            visible: root.kind !== "group" && root.kind !== "note" && root.kind !== "embed"
            width: parent.width
            height: parent.height - px
            y: px / 2
            poly: [[0, 0], [width, height * 0.06], [width - width * 0.006, height], [width * 0.006, height * 0.94]]
            color: root.inverted ? root.pal.black : root.kind === "more" ? root.pal.paper2 : root.pal.white
            // (no shadow: shifted under the slanted bottom edge it left accent dashes; the
            // selected line's accent edge below marks it)
            shadow: "transparent"
            shadowX: -px * 2
            shadowY: 0
        }
        // the selected line's accent edge
        Rectangle {
            visible: root.selected && plate.visible
            x: 0
            y: px * 2
            width: px * 3
            height: plate.height - px * 3
            color: root.pal.accent
        }
        PxText {
            id: label
            kind: "title"
            font.family: Theme.fontP5Body
            font.pixelSize: Theme.p5LabelPx
            font.bold: true
            visible: root.kind !== "group" && root.kind !== "note" && root.kind !== "embed"
            x: px * 7
            y: root.kind === "custom" ? px * 3 : (body.lineH - height) / 2
            width: root.kind === "custom" ? root.width - px * 14 : Math.max(px * 20, root.width - valueBox.width - px * 16)
            text: root.kind === "result" ? root.line.r.title : root.kind === "more" ? I18n.t("Ещё…", "More…") + (root.line.count ? "  ·  " + root.line.count : "") : root.e ? root.e.label : ""
            color: root.live ? root.ink : Theme.mix(root.ink, root.inverted ? root.pal.black : root.pal.white, 0.5)
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }

        // ---- the value ----
        Row {
            id: valueBox
            visible: root.kind !== "group" && root.kind !== "note" && root.kind !== "custom" && root.kind !== "embed"
            anchors.right: parent.right
            anchors.rightMargin: px * 6
            y: (body.lineH - height) / 2
            spacing: px * 3
            scale: root.popScale
            opacity: root.live ? 1 : 0.5

            // ВКЛ / ВЫКЛ
            Repeater {
                model: root.kind === "toggle" ? [true, false] : []
                Item {
                    id: sw
                    required property bool modelData
                    readonly property bool on: root.checkedNow === modelData
                    width: swText.implicitWidth + px * 8
                    height: swText.implicitHeight + px * 3
                    scale: on ? 1.08 : 1
                    P5Plate {
                        anchors.fill: parent
                        poly: [[px * 2, 0], [width, 0], [width - px * 2, height], [0, height]]
                        color: sw.on ? (root.selected ? root.pal.accent : root.pal.black) : root.pal.paper2
                    }
                    PxText {
                        id: swText
                        kind: "title"
                        anchors.centerIn: parent
                        text: sw.modelData ? I18n.t("ВКЛ", "ON") : I18n.t("ВЫКЛ", "OFF")
                        color: sw.on ? (root.selected ? root.pal.black : root.pal.paper) : root.pal.black
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.pick();
                            if (!sw.on)
                                root.step(1);
                        }
                    }
                }
            }
            // ◀ value ▶ (a choice, a number)
            Item {
                id: chooser
                visible: root.kind === "choice" || root.kind === "spin"
                width: Math.max(px * 60, chooserText.width + arrowL.implicitWidth + arrowR.implicitWidth + px * 22)
                height: chooserText.implicitHeight + px * 3
                P5Plate {
                    anchors.fill: parent
                    poly: [[px * 3, 0], [width, 0], [width - px * 3, height], [0, height]]
                    color: root.selected ? root.pal.accent : root.pal.paper2
                }
                PxText {
                    id: arrowL
                    kind: "title"
                    font.bold: true
                    x: px * 4 + (root.selected && nudge.on ? -px : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "◀"
                    color: root.pal.black
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -px * 3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.pick();
                            root.step(-1);
                        }
                    }
                }
                PxText {
                    id: chooserText
                    kind: "title"
                    font.family: Theme.fontP5Body
                    font.pixelSize: Theme.p5LabelPx
                    anchors.centerIn: parent
                    // (between the arrows: ▶ is wider than ◀ in this face)
                    anchors.horizontalCenterOffset: (arrowL.implicitWidth - arrowR.implicitWidth) / 2
                    width: Math.min(implicitWidth, Math.max(px * 40, root.width * 0.4))
                    elide: Text.ElideRight
                    text: root.kind === "choice" ? root.choiceLabel : root.kind === "spin" && root.e ? root.numberText(root.valueNow) : ""
                    color: root.pal.black
                    font.bold: true
                }
                PxText {
                    id: arrowR
                    kind: "title"
                    font.family: Theme.fontP5Body
                    font.pixelSize: Theme.p5LabelPx
                    font.bold: true
                    anchors.right: parent.right
                    anchors.rightMargin: px * 4 + (root.selected && !nudge.on ? -px : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▶"
                    color: root.pal.black
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -px * 3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.pick();
                            root.step(1);
                        }
                    }
                }
            }
            // a bar and its number
            Item {
                id: bar
                visible: root.kind === "slider"
                width: px * 50
                height: px * 6
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                readonly property real frac: root.kind === "slider" && root.e && root.e.to !== root.e.from ? Math.max(0, Math.min(1, (root.valueNow - root.e.from) / (root.e.to - root.e.from))) : 0
                P5Plate {
                    anchors.fill: parent
                    poly: [[px * 2, 0], [width, 0], [width - px * 2, height], [0, height]]
                    color: root.pal.paper3
                }
                P5Plate {
                    width: Math.max(px * 3, parent.width * bar.frac)
                    height: parent.height
                    poly: [[px * 2, 0], [width, 0], [width - px * 2, height], [0, height]]
                    color: root.selected ? root.pal.accent : root.pal.black
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -px * 3
                    cursorShape: Qt.PointingHandCursor
                    function at(mx) {
                        const e = root.e, f = Math.max(0, Math.min(1, mx / bar.width));
                        let v = e.from + (e.to - e.from) * f;
                        if (e.stepSize > 0)
                            v = Math.round((v - e.from) / e.stepSize) * e.stepSize + e.from;
                        return Number(v.toFixed(Math.max(e.decimals || 0, 3)));
                    }
                    onPressed: m => {
                        root.pick();
                        root.hold(at(m.x));
                        if (root.e.live)
                            root.e.moved(root.held);
                    }
                    onPositionChanged: m => {
                        if (!pressed)
                            return;
                        root.hold(at(m.x));
                        if (root.e.live)
                            root.e.moved(root.held);
                    }
                    onReleased: m => {
                        const v = at(m.x);
                        root.hold(v);
                        root.e.moved(v);
                        root.e.released(v);
                        root.moved(1);
                    }
                }
            }
            PxText {
                kind: "title"
                font.family: Theme.fontP5Body
                font.pixelSize: Theme.p5LabelPx
                visible: root.kind === "slider" && root.e && root.e.showValue
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                text: root.kind === "slider" && root.e ? root.numberText(root.valueNow) : ""
                color: root.ink
                font.bold: true
            }
            // a text typed in
            Item {
                id: fieldBox
                visible: root.kind === "field"
                width: Math.min(px * 120, Math.max(px * 70, root.width * 0.45))
                height: input.font.pixelSize + px * 6
                P5Plate {
                    anchors.fill: parent
                    poly: [[0, 0], [width, 0], [width, height], [0, height]]
                    color: input.activeFocus ? root.pal.paper : root.pal.paper2
                    rim: root.selected ? root.pal.accent : "transparent"
                    shadowX: 0
                    shadowY: 0
                }
                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: px * 3
                    anchors.rightMargin: px * 3
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: root.pal.black
                    selectionColor: root.pal.accent
                    font.family: Theme.fontBody
                    font.pixelSize: Theme.sizeBody
                    renderType: Text.NativeRendering
                    echoMode: root.e && root.e.password ? TextInput.Password : TextInput.Normal
                    text: root.kind === "field" && root.e ? root.e.text : ""
                    onTextEdited: root.e.edit(text)
                    onAccepted: {
                        root.e.accepted();
                        focus = false;
                    }
                    onEditingFinished: {
                        root.e.editingFinished();
                        root.e.release();
                    }
                    Keys.onEscapePressed: focus = false
                    PxText {
                        kind: "title"
                        font.bold: true
                        visible: !input.text && !input.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.e && root.kind === "field" ? root.e.placeholder : ""
                        color: Theme.mix(root.pal.black, root.pal.paper, 0.5)
                    }
                }
            }
            // the line's button and its other buttons: they wrap under one another when the card
            // is too narrow for them in a row (never pushed off the card's left edge)
            Flow {
                id: pressFlow
                readonly property real natural: {
                    let w = 0, n = 0;
                    for (const c of children)
                        if (c.visible && c.width > 0) {
                            w += c.width;
                            n++;
                        }
                    return w + Math.max(0, n - 1) * spacing;
                }
                // (not by `natural`: an unseen Flow's children read unseen, it would stay hidden)
                visible: press.visible || !!(root.e && root.kind !== "custom" && root.e.actions && root.e.actions.some(a => a.present))
                width: Math.min(natural, Math.max(px * 20, root.width - px * 14 - (label.text !== "" ? Math.min(label.implicitWidth, root.width * 0.45) + px * 6 : 0)))
                spacing: px * 3
                // a button, a link
                Item {
                    id: press
                    visible: root.kind === "button" || root.kind === "link" || root.kind === "more" || root.kind === "result"
                    width: pressRow.implicitWidth + px * 12
                    height: pressText.implicitHeight + px * 3
                    P5Plate {
                        anchors.fill: parent
                        poly: [[px * 3, 0], [width, 0], [width - px * 3, height], [0, height]]
                        color: root.selected ? root.pal.accent : root.e && root.e.danger ? root.pal.danger : root.e && root.e.accent ? root.pal.black : root.pal.paper2
                    }
                    Row {
                        id: pressRow
                        anchors.centerIn: parent
                        spacing: px * 2
                        // an icon-only button shows its icon, never the icon's name
                        PxIcon {
                            visible: root.kind === "button" && !!root.e && root.e.icon !== ""
                            name: root.e && root.e.icon || "heart"
                            pixel: Theme.u
                            anchors.verticalCenter: parent.verticalCenter
                            ink: pressText.color
                        }
                        PxText {
                            id: pressText
                            kind: "title"
                            visible: text !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.kind === "result" ? (root.line.r.crumb || root.line.r.title) + " ›" : root.kind === "more" ? (root.line.opened ? "▴" : "▾") : root.kind === "link" && root.e ? root.e.target + " ›" : root.e && root.kind === "button" ? root.e.text : ""
                            color: !root.selected && root.e && (root.e.accent || root.e.danger) ? root.pal.paper : root.pal.black
                            font.bold: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.pick();
                            root.activate();
                        }
                    }
                }
                // a line's other buttons
                Repeater {
                    model: root.e && root.kind !== "custom" ? root.e.actions : []
                    Item {
                        id: act
                        required property var modelData
                        visible: modelData.present
                        width: actRow.implicitWidth + px * 8
                        height: actText.implicitHeight + px * 3
                        opacity: modelData.enabled ? 1 : 0.5
                        P5Plate {
                            anchors.fill: parent
                            poly: [[px * 2, 0], [width, 0], [width - px * 2, height], [0, height]]
                            color: actMouse.containsMouse ? root.pal.accent : root.pal.paper2
                        }
                        Row {
                            id: actRow
                            anchors.centerIn: parent
                            spacing: px * 2
                            PxIcon {
                                visible: act.modelData.icon !== ""
                                name: act.modelData.icon || "heart"
                                pixel: Theme.u
                                anchors.verticalCenter: parent.verticalCenter
                                ink: root.pal.black
                            }
                            PxText {
                                id: actText
                                kind: "title"
                                font.bold: true
                                visible: text !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: act.modelData.text
                                color: root.pal.black
                            }
                        }
                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pick();
                                if (act.modelData.enabled)
                                    act.modelData.clicked();
                                Sounds.playSoft("click", 0.6);
                            }
                        }
                    }
                }
            }
        }
        // the arrows of the selected line push in turn
        Timer {
            id: nudge
            property bool on: false
            running: root.selected && !Motion.still
            repeat: true
            interval: 250
            onTriggered: on = !on
        }

        Column {
            id: under
            visible: root.opened
            x: px * 7
            y: body.lineH - px * 2
            width: root.width - px * 14
            spacing: px * 2
            PxText {
                width: parent.width
                visible: root.hintText !== ""
                text: root.hintText
                wrapMode: Text.Wrap
                kind: "title"
                font.family: Theme.fontP5Body
                font.pixelSize: Math.round(Theme.p5LabelPx * 0.7)
                color: Theme.mix(root.ink, root.inverted ? root.pal.black : root.pal.white, 0.25)
            }
            Loader {
                id: preview
                active: root.opened && root.previewScene !== "" && !root.previewShut
                width: Math.min(parent.width, px * 230)
                height: item ? item.implicitHeight : 0
                sourceComponent: PxPreview {
                    width: preview.width
                    height: implicitHeight
                    scene: root.previewScene
                    variant: root.previewVariant
                    caption: root.previewCaption
                    onCloseClicked: root.previewShut = true
                }
            }
        }

        // ---- a custom part: the page's own controls, on a dark inset ----
        Column {
            id: customCol
            visible: root.kind === "custom"
            x: px * 7
            y: root.e && root.e.label ? label.y + label.height + px * 2 : px * 3
            width: root.width - px * 14
            spacing: px
            Rectangle {
                width: parent.width
                height: host.height + px * 8
                color: "transparent"
                CatHost {
                    id: host
                    x: px * 4
                    y: px * 4
                    width: parent.width - px * 8
                    entry: root.kind === "custom" ? root.e : null
                }
            }
        }
    }

    // ---- a page of its own inside the card: a plugin's settings, the owner's pages ----
    Rectangle {
        id: embedBox
        visible: root.kind === "embed"
        parent: body
        x: px * 2
        y: px * 3
        width: root.width - px * 4
        height: root.kind === "embed" ? embed.height + px * 8 : 0
        color: "transparent"
        Loader {
            id: embed
            x: px * 4
            y: px * 4
            width: parent.width - px * 8
            height: item ? item.implicitHeight : 0
            active: root.kind === "embed"
            Component.onCompleted: {
                if (root.kind !== "embed")
                    return;
                if (root.line.plugin) {
                    const p = Plugins.byId(root.line.plugin);
                    if (p && p.settings)
                        setSource(Plugins.url(p, p.settings), {
                            "plugin": Plugins.context(p)
                        });
                } else if (root.line.file) {
                    setSource(root.line.file, {
                        "embedded": true,
                        "loose": true
                    });
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        // only a mouse that moves picks: the list sliding under a resting pointer doesn't
        onPositionChanged: m => {
            const g = mapToGlobal(m.x, m.y);
            if (root.gate && !root.gate(g))
                return;
            if (root.selectable && !root.selected)
                root.pick();
        }
        // a click on the name only picks the row: a setting changes on its value or button
        // (a stray click on a toggle's name flipped it); rows that are a way somewhere still go
        onClicked: {
            root.pick();
            if (["result", "more", "link", "field"].includes(root.kind))
                root.activate();
        }
    }
}
