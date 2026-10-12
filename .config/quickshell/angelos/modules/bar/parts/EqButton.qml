pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar
import "EqMotion.js" as EqMotion

// An instrument face in the bar, with the controls in a small window above it.
Item {
    id: root
    property bool above: true
    property bool barInk: false
    property bool vertical: false
    readonly property var levels: Eq.levels
    readonly property var frequencies: Eq.frequencies
    readonly property string preset: Eq.preset
    readonly property string error: Eq.error
    readonly property bool ready: Eq.ready
    readonly property bool active: Eq.active
    readonly property var spectrumLevels: Eq.spectrumLevels
    property real pulseProgress: -1
    // the bridge and the spectrum are shared by every bar: services/Eq
    property bool watching: false
    property bool viewing: false
    // a face that is going away still hears that it is no longer visible: count it out once
    property bool gone: false
    function count() {
        if (gone)
            return;
        if (watching !== visible) {
            watching = visible;
            Eq.watchers += watching ? 1 : -1;
        }
        // (the popup's own word: it calls this from its handler, before `pop.visible` follows)
        const open = !!pop.item && pop.item.visible;
        if (viewing !== open) {
            viewing = open;
            Eq.viewers += viewing ? 1 : -1;
        }
    }
    onVisibleChanged: count()
    Component.onCompleted: count()
    Component.onDestruction: {
        gone = true;
        if (watching)
            Eq.watchers--;
        if (viewing)
            Eq.viewers--;
    }
    readonly property var choices: [
        { "id": "flat", "label": I18n.t("РОВНО", "FLAT") },
        { "id": "bass", "label": I18n.t("БАС", "BASS") },
        { "id": "voice", "label": I18n.t("ГОЛОС", "VOICE") },
        { "id": "air", "label": I18n.t("ВОЗДУХ", "AIR") },
        { "id": "soft", "label": I18n.t("МЯГКО", "SOFT") }
    ]
    implicitWidth: vertical ? Theme.u * 17 : Theme.u * 45
    implicitHeight: Theme.u * 15
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: I18n.t("Эквалайзер EasyEffects", "EasyEffects equalizer")
    Accessible.description: ready ? (active ? I18n.t("включён", "enabled") : I18n.t("выключен", "bypassed")) : error
    Accessible.focusable: true
    Accessible.onPressAction: pop.toggle()
    Keys.onReturnPressed: pop.toggle()
    Keys.onSpacePressed: pop.toggle()

    function triggerPulse() {
        if (Motion.still) return;
        sweep.stop();
        pulseProgress = 0;
        sweep.start();
    }
    SequentialAnimation {
        id: sweep
        NumberAnimation {
            target: root
            property: "pulseProgress"
            from: 0
            to: 10
            duration: Motion.ms(740)
            easing.type: Easing.Linear
        }
        ScriptAction { script: root.pulseProgress = -1 }
    }

    PxBox {
        anchors.fill: parent
        sunken: pop.visible
        hell: root.barInk
        color: root.barInk ? Theme.hellFace : Theme.face
    }
    PxText {
        id: mark
        anchors.left: parent.left
        anchors.leftMargin: Theme.u * 3
        anchors.verticalCenter: parent.verticalCenter
        text: "EQ"
        kind: "tiny"
        color: root.barInk ? Theme.hellText : root.active ? Theme.accent : Theme.textDim
    }
    Canvas {
        id: thumbnail
        visible: !root.vertical
        anchors.left: mark.right
        anchors.leftMargin: Theme.u * 2
        anchors.right: parent.right
        anchors.rightMargin: Theme.u * 3
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.u * 10
        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.lineWidth = 1;
            ctx.strokeStyle = Theme.textDim;
            ctx.beginPath(); ctx.moveTo(0, height / 2); ctx.lineTo(width, height / 2); ctx.stroke();
            ctx.fillStyle = root.barInk ? Theme.hellEmber : Theme.accent2;
            ctx.globalAlpha = root.active ? 0.78 : 0.26;
            for (let i = 0; i < 10; i++) {
                let amount = EqMotion.displayLevel(root.spectrumLevels[i] || 0);
                if (amount > 0) {
                    let unit = width / 10;
                    ctx.fillRect(i * unit + 1, height - amount * height, Math.max(1, unit - 2), amount * height);
                }
            }
            ctx.strokeStyle = root.barInk ? Theme.hellEmber : Theme.accent;
            ctx.globalAlpha = root.active ? 1 : 0.5;
            ctx.lineWidth = Math.max(1, Theme.u);
            ctx.beginPath();
            for (let i = 0; i < 10; i++) {
                let x = width * i / 9, y = height * (0.5 - root.levels[i] / 28);
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.stroke();
            ctx.globalAlpha = 1;
        }
        Connections {
            target: root
            function onLevelsChanged() { thumbnail.requestPaint(); }
            function onActiveChanged() { thumbnail.requestPaint(); }
            function onSpectrumLevelsChanged() { thumbnail.requestPaint(); }
            function onPulseProgressChanged() { thumbnail.requestPaint(); }
        }
    }
    MouseArea {
        id: hot
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pop.toggle()
    }

    // built when the pointer comes to the button, gone a while after it closed (LazyPopup)
    LazyPopup {
        id: pop
        panelId: "equalizer"
        anchorItem: root
        warm: hot.containsMouse
        BarPopup {
            id: panel
            anchorItem: root
            above: root.above
            title: I18n.exe("eq") + "  /  EasyEffects"
            panelId: "equalizer"
            icon: "music"
            contentWidth: Theme.u * 236
            contentHeight: Theme.u * 264
            onVisibleChanged: {
                root.count();
                if (visible) {
                    Eq.send("status");
                    Eq.send("sources");
                }
            }

            Item {
                anchors.fill: parent
                Rectangle {
                    width: Theme.u * 2
                    height: Theme.u * 11
                    color: root.active ? Theme.accent : Theme.textDim
                }
                PxText {
                    x: Theme.u * 6
                    text: "OUT  /  10 BAND"
                    kind: "tiny"
                    color: Theme.textDim
                }
                PxButton {
                    anchors.right: parent.right
                    y: -Theme.u
                    compact: true
                    text: root.active ? I18n.t("● ВКЛ", "● ON") : I18n.t("○ ВЫКЛ", "○ OFF")
                    enabled: root.ready
                    checked: root.active
                    onClicked: Eq.send("toggle")
                }
                PxText {
                    x: 0
                    y: Theme.u * 15
                    width: parent.width
                    kind: "tiny"
                    color: root.ready ? Theme.textDim : Theme.danger
                    wrapMode: Text.WordWrap
                    text: Eq.routingError || root.error || (Eq.routeActive
                          ? I18n.t("EQ: ", "EQ: ") + Eq.routedApp + " → " + (Eq.outputChoices.find(item => item.value === Eq.routedOutput)?.label || Eq.routedOutput)
                          : I18n.t("ВЫБЕРИ ПРИЛОЖЕНИЕ И КАНАЛ", "SELECT APP AND CHANNEL"))
                }
                PxText {
                    x: 0
                    y: Theme.u * 29
                    width: Theme.u * 20
                    height: Theme.u * 14
                    kind: "tiny"
                    text: "APP"
                    color: Theme.textDim
                }
                PxCombo {
                    x: Theme.u * 20
                    y: Theme.u * 27
                    width: parent.width - Theme.u * 20
                    height: Theme.u * 16
                    model: Eq.sourceChoices
                    currentValue: Eq.selectedSource
                    placeholder: I18n.t("нет активного звука", "no active audio")
                    onActivated: value => {
                        Eq.selectedSource = value;
                        Eq.routingError = "";
                        if (!Eq.outputExplicit) {
                            const preferred = Eq.defaultOutputFor(value);
                            if (preferred) Eq.selectedOutput = preferred;
                        }
                    }
                }
                PxText {
                    x: 0
                    y: Theme.u * 48
                    width: Theme.u * 20
                    height: Theme.u * 14
                    kind: "tiny"
                    text: Eq.rode ? "RØDE" : I18n.t("ВЫХОД", "OUT")
                    color: Theme.textDim
                }
                PxCombo {
                    x: Theme.u * 20
                    y: Theme.u * 46
                    width: parent.width - Theme.u * 20
                    height: Theme.u * 16
                    model: Eq.outputChoices
                    currentValue: Eq.selectedOutput
                    placeholder: I18n.t("канал недоступен", "channel unavailable")
                    onActivated: value => {
                        Eq.selectedOutput = value;
                        Eq.outputExplicit = true;
                        Eq.routingError = "";
                    }
                }
                Row {
                    y: Theme.u * 65
                    spacing: Theme.u * 2
                    PxButton {
                        compact: true
                        accent: true
                        text: I18n.t("ПРИМЕНИТЬ EQ", "APPLY EQ")
                        enabled: root.ready && !!Eq.selectedSource && !!Eq.selectedOutput
                        onClicked: Eq.routeCommand("route")
                    }
                    PxButton {
                        compact: true
                        text: I18n.t("НАПРЯМУЮ", "DIRECT")
                        enabled: !!Eq.selectedSource && !!Eq.selectedOutput
                        onClicked: Eq.routeCommand("direct")
                    }
                    PxButton {
                        visible: Eq.routeActive
                        compact: true
                        text: I18n.t("ВОЗВРАТ", "RESTORE")
                        onClicked: Eq.releaseRoute()
                    }
                }
                PxButton {
                    visible: !root.ready
                    y: Theme.u * 83
                    compact: true
                    accent: true
                    text: I18n.t("ЗАПУСТИТЬ EQ", "START EQ")
                    onClicked: Eq.send("start")
                }
                Row {
                    id: presetRow
                    visible: root.ready
                    y: Theme.u * 83
                    width: parent.width
                    spacing: Theme.u * 2
                    Repeater {
                        model: root.choices
                        delegate: PxButton {
                            required property var modelData
                            width: (presetRow.width - presetRow.spacing * 4) / 5
                            compact: true
                            hpad: Theme.u * 3
                            text: modelData.label
                            checked: root.preset === modelData.id
                            onClicked: {
                                root.triggerPulse();
                                Eq.send("preset " + modelData.id);
                            }
                        }
                    }
                }
                Rectangle {
                    id: display
                    y: Theme.u * 103
                    width: parent.width
                    height: Theme.u * 55
                    color: Theme.sunken
                    border.width: Theme.u
                    border.color: Theme.edge
                    Canvas {
                        id: curve
                        anchors.fill: parent
                        anchors.margins: Theme.u * 6
                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.lineWidth = 1;
                            ctx.strokeStyle = Theme.textDim;
                            ctx.globalAlpha = 0.24;
                            for (let row = 0; row < 5; row++) {
                                let y = height * row / 4;
                                ctx.globalAlpha = row === 2 ? 0.52 : 0.24;
                                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                            }
                            ctx.globalAlpha = 0.24;
                            for (let i = 0; i < 10; i++) {
                                let x = width * i / 9;
                                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                            }
                            ctx.fillStyle = Theme.accent2;
                            ctx.globalAlpha = 0.43;
                            for (let i = 0; i < 10; i++) {
                                let amount = EqMotion.displayLevel(root.spectrumLevels[i] || 0);
                                if (amount > 0) {
                                    let x = width * i / 9, h = amount * height * 0.7;
                                    ctx.fillRect(x - Theme.u * 2, height - h, Theme.u * 4, h);
                                }
                            }
                            ctx.globalAlpha = 1;
                            ctx.strokeStyle = root.active ? Theme.accent : Theme.textDim;
                            ctx.fillStyle = ctx.strokeStyle;
                            ctx.lineWidth = Math.max(1, Theme.u);
                            ctx.beginPath();
                            for (let i = 0; i < 10; i++) {
                                let slider = bandRepeater.itemAt(i);
                                let value = slider ? slider.shown : root.levels[i];
                                let x = width * i / 9, y = height * (0.5 - value / 28);
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                                ctx.fillRect(x - Theme.u, y - Theme.u, Theme.u * 2, Theme.u * 2);
                            }
                            ctx.stroke();
                            ctx.fillStyle = Theme.accent;
                            for (let i = 0; i < 10; i++) {
                                let strength = EqMotion.pulseStrength(root.pulseProgress, i);
                                if (strength < 0.02) continue;
                                ctx.globalAlpha = strength * 0.9;
                                let x = width * i / 9;
                                ctx.fillRect(x - Theme.u * 3, 0, Theme.u * 6, height);
                            }
                            ctx.globalAlpha = 1;
                        }
                        Connections {
                            target: root
                            function onLevelsChanged() { curve.requestPaint(); }
                            function onActiveChanged() { curve.requestPaint(); }
                            function onSpectrumLevelsChanged() { if (panel.visible) curve.requestPaint(); }
                            function onPulseProgressChanged() { curve.requestPaint(); }
                        }
                    }
                    PxText { x: Theme.u * 2; y: Theme.u; kind: "tiny"; text: "+12"; color: Theme.textDim }
                    PxText { x: Theme.u * 2; anchors.bottom: parent.bottom; kind: "tiny"; text: "−12"; color: Theme.textDim }
                }
                Row {
                    id: bands
                    y: Theme.u * 163
                    width: parent.width
                    height: Theme.u * 70
                    Repeater {
                        id: bandRepeater
                        model: 10
                        delegate: Item {
                            id: band
                            required property int index
                            width: bands.width / 10
                            height: bands.height
                            property real gain: root.levels[index] || 0
                            property real shown: gain
                            onGainChanged: if (!drag.pressed) shown = gain
                            onShownChanged: curve.requestPaint()
                            Behavior on shown {
                                enabled: !drag.pressed && !Motion.still
                                NumberAnimation { duration: Motion.ms(360); easing.type: Easing.OutCubic }
                            }
                            readonly property int freq: root.frequencies[index] || 0
                            Accessible.role: Accessible.Slider
                            Accessible.name: freq >= 1000 ? (freq / 1000) + " kHz" : freq + " Hz"
                            Accessible.description: shown.toFixed(1) + " dB"
                            Accessible.focusable: true
                            activeFocusOnTab: true
                            Accessible.onIncreaseAction: nudge(0.5)
                            Accessible.onDecreaseAction: nudge(-0.5)
                            function nudge(step) {
                                shown = Math.max(-12, Math.min(12, shown + step));
                                Eq.changeBand(index, shown);
                            }
                            Keys.onUpPressed: band.nudge(0.5)
                            Keys.onDownPressed: band.nudge(-0.5)
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: -Theme.u * 3
                                kind: "tiny"
                                text: (band.shown > 0 ? "+" : "") + band.shown.toFixed(0)
                                color: root.active ? Theme.text : Theme.textDim
                            }
                            Rectangle {
                                id: rail
                                x: (parent.width - width) / 2
                                y: Theme.u * 3
                                width: Theme.u * 5
                                height: Theme.u * 46
                                color: Theme.sunken
                                border.width: Theme.u
                                border.color: Theme.edge
                            }
                            Rectangle {
                                x: rail.x - Theme.u * 3
                                y: rail.y + (12 - band.shown) * (rail.height - Theme.u * 5) / 24
                                width: Theme.u * 11
                                height: Theme.u * 5
                                color: root.active ? Theme.accent : Theme.textDim
                                border.width: 1
                                border.color: Theme.edge
                            }
                            Rectangle {
                                x: rail.x - Theme.u * 4
                                y: rail.y - Theme.u
                                width: Theme.u * 13
                                height: rail.height + Theme.u * 2
                                color: Theme.accent
                                opacity: EqMotion.pulseStrength(root.pulseProgress, band.index) * 0.4
                            }
                            MouseArea {
                                id: drag
                                width: parent.width
                                height: rail.height + Theme.u * 6
                                enabled: root.ready && root.active
                                cursorShape: Qt.SizeVerCursor
                                function moveTo(mouseY) {
                                    let value = Math.max(-12, Math.min(12, Math.round((12 - (mouseY - rail.y) * 24 / rail.height) * 2) / 2));
                                    if (value !== band.shown) {
                                        band.shown = value;
                                        Eq.changeBand(band.index, value);
                                    }
                                }
                                onPressed: mouse => moveTo(mouse.y)
                                onPositionChanged: mouse => { if (pressed) moveTo(mouse.y); }
                                onWheel: wheel => band.nudge(wheel.angleDelta.y > 0 ? 0.5 : -0.5)
                            }
                            PxText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: Theme.u * 54
                                kind: "tiny"
                                text: band.freq >= 1000 ? (band.freq / 1000) + "k" : String(band.freq)
                                color: Theme.textDim
                            }
                        }
                    }
                }
                PxText {
                    anchors.right: parent.right
                    y: Theme.u * 234
                    kind: "tiny"
                    text: root.preset ? root.preset.toUpperCase() : I18n.t("СВОЙ ПРОФИЛЬ", "CUSTOM")
                    color: root.active ? Theme.accent : Theme.textDim
                }
            }
        }
    }
}
