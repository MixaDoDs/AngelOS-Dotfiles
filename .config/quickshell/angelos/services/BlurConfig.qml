pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root
    property int passes: 3
    property real offset: 3
    property real noise: 0.018
    property real saturation: 1
    property string log: ""
    property bool supported: false
    readonly property bool busy: !!(writer.running || reader.running)   // undefined while the Processes are being made
    function refresh() {
        if (!busy)
            reader.running = true;
    }
    function save(changes) {
        if (busy || !supported)
            return;
        if (Shell.dev) {
            log = I18n.t("В dev-режиме конфиг niri не изменяется", "Dev mode does not modify niri");
            return;
        }
        writer.command = ["python3", Quickshell.shellDir + "/scripts/blur-config.py", JSON.stringify(changes)];
        writer.running = true;
    }
    Process {
        id: reader
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/blur-config.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text);
                    root.passes = v.passes;
                    root.offset = v.offset;
                    root.noise = v.noise;
                    root.saturation = v.saturation;
                    root.supported = true;
                } catch (e) {
                    root.supported = false;
                    root.log = I18n.t("Не найден блок blur в конфиге niri", "No blur block found in the niri config");
                }
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) root.log = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.log = text.trim()
        }
        onExited: reader.running = true
    }
}
