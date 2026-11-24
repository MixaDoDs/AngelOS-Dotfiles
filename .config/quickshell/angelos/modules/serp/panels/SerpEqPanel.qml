pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.serp

// serp-skin: angelOS's equalizer (services/Eq: EasyEffects through scripts/eq-bridge.py, the same
// one the classic bar's EQ face drives) in Serpantinum's look — Serpantinum's music popup has its
// 10 vertical bands too. On / off, the presets, the ten bands (−12…+12 dB, drag or wheel, half a
// dB a step) over the live spectrum, and the route: the sound through the EQ or straight.
Item {
    id: root
    property string screenName: ""
    property real progress: 1
    function st(d) {
        return Math.max(0, Math.min(1, (progress - d) / Math.max(0.01, 1 - d)));
    }

    // counted in while shown, as the classic face does: the bridge and the spectrum run for us
    Component.onCompleted: {
        Eq.watchers++;
        Eq.viewers++;
        Eq.send("status");
        Eq.send("sources");
    }
    Component.onDestruction: {
        Eq.watchers--;
        Eq.viewers--;
    }

    readonly property var presets: [
        {
            "id": "flat",
            "label": "Ровно"
        },
        {
            "id": "bass",
            "label": "Бас"
        },
        {
            "id": "voice",
            "label": "Голос"
        },
        {
            "id": "air",
            "label": "Воздух"
        },
        {
            "id": "soft",
            "label": "Мягко"
        }
    ]
    function hz(f) {
        return f >= 1000 ? (f / 1000) + "k" : String(f);
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Serp.radius * 1.4, 24)
        color: Serp.ground
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Serp.px(16)
        spacing: Serp.px(12)

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Serp.px(10)
            opacity: root.st(0)
            Rectangle {
                Layout.preferredWidth: Serp.px(34)
                Layout.preferredHeight: Serp.px(34)
                radius: Serp.radiusSmall
                color: Eq.active ? Serp.accent : Serp.surface0
                SIcon {
                    anchors.centerIn: parent
                    name: "activity"
                    color: Eq.active ? Serp.onAccent : Serp.subtext0
                }
            }
            Column {
                Layout.fillWidth: true
                SText {
                    text: "Эквалайзер"
                    size: Serp.px(16)
                    black: true
                }
                SText {
                    width: parent.width
                    text: !Eq.ready ? (Eq.error || "EasyEffects не запущен") : Eq.routeActive ? "звук идёт через EQ" + (Eq.routedApp ? " · " + Eq.routedApp : "") : "EasyEffects · звук идёт напрямую"
                    size: Serp.px(10.5)
                    dim: true
                }
            }
            SToggle {
                visible: Eq.ready
                checked: Eq.active
                onToggled: Eq.send("toggle")
            }
        }

        // ---- not running: start it ----
        SButton {
            visible: !Eq.ready
            Layout.alignment: Qt.AlignHCenter
            flat: false
            ground: Serp.accent
            implicitHeight: Serp.px(32)
            padH: Serp.px(14)
            SText {
                text: "Запустить EQ"
                size: Serp.px(12)
                bold: true
                color: Serp.onAccent
            }
            onClicked: Eq.send("start")
        }

        // ---- presets ----
        Row {
            visible: Eq.ready
            Layout.fillWidth: true
            spacing: Serp.px(6)
            opacity: root.st(0.08) * (Eq.active ? 1 : 0.45)
            Repeater {
                model: root.presets
                Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: Eq.preset === modelData.id
                    width: (parent.width - Serp.px(6) * 4) / 5
                    height: Serp.px(28)
                    radius: Serp.radiusSmall
                    color: on ? Serp.accent : cma.containsMouse ? Serp.surface1 : Serp.surface0
                    scale: cma.pressed ? 0.95 : 1
                    Behavior on color {
                        ColorAnimation {
                            duration: Serp.quick
                        }
                    }
                    SText {
                        anchors.centerIn: parent
                        text: chip.modelData.label
                        size: Serp.px(11)
                        bold: true
                        color: chip.on ? Serp.onAccent : Serp.text
                    }
                    MouseArea {
                        id: cma
                        anchors.fill: parent
                        enabled: Eq.active
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Eq.send("preset " + chip.modelData.id)
                    }
                }
            }
        }

        // ---- the ten bands over the spectrum ----
        SCard {
            visible: Eq.ready
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: root.st(0.16)
            // the spectrum behind each band (what goes through EasyEffects, or everything playing):
            // a thin soft bar under every slider, not blocks
            Row {
                anchors.fill: parent
                anchors.margins: Serp.px(10)
                anchors.bottomMargin: Serp.px(28)
                Repeater {
                    model: 10
                    Item {
                        required property int index
                        readonly property var lv: Eq.spectrumLevels || []
                        // the spectrum's bins folded onto the ten bands
                        readonly property real v: {
                            if (!lv.length)
                                return 0;
                            const per = lv.length / 10, from = Math.floor(index * per), to = Math.max(from + 1, Math.floor((index + 1) * per));
                            let m = 0;
                            for (let i = from; i < to && i < lv.length; i++)
                                m = Math.max(m, lv[i] || 0);
                            return Math.min(1, m);
                        }
                        width: parent.width / 10
                        height: parent.height
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: Serp.px(18)
                            height: Math.max(0, parent.height * 0.8 * parent.v)
                            radius: Serp.px(6)
                            color: Qt.alpha(Serp.accent, 0.10)
                            Behavior on height {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                    }
                }
            }
            // 0 dB
            Rectangle {
                x: Serp.px(10)
                width: parent.width - Serp.px(20)
                y: bands.y + bands.railTop + bands.railH / 2
                height: 1
                color: Serp.line
            }
            Row {
                id: bands
                anchors.fill: parent
                anchors.margins: Serp.px(10)
                readonly property real railTop: Serp.px(8)
                readonly property real railH: height - railTop - Serp.px(26)
                Repeater {
                    model: 10
                    Item {
                        id: band
                        required property int index
                        width: bands.width / 10
                        height: bands.height
                        property real gain: Eq.levels[index] || 0
                        property real shown: gain
                        onGainChanged: if (!bma.pressed)
                            shown = gain
                        function set(v) {
                            v = Math.max(-12, Math.min(12, Math.round(v * 2) / 2));
                            if (v !== shown) {
                                shown = v;
                                Eq.changeBand(index, v);
                            }
                        }
                        readonly property real knobY: bands.railTop + (12 - shown) / 24 * bands.railH
                        // the rail, filled from 0 dB to the gain
                        Rectangle {
                            id: rail
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: bands.railTop
                            width: Serp.px(10)
                            height: bands.railH
                            radius: width / 2
                            color: Serp.surface1
                            Rectangle {
                                width: parent.width
                                radius: width / 2
                                readonly property real zero: bands.railH / 2
                                readonly property real k: band.knobY - bands.railTop
                                y: Math.min(zero, k)
                                height: Math.max(width, Math.abs(zero - k))
                                color: Eq.active ? Serp.accent : Serp.surface2
                            }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: band.knobY - height / 2
                            width: Serp.px(18)
                            height: width
                            radius: width / 2
                            color: Serp.text
                            border.width: Serp.px(3)
                            border.color: Eq.active ? Serp.accent : Serp.surface2
                            scale: bma.pressed ? 1.15 : bma.containsMouse ? 1.08 : 1
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Serp.quick
                                }
                            }
                            Behavior on y {
                                enabled: !bma.pressed
                                NumberAnimation {
                                    duration: Serp.normal
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        SText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: bma.pressed || bma.containsMouse ? (band.shown > 0 ? "+" : "") + band.shown : root.hz(Eq.frequencies[band.index])
                            size: Serp.px(9.5)
                            color: bma.pressed || bma.containsMouse ? Serp.accent : Serp.subtext0
                        }
                        MouseArea {
                            id: bma
                            anchors.fill: parent
                            enabled: Eq.active
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor
                            onPressed: m => band.set(12 - (m.y - bands.railTop) * 24 / bands.railH)
                            onPositionChanged: m => {
                                if (pressed)
                                    band.set(12 - (m.y - bands.railTop) * 24 / bands.railH);
                            }
                            onWheel: w => band.set(band.shown + (w.angleDelta.y > 0 ? 0.5 : -0.5))
                        }
                    }
                }
            }
        }

        // ---- which app goes through it, and to which output ----
        SChoice {
            visible: Eq.ready
            Layout.fillWidth: true
            opacity: root.st(0.2)
            title: "Приложение"
            icon: "music"
            model: Eq.sourceChoices
            value: Eq.selectedSource
            placeholder: "нет активного звука"
            onActivated: v => {
                Eq.selectedSource = v;
                Eq.routingError = "";
                if (!Eq.outputExplicit) {
                    const preferred = Eq.defaultOutputFor(v);
                    if (preferred)
                        Eq.selectedOutput = preferred;
                }
            }
        }
        SChoice {
            visible: Eq.ready
            Layout.fillWidth: true
            opacity: root.st(0.22)
            title: Eq.rode ? "RØDE" : "Выход"
            icon: "volume-2"
            model: Eq.outputChoices
            value: Eq.selectedOutput
            placeholder: "устройство"
            onActivated: v => {
                Eq.selectedOutput = v;
                Eq.outputExplicit = true;
                Eq.routingError = "";
            }
        }
        SText {
            visible: Eq.routingError !== ""
            Layout.fillWidth: true
            text: Eq.routingError
            size: Serp.px(10.5)
            color: Serp.red
            wrapMode: Text.Wrap
        }

        // ---- the route ----
        RowLayout {
            visible: Eq.ready
            Layout.fillWidth: true
            spacing: Serp.px(6)
            opacity: root.st(0.24)
            component RouteBtn: SButton {
                id: rbtn
                property string label
                property bool on: false
                Layout.fillWidth: true
                flat: false
                ground: on ? Serp.selected : Serp.surface0
                implicitHeight: Serp.px(30)
                SText {
                    text: rbtn.label
                    size: Serp.px(11)
                    bold: rbtn.on
                    color: rbtn.on ? Serp.accent : Serp.text
                }
            }
            RouteBtn {
                label: "Через EQ"
                on: Eq.routeActive
                enabled: !!Eq.selectedSource && !!Eq.selectedOutput
                opacity: enabled ? 1 : 0.4
                onClicked: Eq.routeCommand("route")
            }
            RouteBtn {
                label: "Напрямую"
                on: !Eq.routeActive
                enabled: !!Eq.selectedSource && !!Eq.selectedOutput
                opacity: enabled ? 1 : 0.4
                onClicked: Eq.routeCommand("direct")
            }
            RouteBtn {
                visible: Eq.routeActive
                label: "Вернуть"
                onClicked: Eq.releaseRoute()
            }
        }
    }
}
