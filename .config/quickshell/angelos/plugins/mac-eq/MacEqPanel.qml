pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The popover's body: on/off, presets, the curve over the spectrum, ten Mac sliders and the
// app routing — what the pixel EQ window has (modules/bar/parts/EqButton), drawn the macOS way
// on the Theme API.
Column {
    id: root

    property bool shown: false
    readonly property bool ready: Eq.ready
    readonly property bool on: Eq.ready && Eq.active
    readonly property var levels: Eq.levels
    readonly property var spectrum: Eq.spectrumLevels
    property real pulse: -1

    spacing: Skin.px(12)

    readonly property var choices: [
        { "value": "flat", "label": I18n.t("Ровно", "Flat") },
        { "value": "bass", "label": I18n.t("Бас", "Bass") },
        { "value": "voice", "label": I18n.t("Голос", "Voice") },
        { "value": "air", "label": I18n.t("Воздух", "Air") },
        { "value": "soft", "label": I18n.t("Мягко", "Soft") }
    ]
    function shownLevel(x) {
        return Math.sqrt(Math.max(0, Math.min(1, x)));
    }
    function pulseAt(i) {
        const d = pulse - i;
        return d >= 0 && d < 1 ? Math.sin(d * Math.PI) : 0;
    }
    function freqLabel(f) {
        return f >= 1000 ? (f / 1000) + "k" : String(f);
    }
    NumberAnimation {
        id: sweep
        target: root
        property: "pulse"
        from: 0
        to: 10
        duration: Skin.ms(740)
        onFinished: root.pulse = -1
    }

    // ---- on / off ----
    Item {
        width: parent.width
        height: Math.max(sw.implicitHeight, Skin.px(22))
        Column {
            anchors.verticalCenter: parent.verticalCenter
            PxText {
                text: "EasyEffects"
                kind: "body"
                color: Skin.text
            }
            PxText {
                text: !root.ready ? (Eq.error || I18n.t("не запущен", "not running")) : root.on ? I18n.t("Выход · 10 полос", "Output · 10 bands") : I18n.t("Выключен — звук идёт как есть", "Bypassed — sound plays as is")
                kind: "small"
                color: root.ready ? Skin.textDim : Skin.danger
            }
        }
        PxToggle {
            id: sw
            visible: root.ready
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Eq.active
            onToggled: Eq.send("toggle")
        }
        PxButton {
            visible: !root.ready
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            accent: true
            compact: true
            text: I18n.t("Запустить", "Start")
            onClicked: Eq.send("start")
        }
    }

    // ---- presets: a segmented control ----
    Rectangle {
        visible: root.ready
        width: parent.width
        height: Skin.px(28)
        radius: Skin.px(8)
        color: Skin.sunken
        Row {
            anchors.fill: parent
            anchors.margins: Skin.px(2)
            Repeater {
                model: root.choices
                Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool picked: Eq.preset === modelData.value
                    width: parent.width / root.choices.length
                    height: parent.height
                    Rectangle {
                        anchors.fill: parent
                        radius: Skin.px(6)
                        color: seg.picked ? Skin.accent : segHot.containsMouse ? Skin.hover : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: Skin.ms(140) }
                        }
                    }
                    Rectangle {
                        visible: seg.index > 0 && !seg.picked && Eq.preset !== root.choices[seg.index - 1].value
                        width: 1
                        height: parent.height * 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Skin.separator
                    }
                    PxText {
                        anchors.centerIn: parent
                        text: seg.modelData.label
                        kind: "small"
                        color: seg.picked ? Skin.accentText : Skin.text
                    }
                    MouseArea {
                        id: segHot
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!Motion.still)
                                sweep.restart();
                            Eq.send("preset " + seg.modelData.value);
                        }
                    }
                }
            }
        }
    }

    // ---- the curve over the spectrum ----
    Rectangle {
        id: graph
        width: parent.width
        height: Skin.px(96)
        radius: Skin.radius
        color: Skin.sunken
        clip: true
        Canvas {
            id: curve
            anchors.fill: parent
            anchors.topMargin: Skin.px(10)
            anchors.bottomMargin: Skin.px(10)
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height, col = w / 10;
                const yOf = g => h * (0.5 - g / 24);
                // grid: 0 dB stronger
                ctx.lineWidth = 1;
                ctx.strokeStyle = Skin.separator;
                for (const g of [12, 6, 0, -6, -12]) {
                    ctx.globalAlpha = g === 0 ? 1 : 0.5;
                    ctx.beginPath();
                    ctx.moveTo(0, Math.round(yOf(g)) + 0.5);
                    ctx.lineTo(w, Math.round(yOf(g)) + 0.5);
                    ctx.stroke();
                }
                // spectrum: soft rounded bars
                ctx.fillStyle = Skin.accent;
                for (let i = 0; i < 10; i++) {
                    const a = root.shownLevel(root.spectrum[i] || 0);
                    if (a <= 0)
                        continue;
                    const bh = a * h * 0.8, bw = col * 0.42, x = col * (i + 0.5) - bw / 2;
                    ctx.globalAlpha = root.on ? 0.22 : 0.1;
                    ctx.beginPath();
                    ctx.roundedRect(x, h - bh, bw, bh + bw, bw / 2, bw / 2);
                    ctx.fill();
                }
                // pulse after a preset
                for (let i = 0; i < 10; i++) {
                    const s = root.pulseAt(i);
                    if (s < 0.02)
                        continue;
                    ctx.globalAlpha = s * 0.25;
                    ctx.fillRect(col * i, -h, col, h * 3);
                }
                // the curve: Catmull-Rom through the bands' centres
                const pts = [];
                for (let i = 0; i < 10; i++) {
                    const b = bands.itemAt(i);
                    pts.push([col * (i + 0.5), yOf(b ? b.shown : (root.levels[i] || 0))]);
                }
                const p = i => pts[Math.max(0, Math.min(9, i))];
                const trace = () => {
                    ctx.moveTo(0, pts[0][1]);
                    ctx.lineTo(pts[0][0], pts[0][1]);
                    for (let i = 0; i < 9; i++) {
                        const p0 = p(i - 1), p1 = p(i), p2 = p(i + 1), p3 = p(i + 2);
                        ctx.bezierCurveTo(p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6, p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6, p2[0], p2[1]);
                    }
                    ctx.lineTo(w, pts[9][1]);
                };
                ctx.beginPath();
                trace();
                ctx.lineTo(w, yOf(0));
                ctx.lineTo(0, yOf(0));
                ctx.closePath();
                ctx.globalAlpha = root.on ? 0.18 : 0.08;
                ctx.fillStyle = root.on ? Skin.accent : Skin.textDim;
                ctx.fill();
                ctx.beginPath();
                trace();
                ctx.globalAlpha = 1;
                ctx.lineWidth = Skin.px(2);
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.strokeStyle = root.on ? Skin.accent : Skin.textDim;
                ctx.stroke();
            }
            Connections {
                target: root
                function onLevelsChanged() { curve.requestPaint(); }
                function onOnChanged() { curve.requestPaint(); }
                function onSpectrumChanged() { if (root.shown) curve.requestPaint(); }
                function onPulseChanged() { curve.requestPaint(); }
            }
            Connections {
                target: Skin
                function onAccentChanged() { curve.requestPaint(); }
                function onDarkChanged() { curve.requestPaint(); }
            }
        }
        PxText { x: Skin.px(6); y: Skin.px(3); text: "+12"; kind: "tiny"; color: Skin.textFaint }
        PxText { x: Skin.px(6); anchors.bottom: parent.bottom; anchors.bottomMargin: Skin.px(2); text: "−12"; kind: "tiny"; color: Skin.textFaint }
    }

    // ---- ten bands: Mac sliders standing up ----
    Row {
        width: parent.width
        height: Skin.px(150)
        Repeater {
            id: bands
            model: 10
            Item {
                id: band
                required property int index
                width: parent.width / 10
                height: parent.height
                readonly property real gain: root.levels[index] || 0
                readonly property int freq: Eq.frequencies[index] || 0
                property real shown: gain
                onGainChanged: if (!drag.pressed) shown = gain
                onShownChanged: curve.requestPaint()
                Behavior on shown {
                    enabled: !drag.pressed && !Motion.still
                    NumberAnimation { duration: Skin.ms(360); easing.type: Easing.OutCubic }
                }
                function nudge(step) {
                    shown = Math.max(-12, Math.min(12, Math.round((shown + step) * 2) / 2));
                    Eq.changeBand(index, shown);
                }
                activeFocusOnTab: true
                Keys.onUpPressed: nudge(0.5)
                Keys.onDownPressed: nudge(-0.5)
                Accessible.role: Accessible.Slider
                Accessible.name: freq >= 1000 ? (freq / 1000) + " kHz" : freq + " Hz"
                Accessible.description: shown.toFixed(1) + " dB"
                Accessible.focusable: true
                Accessible.onIncreaseAction: nudge(0.5)
                Accessible.onDecreaseAction: nudge(-0.5)

                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (band.shown > 0.05 ? "+" : "") + band.shown.toFixed(Math.abs(band.shown % 1) > 0.05 ? 1 : 0)
                    kind: "tiny"
                    color: root.on ? Skin.text : Skin.textFaint
                }
                Item {
                    id: rail
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Skin.px(18)
                    width: Skin.px(18)
                    height: parent.height - Skin.px(38)
                    readonly property real knobY: (12 - band.shown) / 24 * height
                    // the track
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Skin.px(4)
                        height: parent.height
                        radius: width / 2
                        color: Skin.sunken
                        border.width: 1
                        border.color: Skin.separator
                    }
                    // the accent from 0 dB to the knob
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Skin.px(4)
                        y: Math.min(rail.knobY, rail.height / 2)
                        height: Math.abs(rail.knobY - rail.height / 2)
                        radius: width / 2
                        color: root.on ? Skin.accent : Skin.textFaint
                    }
                    // 0 dB tick
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height / 2
                        width: Skin.px(10)
                        height: 1
                        color: Skin.separator
                    }
                    // the knob: round, light, a soft shadow under it
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: rail.knobY - height / 2 + Skin.px(1)
                        width: Skin.px(16)
                        height: width
                        radius: width / 2
                        color: Skin.shadow
                        opacity: 0.6
                    }
                    Rectangle {
                        id: knob
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: rail.knobY - height / 2
                        width: Skin.px(16)
                        height: width
                        radius: width / 2
                        color: Skin.dark ? Skin.mix(Skin.text, Skin.accent, 0.08) : Skin.surfaceAlt
                        border.width: 1
                        border.color: Skin.separator
                        scale: drag.pressed ? 1.12 : 1
                        Behavior on scale {
                            NumberAnimation { duration: Skin.ms(120) }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: Skin.px(5)
                            height: width
                            radius: width / 2
                            color: root.on ? Skin.accent : Skin.textFaint
                            opacity: band.activeFocus || drag.containsMouse ? 1 : 0.0
                        }
                    }
                    // the pulse after a preset
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Skin.px(12)
                        height: parent.height + Skin.px(8)
                        y: -Skin.px(4)
                        radius: width / 2
                        color: Skin.accent
                        opacity: root.pulseAt(band.index) * 0.3
                    }
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    enabled: root.on
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    function moveTo(my) {
                        const v = Math.max(-12, Math.min(12, Math.round((12 - (my - rail.y) * 24 / rail.height) * 2) / 2));
                        if (v !== band.shown) {
                            band.shown = v;
                            Eq.changeBand(band.index, v);
                        }
                    }
                    onPressed: m => {
                        band.forceActiveFocus();
                        moveTo(m.y);
                    }
                    onPositionChanged: m => {
                        if (pressed)
                            moveTo(m.y);
                    }
                    onDoubleClicked: {
                        band.shown = 0;
                        Eq.changeBand(band.index, 0);
                    }
                    onWheel: w => band.nudge(w.angleDelta.y > 0 ? 0.5 : -0.5)
                }
                PxText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: root.freqLabel(band.freq)
                    kind: "tiny"
                    color: Skin.textDim
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Skin.separator
    }

    // ---- routing: one app through the equalizer ----
    PxText {
        text: I18n.t("Через эквалайзер", "Through the equalizer")
        kind: "small"
        color: Skin.textDim
        font.weight: Font.DemiBold
    }
    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Skin.px(10)
        rowSpacing: Skin.px(8)
        verticalItemAlignment: Grid.AlignVCenter
        PxText {
            id: appLabel
            text: I18n.t("Приложение", "App")
            kind: "body"
            color: Skin.text
        }
        PxCombo {
            width: root.width - Math.max(appLabel.implicitWidth, outLabel.implicitWidth) - Skin.px(10)
            model: Eq.sourceChoices
            currentValue: Eq.selectedSource
            placeholder: I18n.t("нет активного звука", "no active audio")
            onActivated: value => {
                Eq.selectedSource = value;
                Eq.routingError = "";
                if (!Eq.outputExplicit) {
                    const preferred = Eq.defaultOutputFor(value);
                    if (preferred)
                        Eq.selectedOutput = preferred;
                }
            }
        }
        PxText {
            id: outLabel
            text: Eq.rode ? "RØDE" : I18n.t("Выход", "Output")
            kind: "body"
            color: Skin.text
        }
        PxCombo {
            width: root.width - Math.max(appLabel.implicitWidth, outLabel.implicitWidth) - Skin.px(10)
            model: Eq.outputChoices
            currentValue: Eq.selectedOutput
            placeholder: I18n.t("канал недоступен", "channel unavailable")
            onActivated: value => {
                Eq.selectedOutput = value;
                Eq.outputExplicit = true;
                Eq.routingError = "";
            }
        }
    }
    Row {
        spacing: Skin.px(8)
        PxButton {
            compact: true
            accent: true
            text: I18n.t("Применить EQ", "Apply EQ")
            enabled: root.ready && !!Eq.selectedSource && !!Eq.selectedOutput
            onClicked: Eq.routeCommand("route")
        }
        PxButton {
            compact: true
            text: I18n.t("Напрямую", "Direct")
            enabled: !!Eq.selectedSource && !!Eq.selectedOutput
            onClicked: Eq.routeCommand("direct")
        }
        PxButton {
            visible: Eq.routeActive
            compact: true
            text: I18n.t("Вернуть", "Restore")
            onClicked: Eq.releaseRoute()
        }
    }
    PxText {
        width: parent.width
        wrapMode: Text.WordWrap
        kind: "small"
        color: Eq.routingError ? Skin.danger : Skin.textDim
        text: Eq.routingError || (Eq.routeActive
              ? Eq.routedApp + " → " + (Eq.outputChoices.find(item => item.value === Eq.routedOutput)?.label || Eq.routedOutput)
              : I18n.t("Выбери приложение и выход, чтобы пустить его через эквалайзер.", "Pick an app and an output to send it through the equalizer."))
    }
}
