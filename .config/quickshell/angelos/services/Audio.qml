pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default sink/source volume + device lists. Only changes things on explicit calls.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: !!sink && !!sink.audio
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    readonly property var nodes: Pipewire.nodes.values
    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.audio && n.isStream && n.isSink)
    // what the mixers list: programs playing sound. Not angelOS's own clicks and chimes
    // (quickshell's SoundEffect, pw-play): they come and go every click and made the
    // mixer jump. Not virtual-sink plumbing either (loopbacks: node.virtual / link-group).
    readonly property var appStreams: streams.filter(n => isAppStream(n)).sort((a, b) => a.id - b.id)
    function isAppStream(n) {
        const p = n.properties || {};
        if (String(p["node.virtual"]) === "true" || String(p["node.link-group"] || "").startsWith("loopback"))
            return false;
        const app = String(p["application.name"] || p["node.name"] || n.name || "");
        if (app === "quickshell" || app === "pw-play" || app === "pw-cat" || app === "angelos-sfx")
            return false;
        return String(p["media.name"] || "").indexOf("/angelos/sounds/") < 0;
    }
    function streamName(n) {
        const p = n.properties || {};
        return p["application.name"] || p["media.name"] || nodeName(n);
    }

    signal changed(string what)

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks).concat(root.sources).concat(root.streams)
    }

    function nodeName(n) {
        if (!n)
            return "—";
        return n.description || n.nickname || n.name || "?";
    }

    function setVolume(v) {
        if (!ready)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1.5, v));
        changed("volume");
    }
    function step(delta) {
        setVolume(Math.round((volume + delta) * 100) / 100);
    }
    function toggleMute() {
        if (!ready)
            return;
        sink.audio.muted = !sink.audio.muted;
        changed("volume");
    }
    function toggleMic() {
        if (!source || !source.audio)
            return;
        source.audio.muted = !source.audio.muted;
        changed("mic");
    }
    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
}
