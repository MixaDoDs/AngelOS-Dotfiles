pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// CPU / GPU / RAM / temperatures / network (paused while the desk is out of sight: locked or
// under a fullscreen window):
//   S  four numbers in a little grid
//   M  pixel meters
//   L  the meters, the last minute of CPU and GPU in columns, the three busiest programs
//      (scripts/top-procs.py, running only while an L is on show)
// In hell (Theme.realm) the same numbers as Heat, Inferno, Souls and Cauldron, in meters of fire.
// macOS look (DesktopWidgets.macLook): four rings with the load in the middle, the network
// on a line of its own under them.
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    readonly property bool passive: true     // nothing to click: no input copy needed
    readonly property bool seen: visible && !Shell.hiddenScreen(screenName)
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

    readonly property bool mac: DesktopWidgets.macLook
    implicitWidth: mac ? macCol.implicitWidth : size === "s" ? sGrid.implicitWidth : Theme.u * (size === "l" ? 150 : 130)
    implicitHeight: mac ? macCol.implicitHeight : size === "s" ? sGrid.implicitHeight : col.implicitHeight

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
            if (!gpuProc.running)
                gpuProc.running = true;
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
        running: root.seen && root.size === "l" && !root.mac
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
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.split(",").map(s => parseFloat(s));
                if (v.length >= 4 && !isNaN(v[0])) {
                    root.gpu = v[0] / 100;
                    root.gpuTemp = v[1];
                    root.vramText = (v[2] / 1024).toFixed(1) + " / " + (v[3] / 1024).toFixed(0) + " " + I18n.t("ГБ", "GB");
                }
            }
        }
    }

    // ---- macOS look ----
    readonly property real vram: vramText ? parseFloat(vramText) / Math.max(1, parseFloat(vramText.split("/")[1])) : -1
    function pct(v) {
        return v < 0 ? "—" : Math.round(v * 100) + "%";
    }
    function deg(t) {
        return t > 0 ? Math.round(t) + "°C" : "";
    }
    Column {
        id: macCol
        visible: root.mac
        spacing: DesktopWidgets.mpx(12)
        Row {
            spacing: DesktopWidgets.mpx(10)
            Repeater {
                model: [
                    {
                        "k": "CPU",
                        "v": root.cpu,
                        "d": root.deg(root.cpuTemp)
                    },
                    {
                        "k": "GPU",
                        "v": root.gpu,
                        "d": root.deg(root.gpuTemp)
                    },
                    {
                        "k": I18n.t("ОЗУ", "RAM"),
                        "v": root.ram,
                        "d": root.ramText
                    },
                    {
                        "k": "VRAM",
                        "v": root.vram,
                        "d": root.vramText
                    }
                ]
                Column {
                    id: gauge
                    required property var modelData
                    required property int index
                    width: DesktopWidgets.mpx(72)
                    spacing: DesktopWidgets.mpx(2)
                    MacRing {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: DesktopWidgets.mpx(60)
                        height: width
                        lineWidth: DesktopWidgets.mpx(7)
                        value: gauge.modelData.v
                        color: DesktopWidgets.macColors[gauge.index]
                        MacWidgetText {
                            anchors.centerIn: parent
                            text: root.pct(gauge.modelData.v)
                            size: 13
                            weight: Font.DemiBold
                        }
                    }
                    Item {
                        width: 1
                        height: DesktopWidgets.mpx(4)
                    }
                    MacWidgetText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: gauge.modelData.k
                        size: 11
                        weight: Font.DemiBold
                        role: "secondary"
                    }
                    MacWidgetText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: gauge.modelData.d || " "
                        size: 11
                        role: "tertiary"
                    }
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            color: DesktopWidgets.macSeparator
        }
        Row {
            width: parent.width
            MacWidgetText {
                width: parent.width * 0.3
                text: I18n.t("Сеть", "Network")
                size: 12
                weight: Font.DemiBold
                role: "secondary"
            }
            MacWidgetText {
                width: parent.width * 0.35
                horizontalAlignment: Text.AlignRight
                text: "↓ " + root.human(root.rx)
                size: 12
                weight: Font.Medium
            }
            MacWidgetText {
                width: parent.width * 0.35
                horizontalAlignment: Text.AlignRight
                text: "↑ " + root.human(root.tx)
                size: 12
                weight: Font.Medium
            }
        }
    }

    // ---- pixel and hell ----
    function vramOf() {
        return root.vramText ? parseFloat(root.vramText) / Math.max(1, parseFloat(root.vramText.split("/")[1])) : 0;
    }
    readonly property var readings: [
        {
            "k": "CPU",
            "id": "cpu",
            "v": root.cpu,
            "t": Math.round(root.cpu * 100) + "%" + (root.cpuTemp > 0 ? "  " + Math.round(root.cpuTemp) + "°" : ""),
            "c": Theme.accent,
            "hist": "cpu"
        },
        {
            "k": "GPU",
            "id": "gpu",
            "v": Math.max(0, root.gpu),
            "t": root.gpu < 0 ? "—" : Math.round(root.gpu * 100) + "%" + (root.gpuTemp > 0 ? "  " + Math.round(root.gpuTemp) + "°" : ""),
            "c": Theme.accent2,
            "hist": "gpu"
        },
        {
            "k": "RAM",
            "id": "ram",
            "v": root.ram,
            "t": root.ramText,
            "c": Theme.accent4
        },
        {
            "k": "VRAM",
            "id": "vram",
            "v": root.vramOf(),
            "t": root.vramText || "—",
            "c": Theme.accent3
        }
    ]
    readonly property string labelFont: Theme.hell ? Theme.fontHellText : Theme.fontBody
    readonly property int labelPx: Theme.hell ? Theme.hellTextPx(Theme.fs) : Theme.sizeBody
    function labelOf(r) {
        // hell: the reading's plain name first, the circle's word after it (HellLook.label)
        return Theme.hell ? HellLook.label(r.id, r.k) : r.k;
    }

    // S: four numbers, two by two
    Grid {
        id: sGrid
        visible: !root.mac && root.size === "s"
        columns: 2
        columnSpacing: Theme.u * 6
        rowSpacing: Theme.u * 2
        Repeater {
            model: [root.readings[0], root.readings[1], root.readings[2], {
                    "k": I18n.t("Сеть", "Net"),
                    "id": "net",
                    "big": "↓ " + root.human(root.rx).replace(/ .*/, ""),
                    "c": Theme.ok
                }]
            Column {
                id: cell
                required property var modelData
                spacing: 0
                PxText {
                    text: Theme.hell && cell.modelData.id !== "net" ? root.labelOf(cell.modelData) : cell.modelData.k
                    kind: "tiny"
                    font.family: root.labelFont
                    color: Theme.hell ? Theme.hellTextDim : Theme.textDim
                }
                PxText {
                    text: cell.modelData.big || (cell.modelData.id === "gpu" && root.gpu < 0 ? "—" : Math.round(cell.modelData.v * 100) + "%")
                    font.family: Theme.hell ? Theme.fontHellText : Theme.fontTitle
                    font.pixelSize: Theme.hell ? Theme.hellTextPx(Theme.fs * 1.6) : Theme.fontPx(20, Theme.fontTitle)
                    color: Theme.hell ? Theme.hellText : cell.modelData.c
                }
            }
        }
    }

    // M and L: the meters (L: the last minute under CPU and GPU, the busiest programs at the end)
    Column {
        id: col
        visible: !root.mac && root.size !== "s"
        width: parent.width
        spacing: Theme.u * 3

        Repeater {
            model: root.readings
            Column {
                id: r
                required property var modelData
                width: col.width
                spacing: Theme.u
                Row {
                    width: parent.width
                    PxText {
                        width: parent.width / 2
                        text: root.labelOf(r.modelData)
                        font.bold: !Theme.hell
                        font.family: root.labelFont
                        font.pixelSize: root.labelPx
                        color: Theme.hell ? Theme.hellTextDim : Theme.text
                        elide: Text.ElideRight
                    }
                    PxText {
                        width: parent.width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: r.modelData.t
                        font.family: root.labelFont
                        font.pixelSize: root.labelPx
                        color: Theme.hell ? Theme.hellText : Theme.textDim
                    }
                }
                PxBox {
                    width: parent.width
                    height: Theme.u * 6
                    sunken: true
                    hell: Theme.hell
                    color: Theme.hell ? Theme.hellSunken : Theme.sunken
                    Row {
                        anchors.fill: parent
                        spacing: Math.max(1, Theme.u / 2)
                        Repeater {
                            model: 16
                            Rectangle {
                                required property int index
                                readonly property bool lit: index < Math.round(r.modelData.v * 16)
                                width: parent ? (parent.width - 15 * parent.spacing) / 16 : 0
                                height: parent ? parent.height : 0
                                // hell: dried blood along the meter; past 80 % its last block is the one accent
                                color: !lit ? "transparent" : !Theme.hell ? r.modelData.c : index === Math.round(r.modelData.v * 16) - 1 && r.modelData.v > 0.8 ? Theme.hellAccent : Theme.hellBlood
                            }
                        }
                    }
                }
                // L: the last minute, a column every 2 s, the newest on the right
                Item {
                    id: hist
                    visible: root.size === "l" && !!r.modelData.hist
                    readonly property var values: r.modelData.hist === "gpu" ? root.gpuHist : root.cpuHist
                    readonly property real colW: (width - (root.histLen - 1) * Math.max(1, Theme.u / 2)) / root.histLen
                    width: parent.width
                    height: visible ? Theme.u * 10 : 0
                    Repeater {
                        model: hist.visible ? hist.values.length : 0
                        Rectangle {
                            required property int index
                            readonly property real v: hist.values[index] || 0
                            x: hist.width - (hist.values.length - index) * (hist.colW + Math.max(1, Theme.u / 2)) + Math.max(1, Theme.u / 2)
                            width: hist.colW
                            // whole art pixels, at least one so a quiet minute still shows
                            height: Math.max(Theme.u, Math.round(v * hist.height / Theme.u) * Theme.u)
                            y: hist.height - height
                            color: Theme.hell ? (v > 0.8 ? Theme.hellAccent : Theme.hellBlood) : Qt.alpha(r.modelData.c, 0.45 + v * 0.55)
                        }
                    }
                }
            }
        }
        Row {
            spacing: Theme.u * 6
            PxText {
                text: "↓ " + root.human(root.rx)
                font.family: root.labelFont
                font.pixelSize: root.labelPx
                color: Theme.hell ? Theme.hellTextDim : Theme.ok
            }
            PxText {
                text: "↑ " + root.human(root.tx)
                font.family: root.labelFont
                font.pixelSize: root.labelPx
                color: Theme.hell ? Theme.hellTextDim : Theme.accent2
            }
        }
        // L: the three busiest programs
        Rectangle {
            visible: root.size === "l"
            width: parent.width
            height: Math.max(1, Theme.u / 2)
            color: Theme.hell ? Theme.hellRim : Qt.alpha(Theme.text, 0.2)
        }
        Repeater {
            model: root.size === "l" ? root.busiest : []
            Row {
                id: proc
                required property var modelData
                required property int index
                width: col.width
                PxText {
                    width: parent.width * 0.7
                    text: (proc.index + 1) + ". " + proc.modelData.name
                    elide: Text.ElideRight
                    font.family: root.labelFont
                    font.pixelSize: root.labelPx
                    color: Theme.hell ? Theme.hellText : Theme.text
                }
                PxText {
                    width: parent.width * 0.3
                    horizontalAlignment: Text.AlignRight
                    text: (proc.modelData.cpu >= 10 ? Math.round(proc.modelData.cpu) : proc.modelData.cpu.toFixed(1)) + "%"
                    font.family: root.labelFont
                    font.pixelSize: root.labelPx
                    color: Theme.hell ? Theme.hellTextDim : Theme.textDim
                }
            }
        }
        PxText {
            visible: root.size === "l" && root.busiest.length === 0
            text: I18n.t("считаю, кто занят…", "seeing who is busy…")
            kind: "tiny"
            font.family: root.labelFont
            color: Theme.hell ? Theme.hellTextDim : Theme.textDim
        }
    }
}
