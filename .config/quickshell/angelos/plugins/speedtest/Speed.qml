pragma Singleton

import QtQuick
import qs.config
import Quickshell
import Quickshell.Io

// Runs speedtest-cli and parses its human output line by line for live phases.
Singleton {
    id: root

    property string phase: "idle"   // idle | config | server | ping | download | upload | done | error
    property string isp: ""
    property string ip: ""
    property string server: ""
    property real ping: 0
    property real down: 0
    property real up: 0
    property string error: ""
    property string log: ""
    readonly property bool running: proc.running
    property real wobble: 0          // animated needle while measuring
    signal finished(var result)

    function start() {
        if (proc.running)
            return;
        phase = "config";
        isp = ip = server = error = log = "";
        ping = down = up = 0;
        proc.running = true;
    }
    function stop() {
        proc.running = false;
        phase = "idle";
    }

    Timer {
        interval: 90
        repeat: true
        running: root.phase === "download" || root.phase === "upload" || root.phase === "ping"
        onTriggered: root.wobble = Math.max(0.05, Math.min(0.95, root.wobble + (Math.random() - 0.45) * 0.12))
    }

    Process {
        id: proc
        // servers.py: speedtest-cli with the site's own, near servers (the old list fails over a VPN)
        command: ["sh", "-c", "exec python3 -I -u \"$1\" --secure 2>&1", "sh", decodeURIComponent(Qt.resolvedUrl("servers.py").toString().replace(/^file:\/\//, ""))]
        stdout: SplitParser {
            onRead: line => {
                root.log += line + "\n";
                let m;
                if (/Retrieving speedtest.net configuration/.test(line))
                    root.phase = "config";
                else if ((m = line.match(/^Testing from (.*) \(([^)]+)\)/))) {
                    root.isp = m[1];
                    root.ip = m[2];
                } else if (/server list|Selecting best server/.test(line))
                    root.phase = "ping";
                else if ((m = line.match(/^Hosted by (.*?)(?: \[[^\]]*\])?: ([\d.]+) ms/))) {
                    root.server = m[1];
                    const ms = parseFloat(m[2]);
                    root.ping = ms > 60000 ? 0 : ms;   // speedtest-cli reports 1800000 when it could not measure
                } else if (/Testing download speed/.test(line))
                    root.phase = "download";
                else if ((m = line.match(/^Download: ([\d.]+) Mbit/))) {
                    root.down = parseFloat(m[1]);
                    root.phase = "upload";
                } else if (/Testing upload speed/.test(line))
                    root.phase = "upload";
                else if ((m = line.match(/^Upload: ([\d.]+) Mbit/)))
                    root.up = parseFloat(m[1]);
                else if (/ERROR|Cannot|Traceback|error:/i.test(line))
                    root.error = line;
            }
        }
        onExited: code => {
            if (code === 0 && root.up > 0) {
                root.phase = "done";
                root.finished({
                    "time": Date.now(),
                    "ping": root.ping,
                    "down": root.down,
                    "up": root.up,
                    "server": root.server,
                    "isp": root.isp
                });
            } else if (root.phase !== "idle") {
                root.phase = "error";
                if (!root.error)
                    root.error = code === 127 ? I18n.t("speedtest-cli не найден: sudo pacman -S speedtest-cli", "Install speedtest-cli: sudo pacman -S speedtest-cli") : "тест прервался (код " + code + ")";
            }
        }
    }
}
