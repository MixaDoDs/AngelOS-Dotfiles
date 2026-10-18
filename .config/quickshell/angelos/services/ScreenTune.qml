pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Brightness, gamma, contrast, R/G/B and saturation per monitor (Settings → Monitor → Brightness
// and colour, Config.system.screenTune {output: {brightness 0.3–1, saturation −1…1, `curve`}}) and the night
// light's schedule (plugins/nightlight sets `night`). Software only, nothing on stream:
//   scripts/gamma.py     the gamma tables — brightness and the night light's warmth in one
//                        owner (wlsunset next to it would fight for them); runs only while
//                        there is something to change, the tables go back when it stops
//   scripts/vibrance.py  NVIDIA Digital Vibrance (nvibrant, fetched once), again after
//                        a monitor comes back or the machine wakes up
Singleton {
    id: root

    readonly property var tune: Config.system.screenTune || ({})
    property var night: null                 // {day, night, sunrise, sunset | location}, null = off
    property var states: ({})                // output -> ok | neutral | waiting | failed
    property int kelvin: 6600
    property string error: ""
    property bool nvidia: false
    property string driver: ""
    property string vibranceError: ""
    readonly property bool vibranceBusy: vib.running

    function brightnessOf(name) {
        const t = tune[name] || {};
        return t.brightness === undefined ? 1 : Math.max(0.3, Math.min(1, Number(t.brightness)));
    }
    // the rest of the gamma curve: key -> [as at boot, min, max]; scripts/gamma.py clamps the same
    readonly property var curve: ({
            "gamma": [1, 0.5, 2],
            "contrast": [1, 0.5, 1.5],
            "red": [1, 0.5, 1],
            "green": [1, 0.5, 1],
            "blue": [1, 0.5, 1]
        })
    function curveOf(name, key) {
        const t = tune[name] || {}, c = curve[key];
        return t[key] === undefined ? c[0] : Math.max(c[1], Math.min(c[2], Number(t[key])));
    }
    function tuned(name) {
        return brightnessOf(name) < 1 || saturationOf(name) !== 0 || Object.keys(curve).some(k => curveOf(name, k) !== curve[k][0]);
    }
    function saturationOf(name) {
        const t = tune[name] || {};
        return t.saturation === undefined ? 0 : Math.max(-1, Math.min(1, Number(t.saturation)));
    }
    function setTune(name, key, value) {
        const all = Object.assign({}, Config.system.screenTune || {});
        const t = Object.assign({}, all[name] || {});
        if (value === null || value === undefined)
            delete t[key];
        else
            t[key] = value;
        if (Object.keys(t).length)
            all[name] = t;
        else
            delete all[name];
        Config.system.screenTune = all;
    }
    function reset(name) {
        const all = Object.assign({}, Config.system.screenTune || {});
        delete all[name];
        Config.system.screenTune = all;
    }
    // what the gamma tables of this output are doing, for Settings
    function stateOf(name) {
        return states[name] || "neutral";
    }

    // ---- gamma: brightness, the curve + night light ----
    readonly property var gammaOutputs: {
        const o = {};
        for (const n of Object.keys(tune)) {
            const t = {};
            if (brightnessOf(n) < 0.999)
                t.brightness = brightnessOf(n);
            for (const k of Object.keys(curve))
                if (curveOf(n, k) !== curve[k][0])
                    t[k] = curveOf(n, k);
            if (Object.keys(t).length)
                o[n] = t;
        }
        return o;
    }
    readonly property bool gammaWanted: Config.ready && !Shell.dev && (Object.keys(gammaOutputs).length > 0 || !!night)
    readonly property string gammaMessage: JSON.stringify({
        "outputs": gammaOutputs,
        "night": night
    })
    function send(retry) {
        if (!gamma.running)
            return;
        const m = JSON.parse(gammaMessage);
        if (retry)
            m.retry = true;
        gamma.write(JSON.stringify(m) + "\n");
    }
    onGammaMessageChanged: send(false)
    onGammaWantedChanged: {
        if (gammaWanted) {
            gamma.running = true;
        } else {
            gamma.running = false;
            states = {};
            kelvin = 6600;
        }
    }
    Component.onCompleted: {
        if (gammaWanted)
            gamma.running = true;
        if (Config.ready && !Shell.dev)
            probe.running = true;
    }
    Process {
        id: gamma
        stdinEnabled: true
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/gamma.py"]
        onStarted: root.send(false)
        stdout: SplitParser {
            onRead: line => {
                try {
                    const r = JSON.parse(line);
                    if (r.outputs)
                        root.states = r.outputs;
                    if (r.kelvin)
                        root.kelvin = r.kelvin;
                    root.error = r.error || "";
                } catch (e) {}
            }
        }
        onExited: if (root.gammaWanted && !restart.running)
            restart.start()
    }
    Timer {
        id: restart
        interval: 3000
        onTriggered: if (root.gammaWanted)
            gamma.running = true
    }
    // another owner (a wlsunset left over) let go: ask again now and then
    readonly property bool anyFailed: Object.keys(states).some(n => states[n] === "failed")
    Timer {
        interval: 20000
        repeat: true
        running: root.anyFailed && gamma.running
        onTriggered: root.send(true)
    }

    // ---- saturation: NVIDIA Digital Vibrance ----
    Process {
        id: probe
        command: ["python3", Quickshell.shellDir + "/scripts/vibrance.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.nvidia = !!r.nvidia;
                    root.driver = r.driver || "";
                    if (root.nvidia && root.anySaturation())
                        vibDebounce.restart();
                } catch (e) {}
            }
        }
    }
    function anySaturation() {
        return Object.keys(tune).some(n => saturationOf(n) !== 0);
    }
    readonly property string vibranceKey: JSON.stringify(Object.keys(tune).sort().map(n => [n, saturationOf(n)]))
    property string vibranceApplied: ""
    property bool vibranceAgain: false
    onVibranceKeyChanged: if (nvidia)
        vibDebounce.restart()
    Timer {
        id: vibDebounce
        interval: 250
        onTriggered: root.applyVibrance(false)
    }
    function applyVibrance(force) {
        if (!Config.ready || Shell.dev || !nvidia)
            return;
        if (vib.running) {
            vibranceAgain = true;
            return;
        }
        if (!force && vibranceKey === vibranceApplied)
            return;
        // every output we know of: one left out goes back to 0 (as at boot)
        vib.command = ["python3", Quickshell.shellDir + "/scripts/vibrance.py", "set"].concat(Object.keys(tune).map(n => n + "=" + saturationOf(n)));
        vib.key = vibranceKey;
        vib.running = true;
    }
    Process {
        id: vib
        property string key: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.vibranceError = r.ok ? ((r.unknown || []).length ? I18n.t("не нашёл порт для ", "No port found for ") + r.unknown.join(", ") : "") : (r.error || "nvibrant");
                    if (r.ok)
                        root.vibranceApplied = vib.key;
                } catch (e) {
                    root.vibranceError = I18n.t("nvibrant не ответил", "nvibrant didn't answer");
                }
            }
        }
        onExited: if (root.vibranceAgain) {
            root.vibranceAgain = false;
            vibDebounce.restart();
        }
    }
    // a monitor plugged back in or a wake-up: the driver may have dropped the vibrance
    Connections {
        target: Shell
        function onResumed() {
            if (root.anySaturation())
                again.restart();
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.anySaturation())
                again.restart();
        }
    }
    Timer {
        id: again
        interval: 2500
        onTriggered: root.applyVibrance(true)
    }
}
