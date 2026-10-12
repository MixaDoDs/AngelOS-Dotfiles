pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import "../modules/bar/parts/EqMotion.js" as EqMotion

// The output equalizer of EasyEffects behind the bar's EQ face (modules/bar/parts/EqButton):
// one bridge (scripts/eq-bridge.py) and one spectrum for every bar on every screen.
// A face counts itself in `watchers` while it is shown, an open window in `viewers`.
Singleton {
    id: root

    property int watchers: 0
    property int viewers: 0

    // A RØDECaster gives the computer several outputs (Game, System, Chat, Music), a fader
    // each, and EasyEffects has one output chain: an app sent through the equalizer plays on
    // one of them only and ends up on another app's fader. No equalizer on the bar there,
    // nor before PipeWire has said what is plugged in (services/BarLayout leaves "eq" out).
    function isMixer(name) {
        return /^alsa_(input|output)\..*rodecaster/i.test(name || "");
    }
    readonly property bool mixer: Audio.nodes.some(n => isMixer(n.name))
    readonly property bool offered: Pipewire.ready !== false && !mixer

    property var levels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var frequencies: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    property string preset: ""
    property string error: ""
    property bool ready: false
    property bool active: false
    property var sourceChoices: []
    property var sourceRecords: []
    property var outputChoices: []
    property bool rode: false
    property string selectedSource: ""
    property string selectedOutput: ""
    property bool outputExplicit: false
    property bool routeActive: false
    property string routedApp: ""
    property string routedOutput: ""
    property string routingError: ""

    function send(line) {
        if (bridge.running)
            bridge.write(line + "\n");
    }
    function routeCommand(action) {
        if (!selectedSource || !selectedOutput)
            return;
        routingError = "";
        send(action + " " + JSON.stringify({
            "app": selectedSource,
            "output": selectedOutput
        }));
    }
    function releaseRoute() {
        routingError = "";
        send("release");
    }
    function defaultOutputFor(appName) {
        const app = sourceRecords.find(item => item.id === appName);
        if (!app)
            return "";
        return app.sinks.find(name => outputChoices.some(item => item.value === name)) || "";
    }
    function changeBand(index, gain) {
        if (!ready || !active)
            return;
        let next = levels.slice();
        next[index] = gain;
        levels = next;
        send("set " + index + " " + gain);
    }

    // The bars behind the curve. With an app in the equalizer they are that app (what goes
    // into EasyEffects), otherwise everything the computer plays.
    property var spectrumLevels: []
    readonly property bool spectrumLive: watchers > 0 && !Motion.still && !Power.eco
    readonly property string spectrumSpec: routeActive ? "monitor:easyeffects_sink" : ""
    readonly property string spectrumKey: Math.random().toString(36).slice(2, 10)
    readonly property string spectrumConf: Quickshell.env("HOME") + "/.cache/angelos/cava-eq-" + spectrumKey + ".conf"
    readonly property string spectrumFifo: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/angelos-cava-eq-" + spectrumKey + ".fifo"
    property string spectrumWritten: ""
    property bool spectrumUnavailable: false
    property double spectrumLastFrame: 0

    function writeSpectrumConf() {
        if (!spectrumLive || spectrumUnavailable)
            return;
        const text = ["[general]", "bars = 10", "framerate = 20", "sensitivity = 70", "autosens = 1", "[input]", "method = fifo", "source = " + spectrumFifo, "sample_rate = 22050", "sample_bits = 16", "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 100", "bar_delimiter = 59", "frame_delimiter = 10", "channels = mono", "[smoothing]", "noise_reduction = 60", ""].join("\n");
        // the same text again: FileView writes nothing and says no `saved`
        if (text === spectrumWritten) {
            audio.running = true;
        } else {
            spectrumWritten = text;
            spectrumFile.setText(text);
        }
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
    // another thing to listen to: the watchdog below starts the tap again
    onSpectrumSpecChanged: audio.running = false

    FileView {
        id: spectrumFile
        path: root.spectrumConf
        preload: false
        atomicWrites: true
        onSaved: audio.running = root.spectrumLive
    }
    Process {
        id: audio
        command: ["python3", Quickshell.shellDir + "/scripts/audio-tap.py", "run", "--conf", root.spectrumConf, "--fifo", root.spectrumFifo, root.spectrumSpec]
        property string lastLine: ""
        property double startedAt: 0
        onStarted: {
            startedAt = Date.now();
            root.spectrumLastFrame = startedAt;
        }
        stdout: SplitParser {
            onRead: line => {
                root.spectrumLastFrame = Date.now();
                if (line === audio.lastLine)
                    return;
                audio.lastLine = line;
                root.spectrumLevels = EqMotion.decodeSpectrum(line);
            }
        }
        onExited: code => {
            if (code === 127) {
                root.spectrumUnavailable = true;
            } else if (root.spectrumLive) {
                spectrumRetry.interval = Date.now() - startedAt > 15000 ? 2000 : Math.min(60000, spectrumRetry.interval * 2);
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
        running: root.watchers > 0
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/eq-bridge.py"]
        stdinEnabled: true
        onStarted: {
            write("status\n");
            write("sources\n");
        }
        stdout: SplitParser {
            onRead: line => {
                let state;
                try {
                    state = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (state.outputs) {
                    root.rode = !!state.rode;
                    root.outputChoices = state.outputs.map(item => ({
                                "label": item.label,
                                "value": item.name
                            }));
                    if (root.outputChoices.length && !root.outputChoices.some(item => item.value === root.selectedOutput))
                        root.selectedOutput = root.outputChoices[0].value;
                }
                if (state.apps) {
                    root.sourceRecords = state.apps;
                    root.sourceChoices = state.apps.map(item => ({
                                "label": item.app + (item.streams.length > 1 ? " · " + item.streams.length : ""),
                                "value": item.id
                            }));
                    if (root.selectedSource && !state.apps.some(item => item.id === root.selectedSource))
                        root.selectedSource = state.apps.length ? state.apps[0].id : "";
                    else if (!root.selectedSource && state.apps.length)
                        root.selectedSource = state.apps[0].id;
                    if (!root.outputExplicit) {
                        const preferred = root.defaultOutputFor(root.selectedSource);
                        if (preferred)
                            root.selectedOutput = preferred;
                    }
                }
                if (state.route !== undefined) {
                    const on = !!(state.route && state.route.active);
                    const app = state.route ? state.route.app || "" : "";
                    const output = state.route ? state.route.output || "" : "";
                    // show the route once when it changes, not on every poll: the lists
                    // stay free to pick another app while one is in the equalizer
                    const changed = on !== root.routeActive || app !== root.routedApp || output !== root.routedOutput;
                    root.routeActive = on;
                    root.routedApp = app;
                    root.routedOutput = output;
                    if (!state.apps)
                        root.routingError = state.error || "";
                    if (on && changed) {
                        root.selectedSource = app;
                        if (output) {
                            root.selectedOutput = output;
                            root.outputExplicit = true;
                        }
                    }
                }
                // the lists and a route say nothing about EasyEffects itself
                if (state.ready !== undefined) {
                    root.error = state.error || "";
                    root.ready = !!state.ready;
                }
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
        running: root.viewers > 0
        onTriggered: root.send("status")
    }
    // with a window open the lists follow what plays; with an app in the equalizer the
    // bridge also keeps EasyEffects on the chosen channel
    Timer {
        interval: root.viewers > 0 ? 1800 : 5000
        repeat: true
        running: root.viewers > 0 || (root.watchers > 0 && root.routeActive)
        onTriggered: root.send("sources")
    }
}
