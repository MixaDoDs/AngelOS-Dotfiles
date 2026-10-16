pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config

// Who records the microphone or has the camera on now: the Halo's privacy dot (as the
// iPhone's: orange for the microphone, green for the camera; the pointer on it says who).
//   microphone  PipeWire's capture streams (Stream/Input/Audio) of programs. Not angelOS's own
//               taps (pw-record behind the spectrum, the lyrics level, the RØDE fader follower),
//               not loopbacks and filter chains (no program name), not a sink's monitor (that
//               listens to what plays, not to you)
//   camera      scripts/cam-watch.py: inotify on /dev/video*, who holds one open; a program
//               that takes the camera through PipeWire (the portal) shows as PipeWire there,
//               its name comes from PipeWire's video capture stream instead
// Settings → Halo → «Privacy dot».
Singleton {
    id: root

    readonly property bool wanted: Config.ready && !!Config.halo.enabled && (Config.halo.privacyDot !== false || Config.halo.calls !== false) && !Shell.dev

    // the programs' streams (which way each goes: its media.class, read below)
    readonly property var captures: Pipewire.nodes.values.filter(n => n.isStream)
    PwObjectTracker {
        objects: root.wanted ? root.captures : []
    }
    // our own taps and the plumbing: never "someone listens"
    readonly property var ownNames: ["pw-record", "pw-cat", "quickshell", "angelos-cava", "cava"]
    function app(n) {
        const p = n.properties || {};
        if (String(p["stream.capture.sink"]) === "true" || String(p["node.virtual"]) === "true")
            return "";
        if (String(p["node.link-group"] || "").startsWith("loopback"))
            return "";
        const name = String(p["application.name"] || "");
        if (!name || ownNames.includes(name.toLowerCase()) || String(p["node.name"] || "").startsWith("angelos"))
            return "";
        return name;
    }
    function names(cls) {
        const out = [];
        for (const n of captures) {
            if (String((n.properties || {})["media.class"] || "") !== cls)
                continue;
            const a = app(n);
            if (a && !out.includes(a))
                out.push(a);
        }
        return out;
    }
    readonly property var mic: wanted ? names("Stream/Input/Audio") : []
    // the camera's holders by process name; PipeWire itself stands for its video streams
    property var camHolders: []
    readonly property var cam: {
        if (!wanted)
            return [];
        const out = [];
        const viaPw = names("Stream/Input/Video");
        for (const h of camHolders) {
            const n = h.name || "?";
            const plumbing = ["pipewire", "wireplumber", "pipewire-media-session"].includes(n);
            for (const x of plumbing ? viaPw : [n])
                if (!out.includes(x))
                    out.push(x);
        }
        return out;
    }
    readonly property bool active: mic.length > 0 || cam.length > 0
    // "Микрофон: Discord, OBS · Камера: chromium"
    readonly property string who: [mic.length ? I18n.t("Микрофон: ", "Microphone: ") + mic.join(", ") : "", cam.length ? I18n.t("Камера: ", "Camera: ") + cam.join(", ") : ""].filter(x => x).join(" · ")

    Process {
        id: watch
        running: root.wanted
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/cam-watch.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const l = JSON.parse(line);
                    if (Array.isArray(l))
                        root.camHolders = l;
                } catch (e) {}
            }
        }
        onRunningChanged: if (!running)
            root.camHolders = []
    }
}
