pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config

// How bright the lyric line on the bar is (Lyrics → Brightness follows the volume):
//   rode   a RØDECaster: where its fader stands. scripts/lyrics-level.py lays the
//          player's own sound over the console's mix after the faders (Config.lyrics.glowTap)
//          and reads the fader's gain from it — the fader down, the line fades. With the
//          main mix and a multitrack source on the same console it reads the multitrack
//          instead: the player's own track against the mix, the mic a track of its own,
//          so talking over the music doesn't dim the line
//          With rode-fader-follow running (a user service of the RØDECaster Duo's PipeWire
//          setup: it solves the same least squares and sets a fader's gain as the volume of its
//          track's rcp_duo_*fader*_src source) that volume is read instead — no second
//          20-channel capture solving it again (5–6 % of a core while music plays). Which
//          track is the player's is found once by the script (the console decides which fader
//          a USB channel goes to: a browser on System came on fader 4, not Music)
//   level  everyone else: how loud the player really plays — its own output after its
//          slider in the mixer, plus the master volume; the quiet parts of a song are
//          dimmer too (fast up, slow down)
// Between Config.lyrics.glowFloor (never under 30 %) and 100 %, in tenths; the script
// reports at most twice a second. Measured only while a line is on screen and the
// player plays; paused, the last brightness holds.
Singleton {
    id: root

    readonly property string mode: ["off", "auto", "rode", "level"].includes(Config.lyrics.glow) ? Config.lyrics.glow : "auto"
    // the console's sources (ALSA "pro" profile: pro-input-0 the stereo mix, pro-input-1 the multitrack)
    readonly property var rodeSources: Audio.sources.filter(n => /alsa_input\..*(rodecaster|r__de)/i.test(n.name || ""))
    readonly property bool rodePresent: rodeSources.length > 0
    readonly property bool numpyMissing: _error.indexOf("numpy") >= 0
    readonly property string effective: mode === "off" ? "off" : (mode === "rode" || (mode === "auto" && rodePresent)) && rodePresent && !numpyMissing ? "rode" : "level"
    function channelsOf(n) {
        const p = n && n.properties || {};
        return parseInt(p["audio.channels"]) || String(p["audio.position"] || "").split(",").filter(c => c.trim()).length;
    }
    readonly property var multitrackNode: rodeSources.find(n => channelsOf(n) > 2) || rodeSources.find(n => /pro-input-1$/.test(n.name || "")) || null
    // where the fader is read: "main", then every pair the multitrack has — aux01, aux23 …
    // aux1819 on a Duo (20 channels); its count unknown, the first ten channels
    readonly property var taps: {
        const out = {
            "main": []
        };
        const n = Math.max(channelsOf(multitrackNode), 10);
        for (let c = 0; c + 1 < n; c += 2)
            out["aux" + c + (c + 1)] = ["AUX" + c, "AUX" + (c + 1)];
        return out;
    }
    readonly property var tapList: Object.keys(taps)
    readonly property string tap: taps[Config.lyrics.glowTap] ? Config.lyrics.glowTap : "main"
    readonly property var mixNode: tap === "main" ? rodeSources.find(n => /pro-input-0$/.test(n.name || "")) || rodeSources.find(n => n !== multitrackNode) || null : multitrackNode
    // the multitrack pair the script found the player on (main / AUX0/1), or was given
    property string track: ""

    // the player's own stream in PipeWire: the MPRIS player matched by name
    readonly property var stream: {
        const p = Lyrics.player;
        const list = Audio.appStreams;
        if (!p || !list.length)
            return null;
        const keys = [p.identity, p.desktopEntry, String(p.dbusName || "").replace("org.mpris.MediaPlayer2.", "").split(".")[0]].filter(k => !!k).map(k => String(k).toLowerCase());
        const hit = n => {
            const pr = n.properties || {};
            const bin = String(pr["application.process.binary"] || "").toLowerCase();
            const hay = [pr["application.name"], bin, pr["application.id"], pr["node.name"]].filter(v => !!v).join(" ").toLowerCase();
            return keys.some(k => hay.includes(k) || (bin && k.includes(bin)) || k.includes(String(pr["application.name"] || "~").toLowerCase()));
        };
        return list.find(hit) || (list.length === 1 ? list[0] : null);
    }
    readonly property string streamSerial: stream && stream.properties ? String(stream.properties["object.serial"] || "") : ""

    property real db: NaN                    // last reading: fader gain (rode) or level (level)
    property string _error: ""
    property string _readingFor: ""          // which mode the reading belongs to
    readonly property bool measuring: probe.running

    // ---- the fader the console's follower already reads (see the top) ----
    property bool followerActive: false
    Process {
        id: follower
        command: ["systemctl", "--user", "is-active", "--quiet", "rode-fader-follow.service"]
        onExited: code => root.followerActive = code === 0
    }
    // asked when the console comes and whenever the music starts: one systemctl, not a poll
    function askFollower() {
        if (rodePresent && !follower.running)
            follower.running = true;
    }
    onRodePresentChanged: askFollower()
    Connections {
        target: Lyrics
        function onPlayingChanged() {
            if (Lyrics.playing)
                root.askFollower();
        }
    }
    // the tracks whose fader the follower reads (its TARGETS, ~/.local/bin/rode-fader-follow.py)
    readonly property var followed: ({
            "AUX4/5": "rcp_duo_fader2_src",
            "AUX8/9": "rcp_duo_fader4_src",
            "AUX10/11": "rcp_duo_vfader1_src"
        })
    // the player's track: the pair picked in the settings, else the one the script found
    readonly property string playerTrack: tap !== "main" ? taps[tap].join("/").replace(/\/AUX/, "/") : track
    readonly property var faderNode: followerActive && followed[playerTrack] ? Audio.sources.find(n => n.name === followed[playerTrack]) || null : null
    PwObjectTracker {
        objects: root.faderNode ? [root.faderNode] : []
    }
    readonly property bool fromFader: effective === "rode" && !!faderNode && !!faderNode.audio
    // the node's volume is on the mixer's cubic scale (93 % = 0.80 of the sound = −1.9 dB, as pactl says)
    readonly property real faderDb: fromFader ? (faderNode.audio.muted ? -90 : Math.max(-90, 60 * Math.log(Math.max(1e-6, faderNode.audio.volume)) / Math.LN10)) : NaN
    onFaderDbChanged: {
        if (!fromFader || isNaN(faderDb))
            return;
        _readingFor = "rode";
        db = faderDb;
    }

    readonly property bool wanted: Config.lyrics.enabled && effective !== "off" && Lyrics.hasLyrics && Lyrics.playing && !Lyrics.unseen && streamSerial !== "" && (effective !== "rode" || !!mixNode) && !fromFader
    readonly property real floor: Math.max(0.3, Math.min(1, (Config.lyrics.glowFloor || 30) / 100))
    // 0…1 between the calibrated ends
    readonly property real frac: {
        if (effective === "off")
            return 1;
        if (effective === "level" && (streamSerial === "" || isNaN(db) || _readingFor !== "level"))
            // no stream to listen to: the master volume alone
            return Math.max(0, Math.min(1, Audio.volume));
        if (isNaN(db) || _readingFor !== effective)
            return 1;
        if (effective === "rode") {
            const lo = Config.lyrics.glowRodeMin, hi = Config.lyrics.glowRodeMax;
            return Math.max(0, Math.min(1, (db - lo) / Math.max(1, hi - lo)));
        }
        const v = db + 20 * Math.log(Math.max(0.001, Audio.muted ? 0.001 : Audio.volume)) / Math.LN10;
        const lo = Config.lyrics.glowLevelMin, hi = Config.lyrics.glowLevelMax;
        return Math.max(0, Math.min(1, (v - lo) / Math.max(1, hi - lo)));
    }
    // what the bar shows: frac in tenths, moved only once the reading leaves the
    // current tenth by more than a margin. A fader standing still wobbles by a few dB;
    // without this the line kept easing (and the bar repainting at 200 Hz) non-stop
    property real _step: 1
    function _settle() {
        if (effective === "off")
            _step = 1;
        else if (Math.abs(frac - _step) >= 0.08)
            _step = Math.round(frac * 10) / 10;
    }
    onFracChanged: _settle()
    onEffectiveChanged: _settle()
    readonly property real opacity: effective === "off" ? 1 : floor + (1 - floor) * _step

    // how loud the player really plays, 0…1 — for a layered wallpaper's kick wave (WallpaperView,
    // while Bass.walls): its output after its slider plus the master volume, on the level mode's
    // scale. The level mode's reading when the line has one, else a reading of its own: a
    // RØDECaster's fader is no loudness to go by (29.10: the music's channel kept out of the
    // console's mix, its fader can't be seen at all)
    readonly property real loud: {
        const d = effective === "level" && _readingFor === "level" ? db : levelDb;
        const vol = Audio.muted ? 0.001 : Math.max(0.001, Audio.volume);
        if (isNaN(d))
            return Math.min(1, vol);
        const lo = Config.lyrics.glowLevelMin, hi = Config.lyrics.glowLevelMax;
        return Math.max(0, Math.min(1, (d + 20 * Math.log(vol) / Math.LN10 - lo) / Math.max(1, hi - lo)));
    }
    property real levelDb: NaN
    readonly property bool hearWanted: Bass.walls > 0 && Lyrics.playing && streamSerial !== "" && !(effective === "level" && probe.running)
    onHearWantedChanged: hear.running = hearWanted
    onStreamSerialChanged: {
        levelDb = NaN;
        hear.running = false;
        hear.running = hearWanted;
    }
    Process {
        id: hear
        command: ["python3", Quickshell.shellDir + "/scripts/lyrics-level.py", "stream", root.streamSerial]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    if (typeof d.db === "number")
                        root.levelDb = d.db;
                } catch (e) {}
            }
        }
        // the stream went away or a hiccup: again while wanted
        onExited: if (root.hearWanted)
            hearAgain.restart()
    }
    Timer {
        id: hearAgain
        interval: 3000
        onTriggered: hear.running = root.hearWanted
    }

    // calibration (Lyrics page): "this is the top" / "this is the bottom"
    function markTop() {
        if (isNaN(db))
            return false;
        if (effective === "rode")
            Config.lyrics.glowRodeMax = Math.round(db);
        else
            Config.lyrics.glowLevelMax = Math.round(db + 20 * Math.log(Math.max(0.001, Audio.volume)) / Math.LN10);
        return true;
    }
    function markBottom() {
        if (isNaN(db))
            return false;
        if (effective === "rode")
            Config.lyrics.glowRodeMin = Math.round(Math.max(-80, db));
        else
            Config.lyrics.glowLevelMin = Math.round(Math.max(-80, db + 20 * Math.log(Math.max(0.001, Audio.volume)) / Math.LN10));
        return true;
    }
    function resetCalibration() {
        Config.lyrics.glowRodeMin = -40;
        Config.lyrics.glowRodeMax = 0;
        Config.lyrics.glowLevelMin = -48;
        Config.lyrics.glowLevelMax = -14;
    }

    readonly property var command: {
        const script = Quickshell.shellDir + "/scripts/lyrics-level.py";
        if (effective === "rode" && mixNode)
            return ["python3", script, "rode", streamSerial, mixNode.name].concat(taps[tap].length ? [taps[tap].join(",")] : []);
        return ["python3", script, "stream", streamSerial];
    }
    onCommandChanged: {
        track = "";
        if (probe.running) {
            probe.running = false;
            restart.restart();
        }
    }
    Timer {
        id: restart
        interval: 300
        onTriggered: probe.running = root.wanted
    }
    onWantedChanged: {
        if (wanted)
            restart.restart();
        else
            probe.running = false;
    }

    Process {
        id: probe
        command: root.command
        onStarted: root._error = ""
        stdout: SplitParser {
            onRead: line => {
                let d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (d.error) {
                    root._error = d.error;
                    return;
                }
                if (typeof d.db === "number") {
                    root._readingFor = root.effective;
                    root.db = d.db;
                    root.track = typeof d.track === "string" ? d.track.replace(/\/AUX/, "/") : "";
                }
            }
        }
        // the capture ended (the player's stream went away, a new song): try again while wanted
        onExited: code => {
            if (root.wanted && !root.numpyMissing)
                retry.restart();
        }
    }
    Timer {
        id: retry
        interval: 3000
        onTriggered: if (root.wanted && !probe.running)
            probe.running = true
    }
}
