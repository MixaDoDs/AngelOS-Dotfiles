pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config
import qs.services

// The first run's minute before the setup wizard (SetupWizard): it looks like an installer, and
// it is waking up. Over a minute the edges split red and blue more and more, the glow grows, the
// screen shakes with low booms; a Shepard tone and a noise riser climb, a heartbeat speeds up, a
// fire crackles nearer, women scream far, far away; «Привет» at 15 s, «Я тут» at 25 s with a
// burning tree falling. At its loudest it is cut off: a plink, a cute bouncy tune, and the split,
// the glow and the blur fade off the wizard behind it. The tune plays through the wizard and
// fades out over 3 s once the desktop is let go. Space five times skips to the cut.
//
// The minute's sound is mixed by scripts/intro-sounds.py out of data/sounds/intro (CC0
// recordings, SOURCES.md: screams, fire, risers, booms, the plink, the tune) and a little
// synthesis — once, ~16 s, while the installer already shows as it is; yours in
// ~/.local/share/angelos/sounds/intro-own/ play instead. The pictures follow its timeline.json;
// the ophanim rises from below at its moment (SetupIntroScreen). Music already playing (MPRIS)
// fades out and pauses — not a game's.
// This is the controller (one for all the screens); SetupIntroScreen draws the installer and the
// words, SetupWake the waking up over each screen.
// Only on the first run (or opened from Settings → Account «with the intro» in debug mode:
// Shell.setupIntroOnce; or ANGELOS_SETUP_INTRO=1; =0 never); not while motion is off.
Scope {
    id: root

    readonly property string env: Quickshell.env("ANGELOS_SETUP_INTRO") || ""
    readonly property bool wanted: env !== "0" && !Motion.still && (Shell.setupFirstRun || Shell.setupIntroOnce || env === "1")
    // "" → bake (the sounds being made) → run (the minute) → reveal (the cut, fading off) → done
    property string phase: ""
    readonly property bool active: phase === "bake" || phase === "run" || phase === "reveal"
    readonly property bool holding: phase === "bake" || phase === "run"
    property real t: 0                       // s into the minute
    property real reveal: 0                  // 0 → 1 after the cut
    property var timeline: ({})
    readonly property real length: timeline.length || 60
    property int presses: 0
    readonly property int pressesToSkip: 5

    signal shook(real strength)

    readonly property string dir: Config.home + "/.local/share/angelos/sounds/intro"
    // ANGELOS_SETUP_INTRO_MUTE=1: silent, and the music playing is left alone (trying it next to
    // a live session)
    readonly property bool muted: Quickshell.env("ANGELOS_SETUP_INTRO_MUTE") === "1"
    readonly property real volume: StreamMode.quiet || muted ? 0 : (Motion.calm ? 0.36 : 0.55)

    // ---- start and stop with the wizard ----
    Connections {
        target: Shell
        function onSetupLockedChanged() {
            if (Shell.setupLocked)
                root.begin();
            else
                root.end();
        }
    }
    Component.onCompleted: if (Shell.setupLocked)
        begin()
    function begin() {
        const want = wanted;
        Shell.setupIntroOnce = false;
        if (!want || phase !== "")
            return;
        phase = "bake";
        t = 0;
        reveal = 0;
        presses = 0;
        bake.running = true;
        bakeTimeout.restart();
    }
    // the wizard is gone (done, closed, `angelos setup skip`): the minute stops at once, the tune
    // fades out over 3 s
    function end() {
        bake.running = false;
        bakeTimeout.stop();
        clock.stop();
        revealing.stop();
        intro.stop();
        phase = "";
        if (music.playbackState === MediaPlayer.PlayingState)
            fadeOut.restart();
    }

    // ---- the sounds: made once, then only looked up ----
    Process {
        id: bake
        command: ["python3", Quickshell.shellDir + "/scripts/intro-sounds.py", root.dir]
        onExited: code => {
            if (root.phase !== "bake")
                return;
            bakeTimeout.stop();
            if (code !== 0) {
                console.warn("setup intro: the sounds were not made — straight to the wizard");
                root.phase = "done";
                return;
            }
            timelineFile.reload();
        }
    }
    // a slow machine: the wizard rather than a long wait
    Timer {
        id: bakeTimeout
        interval: 30000
        onTriggered: if (root.phase === "bake") {
            bake.running = false;
            root.phase = "done";
        }
    }
    FileView {
        id: timelineFile
        path: root.dir + "/timeline.json"
        printErrors: false
        onLoaded: {
            if (root.phase !== "bake")
                return;
            try {
                root.timeline = JSON.parse(text());
            } catch (e) {
                root.phase = "done";
                return;
            }
            intro.source = root.fileUrl(root.timeline.files.intro);
            plink.source = root.fileUrl(root.timeline.files.plink);
            music.source = root.fileUrl(root.timeline.files.doki);
            intro.play();
        }
    }
    function fileUrl(p) {
        return "file://" + p.split("/").map(encodeURIComponent).join("/");
    }

    // ---- the minute: its clock starts with the sound ----
    MediaPlayer {
        id: intro
        audioOutput: AudioOutput {
            volume: root.volume
        }
        onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState && root.phase === "bake") {
            root.phase = "run";
            root.duck();
            clock.restart();
        }
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia && root.phase === "run")
            root.cut()
        onErrorOccurred: (error, message) => {
            console.warn("setup intro:", message);
            if (root.phase === "bake")
                root.phase = "done";
        }
    }
    // by the wall clock, every frame (an animation's own clock fell 4 s behind in a minute,
    // the sound would have ended long before the cut); the sound's end cuts, this only if it
    // never comes
    FrameAnimation {
        id: clock
        property double t0: 0
        function restart() {
            t0 = Date.now();
            root.t = 0;
            start();
        }
        onTriggered: {
            root.t = Math.min(root.length, (Date.now() - t0) / 1000);
            if (root.t >= root.length && Date.now() - t0 > root.length * 1000 + 500)
                root.cut();
        }
    }
    // the timeline's moments
    property int nextShake: 0
    onTChanged: {
        const shakes = timeline.shakes || [];
        while (nextShake < shakes.length && t >= shakes[nextShake][0]) {
            shook(shakes[nextShake][1]);
            nextShake++;
        }
    }
    onPhaseChanged: if (phase === "run")
        nextShake = 0

    // ---- skipping: space five times ----
    function press() {
        if (phase !== "run")
            return;
        presses++;
        pressesReset.restart();
        if (presses >= pressesToSkip)
            cut();
    }
    Timer {
        id: pressesReset
        interval: 3000
        onTriggered: root.presses = 0
    }

    // ---- the cut: silence, a plink, the tune, and the waking up fades off ----
    function cut() {
        if (phase !== "run")
            return;
        clock.stop();
        intro.stop();
        phase = "reveal";
        plink.play();
        fadeOut.stop();
        musicOut.volume = root.volume * 0.8;
        music.play();
        revealing.restart();
    }
    NumberAnimation {
        id: revealing
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: 3500
        easing.type: Easing.OutCubic
        onFinished: root.phase = "done"
    }
    MediaPlayer {
        id: plink
        audioOutput: AudioOutput {
            volume: root.volume
        }
    }
    MediaPlayer {
        id: music
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput {
            id: musicOut
        }
    }
    NumberAnimation {
        id: fadeOut
        target: musicOut
        property: "volume"
        to: 0
        duration: 3000
        onFinished: music.stop()
    }

    // ---- other music: faded out and paused (a game's stays) ----
    property var ducked: []
    function isGame(p) {
        return /steam|lutris|heroic|bottles|wine|proton|osu|minecraft|game/i.test((p.identity || "") + " " + (p.desktopEntry || "") + " " + (p.dbusName || ""));
    }
    function duck() {
        if (muted)
            return;
        const list = [];
        for (const p of Mpris.players.values)
            if (p.isPlaying && !isGame(p))
                list.push({
                    "player": p,
                    "volume": p.volumeSupported ? p.volume : -1
                });
        ducked = list;
        if (list.length) {
            duckStep.k = 0;
            duckStep.restart();
        }
    }
    Timer {
        id: duckStep
        property int k: 0
        interval: 100
        repeat: true
        onTriggered: {
            k++;
            const done = k >= 15;
            for (const d of root.ducked) {
                if (d.volume >= 0 && d.player.canControl)
                    d.player.volume = d.volume * (1 - k / 15);
                if (done && d.player.canPause)
                    d.player.pause();
            }
            if (done) {
                // the volume back where it was (after the pause has gone through)
                stop();
                restoreVolume.restart();
            }
        }
    }
    Timer {
        id: restoreVolume
        interval: 300
        onTriggered: {
            for (const d of root.ducked)
                if (d.volume >= 0 && d.player.canControl)
                    d.player.volume = d.volume;
        }
    }
}
