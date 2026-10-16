pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Telemetry and the sponsor wall (scripts/telemetry.py, data/sponsor.json). The user is asked
// once — the setup wizard's «telemetry» step, or TelemetryPrompt for those set up before it —
// and Config.setup.telemetry keeps the answer: "" not asked | "yes" | "no". Only "yes" sends:
// a report a week (sooner when angelOS or Quickshell changed), to the author's relay; the
// script checks the answer again itself. Settings → Sponsor shows what goes and can take it back.
Singleton {
    id: root

    readonly property string consent: Config.setup.telemetry || ""
    readonly property bool on: consent === "yes"
    readonly property bool testing: !!Quickshell.env("ANGELOS_TEST")
    property var info: ({})                 // data/sponsor.json: {donate, endpoint}
    readonly property string donateUrl: info.donate || "https://www.donationalerts.com/r/mixaded"
    readonly property bool hasEndpoint: !!info.endpoint
    property var preview: null              // the report as it would go
    property var status: ({})               // telemetry.py status
    property var sponsors: []
    property string sponsorsUpdated: ""
    property bool sponsorsOffline: false

    function setConsent(v) {
        const was = consent;
        Config.setup.telemetry = v;
        if (v === "yes")
            sendSoon.restart();
        else if (was === "yes")
            run(["forget"]);
    }
    function donate() {
        Qt.openUrlExternally(donateUrl);
    }
    function loadPreview() {
        run(["preview"], t => root.preview = JSON.parse(t));
    }
    function loadSponsors() {
        run(["sponsors"], t => {
            const w = JSON.parse(t);
            root.sponsors = w.names || [];
            root.sponsorsUpdated = w.updated || "";
            root.sponsorsOffline = !!w.offline;
        });
    }
    function sendNow() {
        run(["send", "--force"], () => root.refreshStatus());
    }
    function refreshStatus() {
        run(["status"], t => root.status = JSON.parse(t));
    }

    // one helper process per call; `then(stdout)` when it is done
    function run(args, then) {
        const p = runner.createObject(root, {
            "command": ["python3", Quickshell.shellPath("scripts/telemetry.py")].concat(args),
            "then": then || null
        });
        p.running = true;
    }
    Component {
        id: runner
        Process {
            id: proc
            property var then: null
            stdout: StdioCollector {
                onStreamFinished: {
                    if (proc.then)
                        try {
                            proc.then(text);
                        } catch (e) {}
                    proc.destroy();
                }
            }
        }
    }

    FileView {
        path: Quickshell.shellPath("data/sponsor.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.info = JSON.parse(text());
            } catch (e) {}
        }
    }

    // a couple of minutes after the start, then twice a day: the script sends only when due
    Timer {
        id: sendSoon
        interval: 120000
        running: Config.ready && root.on && !root.testing && !Shell.dev
        onTriggered: root.run(["send"], () => root.refreshStatus())
    }
    Timer {
        interval: 12 * 3600 * 1000
        repeat: true
        running: Config.ready && root.on && !root.testing && !Shell.dev
        onTriggered: root.run(["send"], () => root.refreshStatus())
    }
}
