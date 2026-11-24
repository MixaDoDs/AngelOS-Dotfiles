pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.serp
import "."

// serp-skin: the system monitor in Serpantinum's face (angelOS's modules/desktop/widgets/
// SysmonWidget: the same readers, paused while the desk is out of sight).
//   S  four little cards: CPU, GPU, RAM in %, the network ↓
//   M  four usage circles (CPU mauve, GPU blue, RAM peach, VRAM teal), the % in the middle,
//      the name and the temperature / size under; the network ↓ ↑ as two pills
//   L  bigger circles, the last minute of CPU and GPU in columns, the three busiest programs
//      (scripts/top-procs.py, running only while an L is on show) with a thin bar each
// In hell the roles are hell's colours and the names are HellLook's (Heat, Inferno, Souls…).
Item {
    // the usage ring (inline, as the pill bar)
    component SerpRing: Item {
        id: ringRoot
    
        property real value: 0
        property color color: Serp.accent
        property color track: Serp.surface1
        property real lineWidth: Serp.px(7)
        // off for readings that tick every 2 s (each glide kept the desk window drawing)
        property bool animate: false
        property real shown: Math.max(0, Math.min(1, value))
        Behavior on shown {
            enabled: ringRoot.animate
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }
    
        implicitWidth: Serp.px(64)
        implicitHeight: implicitWidth
        readonly property real r: (Math.min(width, height) - lineWidth) / 2
    
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: ringRoot.track
                strokeWidth: ringRoot.lineWidth
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: ringRoot.width / 2
                    centerY: ringRoot.height / 2
                    radiusX: ringRoot.r
                    radiusY: ringRoot.r
                    startAngle: 0
                    sweepAngle: 360
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: ringRoot.shown > 0.002 ? ringRoot.color : "transparent"
                strokeWidth: ringRoot.lineWidth
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ringRoot.width / 2
                    centerY: ringRoot.height / 2
                    radiusX: ringRoot.r
                    radiusY: ringRoot.r
                    startAngle: -90
                    sweepAngle: Math.max(0.5, ringRoot.shown * 359.9)
                }
            }
        }
    }

    // the pill bar (inline: loaded by URL from the desktop host, sibling files aren't types)
    component SerpPill: Rectangle {
        id: pillRoot
    
        property real value: 0
        property color fill: Serp.accent
        property bool animate: true
        property real shown: Math.max(0, Math.min(1, value))
        Behavior on shown {
            enabled: pillRoot.animate
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutCubic
            }
        }
    
        implicitHeight: Serp.px(8)
        radius: height / 2
        color: Serp.surface1
        Rectangle {
            visible: pillRoot.shown > 0.002
            width: Math.max(pillRoot.height, pillRoot.width * pillRoot.shown)
            height: pillRoot.height
            radius: pillRoot.radius
            color: pillRoot.fill
        }
    }

    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    readonly property bool passive: true     // nothing to click: no input copy needed
    // false: kept but nobody looks (the closed sidebar)
    property bool awake: true
    readonly property bool seen: visible && awake && !Shell.hiddenScreen(screenName)
    // the last minute (a reading every 2 s) of CPU and GPU, for L's columns
    readonly property int histLen: 30
    property var cpuHist: []
    property var gpuHist: []
    function pushHist(list, v) {
        const out = list.concat([Math.max(0, v)]);
        return out.length > histLen ? out.slice(out.length - histLen) : out;
    }
    // L: the three busiest programs
    property var busiest: []

    property real cpu: 0
    property real cpuTemp: -1
    property real ram: 0
    property string ramText: ""
    property real gpu: -1
    property real gpuTemp: -1
    property string vramText: ""
    property real rx: 0
    property real tx: 0
    property var _cpuLast: null
    property var _netLast: null
    property string cpuTempPath: ""

    implicitWidth: size === "s" ? sGrid.implicitWidth : col.implicitWidth
    implicitHeight: size === "s" ? sGrid.implicitHeight : col.implicitHeight

    function human(bps) {
        const k = bps / 1024;
        return k < 1024 ? k.toFixed(0) + " " + I18n.t("КБ/с", "KB/s") : (k / 1024).toFixed(1) + " " + I18n.t("МБ/с", "MB/s");
    }

    Timer {
        interval: 2000
        running: root.seen
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.size === "l") {
                root.cpuHist = root.pushHist(root.cpuHist, root.cpu);
                root.gpuHist = root.pushHist(root.gpuHist, root.gpu);
            }
            stat.reload();
            mem.reload();
            net.reload();
            if (root.cpuTempPath)
                temp.reload();
        }
    }
    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            if (root._cpuLast && total > root._cpuLast.t)
                root.cpu = 1 - (idle - root._cpuLast.i) / (total - root._cpuLast.t);
            root._cpuLast = {
                "t": total,
                "i": idle
            };
        }
    }
    FileView {
        id: mem
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const g = k => parseInt((t.match(new RegExp(k + ":\\s+(\\d+)")) || [0, 0])[1]);
            const total = g("MemTotal"), avail = g("MemAvailable");
            root.ram = 1 - avail / Math.max(1, total);
            root.ramText = ((total - avail) / 1048576).toFixed(1) + " / " + (total / 1048576).toFixed(0) + " " + I18n.t("ГБ", "GB");
        }
    }
    FileView {
        id: net
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const l of text().split("\n").slice(2)) {
                const m = l.trim().split(/[:\s]+/);
                if (!m[0] || m[0] === "lo" || m[0].startsWith("veth") || m[0].startsWith("docker"))
                    continue;
                rx += parseInt(m[1]) || 0;
                tx += parseInt(m[9]) || 0;
            }
            const now = Date.now();
            if (root._netLast) {
                const dt = (now - root._netLast.at) / 1000;
                root.rx = Math.max(0, (rx - root._netLast.rx) / dt);
                root.tx = Math.max(0, (tx - root._netLast.tx) / dt);
            }
            root._netLast = {
                "rx": rx,
                "tx": tx,
                "at": now
            };
        }
    }
    FileView {
        id: temp
        path: root.cpuTempPath
        printErrors: false
        onLoaded: root.cpuTemp = parseInt(text()) / 1000
    }
    // find the CPU sensor once (k10temp / coretemp / zenpower)
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in k10temp|coretemp|zenpower|cpu_thermal) echo $h/temp1_input; exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuTempPath = text.trim()
        }
    }
    Process {
        running: root.seen && root.size === "l"
        command: ["python3", Quickshell.shellDir + "/scripts/top-procs.py", "2", "3"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.busiest = JSON.parse(line);
                } catch (e) {}
            }
        }
    }
    Process {
        id: gpuProc
        // NVIDIA through nvidia-smi, AMD through amdgpu's sysfs; Intel's load stays "—".
        // One process while the widget is seen, a line every 2 s (a card that can't say ends it)
        running: root.seen
        command: ["sh", Quickshell.shellDir + "/scripts/gpu-stats.sh", "--watch", "2"]
        stdout: SplitParser {
            onRead: text => {
                const v = text.split(",").map(s => parseFloat(s));
                if (v.length >= 4 && !isNaN(v[0])) {
                    root.gpu = v[0] / 100;
                    root.gpuTemp = v[1];
                    if (v[3] > 0)
                        root.vramText = (v[2] / 1024).toFixed(1) + " / " + (v[3] / 1024).toFixed(0) + " " + I18n.t("ГБ", "GB");
                }
            }
        }
    }

    // ---- the readings ----
    // the Repeaters count these and their delegates read them by index: a model bound to the
    // readings themselves would rebuild every gauge on each new number (2 s)
    readonly property real vram: vramText ? parseFloat(vramText) / Math.max(1, parseFloat(vramText.split("/")[1])) : -1
    function pct(v) {
        return v < 0 ? "—" : Math.round(v * 100) + "%";
    }
    function deg(t) {
        return t > 0 ? Math.round(t) + "°C" : "";
    }
    readonly property var readings: [
        {
            "k": "CPU",
            "id": "cpu",
            "v": root.cpu,
            "d": root.deg(root.cpuTemp),
            "c": Serp.mauve
        },
        {
            "k": "GPU",
            "id": "gpu",
            "v": root.gpu,
            "d": root.deg(root.gpuTemp),
            "c": Serp.blue
        },
        {
            "k": I18n.t("ОЗУ", "RAM"),
            "id": "ram",
            "v": root.ram,
            "d": root.ramText,
            "c": Serp.peach
        },
        {
            "k": "VRAM",
            "id": "vram",
            "v": root.vram,
            "d": root.vramText,
            "c": Serp.teal
        }
    ]
    readonly property var sReadings: [root.readings[0], root.readings[1], root.readings[2], {
        "k": I18n.t("Сеть", "Net"),
        "id": "net",
        "big": "↓ " + root.human(root.rx).replace(/ .*/, ""),
        "c": Serp.green
    }]
    function labelOf(r) {
        // hell: the reading's plain name first, the circle's word after it (HellLook.label)
        return Theme.hell && r.id !== "net" ? HellLook.label(r.id, r.k) : r.k;
    }

    // ---- S: four little cards, two by two ----
    Grid {
        id: sGrid
        visible: root.size === "s"
        columns: 2
        columnSpacing: Serp.px(6)
        rowSpacing: Serp.px(6)
        Repeater {
            model: root.size === "s" ? root.sReadings.length : 0
            Rectangle {
                id: cell
                required property int index
                readonly property var modelData: root.sReadings[index]
                width: Serp.px(88)
                height: cellCol.implicitHeight + Serp.px(14)
                radius: Serp.radiusSmall
                color: Serp.surface0
                Column {
                    id: cellCol
                    x: Serp.px(9)
                    width: parent.width - Serp.px(18)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Serp.px(1)
                    SText {
                        width: parent.width
                        text: root.labelOf(cell.modelData)
                        size: Serp.smallSize
                        bold: true
                        color: Serp.subtext0
                    }
                    SText {
                        width: parent.width
                        text: cell.modelData.big || root.pct(cell.modelData.v)
                        size: Serp.px(20)
                        black: true
                        color: cell.modelData.c
                    }
                }
            }
        }
    }

    // ---- M and L ----
    Column {
        id: col
        visible: root.size !== "s"
        spacing: Serp.px(root.size === "l" ? 12 : 10)
        readonly property int ringD: Serp.px(root.size === "l" ? 76 : 64)
        readonly property int cellW: ringD + Serp.px(12)

        // the usage circles
        Row {
            id: rings
            spacing: Serp.px(6)
            Repeater {
                model: root.size !== "s" ? root.readings.length : 0
                Column {
                    id: gauge
                    required property int index
                    readonly property var modelData: root.readings[index]
                    width: col.cellW
                    spacing: Serp.px(2)
                    SerpRing {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: col.ringD
                        height: col.ringD
                        lineWidth: Serp.px(root.size === "l" ? 8 : 7)
                        value: gauge.modelData.v
                        color: gauge.modelData.c
                        SText {
                            anchors.centerIn: parent
                            text: root.pct(gauge.modelData.v)
                            size: Serp.px(root.size === "l" ? 16 : 14)
                            bold: true
                        }
                    }
                    Item {
                        width: 1
                        height: Serp.px(4)
                    }
                    SText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.labelOf(gauge.modelData)
                        size: Serp.smallSize
                        bold: true
                        color: Serp.subtext1
                    }
                    SText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: gauge.modelData.d || " "
                        size: Serp.px(10)
                        color: Serp.subtext0
                    }
                }
            }
        }

        // L: the last minute of CPU and GPU, a column every 2 s, the newest on the right
        Row {
            visible: root.size === "l"
            spacing: Serp.px(6)
            Repeater {
                model: root.size === "l" ? 2 : 0
                Rectangle {
                    id: histCard
                    required property int index
                    readonly property var r: root.readings[index]
                    readonly property var values: index === 1 ? root.gpuHist : root.cpuHist
                    width: (rings.width - Serp.px(6)) / 2
                    height: Serp.px(62)
                    radius: Serp.radiusSmall
                    color: Serp.surface0
                    SText {
                        x: Serp.px(8)
                        y: Serp.px(5)
                        text: root.labelOf(histCard.r)
                        size: Serp.px(10)
                        bold: true
                        color: Serp.subtext0
                    }
                    Item {
                        id: plot
                        anchors.fill: parent
                        anchors.margins: Serp.px(8)
                        anchors.topMargin: Serp.px(22)
                        readonly property real gap: Math.max(1, Serp.px(2))
                        readonly property real colW: (width - (root.histLen - 1) * gap) / root.histLen
                        Repeater {
                            model: histCard.values.length
                            Rectangle {
                                required property int index
                                readonly property real v: histCard.values[index] || 0
                                x: plot.width - (histCard.values.length - index) * (plot.colW + plot.gap) + plot.gap
                                width: plot.colW
                                // at least a dot, so a quiet minute still shows
                                height: Math.max(width, v * plot.height)
                                y: plot.height - height
                                radius: width / 2
                                color: Qt.alpha(histCard.r.c, 0.45 + v * 0.55)
                            }
                        }
                    }
                }
            }
        }

        // the network: ↓ and ↑ on two pills
        Row {
            spacing: Serp.px(6)
            Repeater {
                model: 2
                Rectangle {
                    id: netPill
                    required property int index
                    width: (rings.width - Serp.px(6)) / 2
                    height: netRow.implicitHeight + Serp.px(10)
                    radius: height / 2
                    color: Serp.surface0
                    Row {
                        id: netRow
                        anchors.centerIn: parent
                        spacing: Serp.px(6)
                        SText {
                            text: netPill.index === 0 ? "↓" : "↑"
                            size: Serp.px(13)
                            black: true
                            color: netPill.index === 0 ? Serp.green : Serp.blue
                        }
                        SText {
                            text: root.human(netPill.index === 0 ? root.rx : root.tx)
                            size: Serp.px(12)
                            bold: true
                            color: Serp.text
                        }
                    }
                }
            }
        }

        // L: the three busiest programs, a thin bar each
        Column {
            visible: root.size === "l"
            width: rings.width
            spacing: Serp.px(6)
            Repeater {
                model: root.size === "l" ? root.busiest : []
                Column {
                    id: proc
                    required property var modelData
                    required property int index
                    width: rings.width
                    spacing: Serp.px(3)
                    Row {
                        width: parent.width
                        SText {
                            width: parent.width * 0.75
                            text: (proc.index + 1) + ". " + proc.modelData.name
                            size: Serp.px(12)
                            bold: true
                        }
                        SText {
                            width: parent.width * 0.25
                            horizontalAlignment: Text.AlignRight
                            text: (proc.modelData.cpu >= 10 ? Math.round(proc.modelData.cpu) : proc.modelData.cpu.toFixed(1)) + "%"
                            size: Serp.px(12)
                            color: Serp.subtext0
                        }
                    }
                    SerpPill {
                        width: parent.width
                        height: Serp.px(4)
                        animate: false
                        value: proc.modelData.cpu / 100
                        fill: Serp.mauve
                    }
                }
            }
            SText {
                visible: root.busiest.length === 0
                text: I18n.t("считаю, кто занят…", "seeing who is busy…")
                size: Serp.smallSize
                color: Serp.subtext0
            }
        }
    }
}
