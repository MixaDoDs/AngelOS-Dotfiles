pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// Pixel spectrum from cava (raw ASCII output). Sound comes through
// scripts/audio-tap.py: pw-record of an output's monitor, a whole multichannel
// interface or one channel pair → FIFO → cava. cava's own `source = <sink>`
// silently fell back to the default *input*, i.e. the microphone.
// In hell (Theme.realm) the bars are dried blood; a loud one's top block is the one accent.
// cava and the tap stop while nobody can see the desk (locked, fullscreen game),
// and run only in a copy that is shown: the widget's face (DesktopWidgetHost) —
// its hidden input copy would share the FIFO and the config. A watchdog restarts a
// cava that stopped printing frames (B4).
// macOS look (DesktopWidgets.macLook): round-capped capsules in the theme's two accents.
Item {
    id: root

    property string screenName
    property var widget
    readonly property bool passive: true     // nothing to click: no input copy needed
    readonly property bool paused: Shell.hiddenScreen(screenName)
    readonly property bool live: visible && !paused
    onLiveChanged: {
        if (!live) {
            restart.stop();
            proc.running = false;
            levels = [];
        } else {
            writeConf();
        }
    }
    readonly property int bars: widget && widget.settings && widget.settings.bars ? widget.settings.bars : 32
    // "" = everything the computer plays (see audio-tap.py for the other specs)
    readonly property string source: widget && widget.settings && widget.settings.source ? widget.settings.source : ""
    property var levels: []
    property bool missing: false
    readonly property string conf: Quickshell.env("HOME") + "/.cache/angelos/cava-" + (widget ? widget.uid : "x") + ".conf"
    readonly property string fifo: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-cava-" + (widget ? widget.uid : "x") + ".fifo"

    readonly property bool mac: DesktopWidgets.macLook
    readonly property int macBar: DesktopWidgets.mpx(bars > 40 ? 4 : 5)
    readonly property int macGap: DesktopWidgets.mpx(3)
    implicitWidth: mac ? bars * (macBar + macGap) - macGap : Theme.u * 6 * bars / 2 + Theme.u * 4
    implicitHeight: mac ? DesktopWidgets.mpx(88) : Theme.u * 44

    FileView {
        id: confFile
        path: root.conf
        preload: false
        atomicWrites: true
        onSaved: proc.running = root.live
    }
    property bool ready: false
    property string written: ""
    function writeConf() {
        if (!ready || !live)
            return;
        proc.running = false;
        const text = ["[general]", "bars = " + bars, "framerate = 30", "sensitivity = 70", "autosens = 1", "[input]", "method = fifo", "source = " + root.fifo, "sample_rate = 22050", "sample_bits = 16", "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 100", "bar_delimiter = 59", "frame_delimiter = 10", "channels = mono", "[smoothing]", "noise_reduction = 60", ""].join("\n");
        // the same text again (back from the lock, sleep, a fullscreen game): FileView writes
        // nothing and sends no `saved`, so cava never came back (B4) — start it right away
        if (text === written) {
            proc.running = true;
            return;
        }
        written = text;
        confFile.setText(text);
    }
    Component.onCompleted: {
        ready = true;
        writeConf();
    }
    onBarsChanged: writeConf()
    onSourceChanged: writeConf()

    property double lastFrame: 0
    property int starts: 0                   // the self-test counts them
    Process {
        id: proc
        command: ["python3", Quickshell.shellDir + "/scripts/audio-tap.py", "run", "--conf", root.conf, "--fifo", root.fifo, root.source]
        onStarted: {
            root.starts++;
            root.lastFrame = Date.now();
        }
        stdout: SplitParser {
            onRead: line => {
                root.lastFrame = Date.now();
                root.levels = line.split(";").filter(s => s !== "").map(n => parseInt(n) / 100);
            }
        }
        onExited: code => {
            if (code === 127)
                root.missing = true;
            else if (root.live)
                restart.start();
        }
    }
    Timer {
        id: restart
        interval: 2000
        onTriggered: proc.running = root.live
    }
    // the watchdog: a running cava prints 30 frames a second, silence included — 6 s without
    // one is a hang (a stuck tap, a stuck cava): start over. And whatever path forgot to
    // start it while the desk is shown, this does
    readonly property int stallMs: 6000
    Timer {
        interval: 2000
        repeat: true
        running: root.live && !root.missing
        onTriggered: {
            if (proc.running && Date.now() - root.lastFrame > root.stallMs) {
                console.warn("cava widget " + (root.widget ? root.widget.uid : "") + ": no frames for " + Math.round((Date.now() - root.lastFrame) / 1000) + " s, restarting");
                proc.running = false;
            } else if (!proc.running && !restart.running && root.written !== "") {
                proc.running = true;
            }
        }
    }

    PxText {
        visible: root.missing && !root.mac
        anchors.centerIn: parent
        text: I18n.t("нужен cava: sudo pacman -S cava", "needs cava: sudo pacman -S cava")
        dim: true
    }

    // ---- macOS look ----
    MacWidgetText {
        visible: root.missing && root.mac
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: I18n.t("Нужен cava: sudo pacman -S cava", "Needs cava: sudo pacman -S cava")
        role: "secondary"
    }
    Row {
        visible: root.mac && !root.missing
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.macGap
        Repeater {
            model: root.mac ? root.bars : 0
            Item {
                id: capsule
                required property int index
                width: root.macBar
                height: root.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(width, (root.levels[capsule.index] || 0) * parent.height)
                    radius: width / 2
                    antialiasing: true
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: DesktopWidgets.macColors[0]
                        }
                        GradientStop {
                            position: 1
                            color: DesktopWidgets.macColors[1]
                        }
                    }
                    opacity: (root.levels[capsule.index] || 0) > 0.01 ? 1 : 0.35
                }
            }
        }
    }

    Row {
        visible: !root.mac
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.u
        Repeater {
            model: root.mac ? 0 : root.bars
            Item {
                id: bar
                required property int index
                readonly property real v: root.levels[index] || 0
                width: Theme.u * 2
                height: root.height
                // stacked pixel blocks, pink at the bottom fading to cyan at the top
                Column {
                    id: stack
                    readonly property int count: Math.round(bar.v * 14)
                    anchors.bottom: parent.bottom
                    spacing: Math.max(1, Theme.u / 2)
                    Repeater {
                        model: stack.count
                        Rectangle {
                            required property int index
                            // the Column stacks downwards: the first block is the top one
                            readonly property int level: stack.count - 1 - index
                            width: bar.width
                            height: Theme.u * 2
                            color: !Theme.hell ? Theme.mix(Theme.accent2, Theme.accent, (index + 1) / 14) : index === 0 && stack.count > 9 ? Theme.hellAccent : Theme.hellBlood
                        }
                    }
                }
            }
        }
    }
}
