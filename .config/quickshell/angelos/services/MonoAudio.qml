pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config

// Mono audio (Settings → Sound, issue #177): one switch for every output, like the accessibility
// switch in Windows, macOS and GNOME. A one-channel twin (pipewire-pulse module-remap-sink
// "angelos_mono") over the chosen device is made the default: stereo is mixed down into it and
// played on both of the device's channels. services/Audio hides the twin and shows the device
// behind it, so the volume, the device lists and the OSD stay on the real device. Picking another
// device moves the twin there; switching off puts the device back as the default.
Singleton {
    id: root

    readonly property string twinName: "angelos_mono"
    readonly property bool on: Config.audio.mono
    readonly property PwNode twin: Audio.nodes.find(n => n.name === twinName) || null
    // the device under the twin: its loopback's target (pipewire-pulse keeps no props of ours)
    readonly property string master: {
        const out = Audio.nodes.find(n => n.name === "output." + twinName);
        return out && out.properties ? String(out.properties["target.object"] || "") : "";
    }
    property bool restored: false

    function isTwin(n) {
        return !!n && n.name === twinName;
    }

    function sync() {
        if (job.running || !Pipewire.ready || !Config.ready)
            return;
        const raw = Pipewire.defaultAudioSink;
        if (!on) {
            if (twin) {
                const dev = Audio.byName(master);
                if (isTwin(raw) && dev)
                    Pipewire.preferredDefaultAudioSink = dev;
                run("");
            }
            return;
        }
        // at the start: the twin of the last session is gone and the system picked some device;
        // the one the user had goes back
        if (!restored) {
            restored = true;
            const want = Audio.byName(Config.audio.monoDevice);
            if (want && !isTwin(raw) && raw !== want) {
                Pipewire.preferredDefaultAudioSink = want;
                return;
            }
        }
        // the device under the twin was unplugged: the twin goes, the system picks another device
        // and the next sync puts a twin over that one
        if (twin && master && !Audio.byName(master)) {
            run("");
            return;
        }
        const dev = isTwin(raw) ? Audio.byName(master) : raw;
        if (!dev || dev.isStream)
            return;
        if (twin && master === dev.name) {
            if (!isTwin(raw))
                Pipewire.preferredDefaultAudioSink = twin;
            return;
        }
        Config.audio.monoDevice = dev.name;
        run(dev.name);
    }

    // drops any twin, then (with a device) loads a new one over it
    function run(device) {
        job.command = ["sh", "-c", 'pactl list short modules | awk -v n="sink_name=$1" \'$2 == "module-remap-sink" && index($0, n " ") {print $1}\' | xargs -r -n1 pactl unload-module; [ -z "$2" ] || exec pactl load-module module-remap-sink sink_name="$1" master="$2" channels=1 channel_map=mono "sink_properties=device.description=\\"Mono (angelOS)\\""', "sh", twinName, device];
        job.running = true;
    }

    Process {
        id: job
        onExited: code => {
            if (code !== 0)
                console.warn("MonoAudio: pactl exited", code);
            Qt.callLater(root.sync);
        }
    }

    readonly property var watched: [on, Pipewire.ready, Config.ready, Pipewire.defaultAudioSink, Audio.sinks.length, twin, master]
    onWatchedChanged: Qt.callLater(sync)
}
