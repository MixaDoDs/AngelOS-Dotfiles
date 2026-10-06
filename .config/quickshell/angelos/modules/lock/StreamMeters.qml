pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// The stats of NEEDY GIRL OVERDOSE on the lock's stream, from the real machine:
//   followers  everyone who ever stayed (services/LockStream, grows with the days)
//   stress     the processor's load, how long the computer has been on, the mistakes
//   affection  the days with angelOS (full by day 30)
//   darkness   the night, the mistakes, the minutes away
PxWindow {
    id: root

    required property var stream
    signal changed(int stress, int dark)

    property int cpus: 1
    property real load: 0
    property int stress: 0
    property int affection: 0
    property int darkness: 0

    title: I18n.exe("stats")
    icon: "gauge"
    compact: true
    closable: false
    height: titleHeight + col.implicitHeight + Theme.pad * 2 + Theme.u * 6

    Process {
        running: true
        command: ["nproc"]
        stdout: StdioCollector {
            onStreamFinished: root.cpus = Math.max(1, parseInt(text) || 1)
        }
    }
    FileView {
        id: loadavg
        path: "/proc/loadavg"
        printErrors: false
    }
    FileView {
        id: uptime
        path: "/proc/uptime"
        printErrors: false
    }
    function update() {
        loadavg.reload();
        uptime.reload();
        load = parseFloat(String(loadavg.text() || "0").split(" ")[0]) || 0;
        const upH = (parseFloat(String(uptime.text() || "0").split(" ")[0]) || 0) / 3600;
        const fails = stream.lockScope.fails || 0;
        const h = new Date().getHours();
        const clamp = v => Math.max(0, Math.min(100, Math.round(v)));
        stress = clamp(load / cpus * 70 + Math.min(25, upH * 2) + fails * 9);
        affection = clamp(LockStream.days * 3.4 + LockStream.streak);
        darkness = clamp((h < 5 ? 60 : h >= 22 ? 45 : h < 7 ? 30 : 10) + fails * 6 + stream.elapsed / 60);
        changed(stress, darkness);
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.update()
    }
    Connections {
        target: root.stream.lockScope
        function onShake() {
            root.update();
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.u * 4
        Repeater {
            model: [
                {
                    "icon": "heart",
                    "label": I18n.t("Подписчики", "Followers"),
                    "value": -1,
                    "fill": Theme.accent
                },
                {
                    "icon": "fire",
                    "label": I18n.t("Стресс", "Stress"),
                    "value": root.stress,
                    "fill": Theme.danger
                },
                {
                    "icon": "heart",
                    "label": I18n.t("Привязанность", "Affection"),
                    "value": root.affection,
                    "fill": Theme.accent2
                },
                {
                    "icon": "moon",
                    "label": I18n.t("Тьма", "Darkness"),
                    "value": root.darkness,
                    "fill": Theme.mix(Theme.edge, Theme.accent2, 0.45)
                }
            ]
            Column {
                id: meter
                required property var modelData
                width: col.width
                spacing: Theme.u * 2
                Row {
                    width: parent.width
                    spacing: Theme.u * 3
                    PxIcon {
                        name: meter.modelData.icon
                        fill: meter.modelData.fill
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PxText {
                        text: meter.modelData.label
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                // followers: a number that counts up; the rest: ten cells and the value
                PxText {
                    visible: meter.modelData.value < 0
                    text: LockStream.followers.toLocaleString(Qt.locale(), "f", 0)
                    kind: "title"
                    color: Theme.accent
                    font.bold: true
                }
                Row {
                    visible: meter.modelData.value >= 0
                    spacing: Theme.u
                    Repeater {
                        model: 10
                        Rectangle {
                            required property int index
                            width: Theme.u * 7
                            height: Theme.u * 6
                            color: index < Math.round(meter.modelData.value / 10) ? meter.modelData.fill : Theme.sunken
                            border.width: Math.max(1, Theme.u / 2)
                            border.color: Theme.edge
                        }
                    }
                    PxText {
                        text: " " + meter.modelData.value
                        kind: "tiny"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
