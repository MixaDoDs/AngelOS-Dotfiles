pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
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
    property var levels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var frequencies: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    property string preset: ""
    property string error: ""
    property bool ready: false
    property bool active: false
    property var spectrumLevels: []
    property real pulseProgress: -1
    readonly property bool spectrumLive: visible && !Motion.still && !Power.eco
    readonly property string spectrumKey: Math.random().toString(36).slice(2, 10)
    readonly property string spectrumConf: Quickshell.env("HOME") + "/.cache/angelos/cava-eq-" + spectrumKey + ".conf"
    readonly property string spectrumFifo: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-cava-eq-" + spectrumKey + ".fifo"
    property string spectrumWritten: ""
    property bool spectrumReady: false
    property bool spectrumUnavailable: false
    property double spectrumLastFrame: 0
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
    Accessible.onPressAction: panel.toggle()
    Keys.onReturnPressed: panel.toggle()
    Keys.onSpacePressed: panel.toggle()

    function send(line) {
        if (bridge.running) bridge.write(line + "\n");
    }
    function changeBand(index, gain) {
        if (!ready || !active) return;
        let next = levels.slice();
        next[index] = gain;
        levels = next;
        send("set " + index + " " + gain);
    }
    function triggerPulse() {
        if (Motion.still) return;
        sweep.stop();
        pulseProgress = 0;
        sweep.start();
    }
    function writeSpectrumConf() {
        if (!spectrumReady || !spectrumLive || spectrumUnavailable) return;
        const text = ["[general]", "bars = 10", "framerate = 20", "sensitivity = 70",
                      "autosens = 1", "[input]", "method = fifo", "source = " + spectrumFifo,
                      "sample_rate = 22050", "sample_bits = 16", "[output]", "method = raw",
                      "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 100",
                      "bar_delimiter = 59", "frame_delimiter = 10", "channels = mono",
                      "[smoothing]", "noise_reduction = 60", ""].join("\n");
        if (text === spectrumWritten) {
            audio.running = true;
        } else {
            spectrumWritten = text;
            spectrumFile.setText(text);
        }
    }
    Component.onCompleted: {
        spectrumReady = true;
        writeSpectrumConf();
    }
    onSpectrumLiveChanged: {
        if (spectrumLive) {
            writeSpectrumConf();
        } else {
            audio.running = false;
            spectrumRetry.stop();
            spectrumLevels = [];
        }
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
    FileView {
        id: spectrumFile
        path: root.spectrumConf
        preload: false
        atomicWrites: true
        onSaved: audio.running = root.spectrumLive
    }
    Process {
        id: audio
        command: ["python3", Quickshell.shellDir + "/scripts/audio-tap.py", "run",
                  "--conf", root.spectrumConf, "--fifo", root.spectrumFifo, ""]
        property string lastLine: ""
        property double startedAt: 0
        onStarted: {
            startedAt = Date.now();
            root.spectrumLastFrame = startedAt;
        }
        stdout: SplitParser {
            onRead: line => {
                root.spectrumLastFrame = Date.now();
                if (line === audio.lastLine) return;
                audio.lastLine = line;
                root.spectrumLevels = EqMotion.decodeSpectrum(line);
            }
        }
        onExited: code => {
            if (code === 127) {
                root.spectrumUnavailable = true;
            } else if (root.spectrumLive) {
                spectrumRetry.interval = Date.now() - startedAt > 15000
                    ? 2000 : Math.min(60000, spectrumRetry.interval * 2);
                spectrumRetry.start();
            }
        }
    }
    Timer {
        id: spectrumRetry
        interval: 2000
        onTriggered: audio.running = root.spectrumLive && !root.spectrumUnavailable
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.spectrumLive && !root.spectrumUnavailable
        onTriggered: {
            if (audio.running && Date.now() - root.spectrumLastFrame > 6000) {
                audio.running = false;
            } else if (!audio.running && !spectrumRetry.running && root.spectrumWritten !== "") {
                audio.running = true;
            }
        }
    }
    Process {
        id: bridge
        running: true
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/eq-bridge.py"]
        stdinEnabled: true
        onStarted: write("status\n")
        stdout: SplitParser {
            onRead: line => {
                let state;
                try { state = JSON.parse(line); } catch (e) { return; }
                root.ready = !!state.ready;
                root.error = state.error || "";
                if (state.ready) {
                    root.levels = state.gains;
                    root.frequencies = state.freqs;
                    root.active = state.enabled;
                    root.preset = state.preset || "";
                }
            }
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: panel.visible
        onTriggered: root.send("status")
    }

    PxBox {
        anchors.fill: parent
        sunken: panel.visible
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
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.toggle()
    }

    BarPopup {
        id: panel
        anchorItem: root
        above: root.above
        title: I18n.exe("eq") + "  /  EasyEffects"
        panelId: "equalizer"
        icon: "music"
        contentWidth: Theme.u * 236
        contentHeight: Theme.u * 195

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
                onClicked: root.send("toggle")
            }
            PxText {
                x: 0
                y: Theme.u * 15
                width: parent.width
                kind: "tiny"
                color: root.ready ? Theme.textDim : Theme.danger
                wrapMode: Text.WordWrap
                text: root.ready
                      ? I18n.t("ДВИГАЙ ПОЛОСЫ · ЗВУК МЕНЯЕТСЯ СРАЗУ", "DRAG BANDS · LIVE AUDIO")
                      : root.error || I18n.t("ПОДКЛЮЧАЮСЬ К ЗВУКУ…", "CONNECTING TO AUDIO…")
            }
            PxButton {
                visible: !root.ready
                y: Theme.u * 33
                compact: true
                accent: true
                text: I18n.t("ЗАПУСТИТЬ EQ", "START EQ")
                onClicked: root.send("start")
            }
            Row {
                id: presetRow
                visible: root.ready
                y: Theme.u * 33
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
                            root.send("preset " + modelData.id);
                        }
                    }
                }
            }
            Rectangle {
                id: display
                y: Theme.u * 53
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
                y: Theme.u * 113
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
                            root.changeBand(index, shown);
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
                                    root.changeBand(band.index, value);
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
                y: Theme.u * 184
                kind: "tiny"
                text: root.preset ? root.preset.toUpperCase() : I18n.t("СВОЙ ПРОФИЛЬ", "CUSTOM")
                color: root.active ? Theme.accent : Theme.textDim
            }
        }
    }
}
