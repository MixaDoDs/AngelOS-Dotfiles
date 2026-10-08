pragma Singleton

import QtQuick
import Quickshell
import qs.config

// The way between hell's circles (services/Story → run; modules/y2k/CircleTransition draws
// it): the screen goes dark through an ordered dither (faintly the new circle's colour), a low
// heavy blow sounds in the dark (Sounds "circle") with the circle's sin over it ("circleSin"), the new circle's number and name come up out of the black and stand a
// moment, then the dark lifts on the circle's look. `atDark` runs once the screen is black
// (the palette switches there, unseen), `then` after it has lifted.
// Calm (Motion.calm): slower, and a soft swell instead of the blow. Motion off: no show at all. Screens with a
// fullscreen window (games, video — when niri-game-mode turns animations off) or streamed
// screens get no dark at all; with none left the switch happens at once, silently.
// Programs go quiet meanwhile and come back slowly after it (services/AppDuck).
// Nothing takes input: Start, the power menu, notifications, polkit and the lock (all on
// the Overlay layer or the session lock) stay above it and keep working.
Singleton {
    id: root

    property bool active: false
    property string target: ""               // the circle coming up
    property real veil: 0                    // 0..1 the dark
    property real title: 0                   // 0..1 the number and name
    readonly property bool calm: Story.calm
    readonly property int tIn: calm ? 1700 : 900
    readonly property int tHit: tIn + 250
    readonly property int tTitle: tIn + 700
    readonly property int tTitleIn: calm ? 1200 : 800
    readonly property int tLift: tTitle + tTitleIn + 2000
    readonly property int tOut: calm ? 1700 : 1100

    function shownOn(name) {
        return StreamMode.effectsOn(name) && !Shell.fullscreenOn(name) && !Shell.locked;
    }
    readonly property bool anywhere: Shell.screens.some(s => shownOn(s.name))

    property var _atDark: null
    property var _then: null
    property bool _dark: false
    property bool _hit: false
    property double _t0: 0
    property int runs: 0                     // the self-test counts the shows asked for
    function run(id, atDark, then) {
        runs++;
        // one at a time: a second run while the first is dark switches at once
        if (active) {
            if (atDark)
                atDark();
            target = id;
            return;
        }
        if (!anywhere || Motion.still) {
            if (atDark)
                atDark();
            if (then)
                then();
            return;
        }
        target = id;
        // the hit's sounds decoded and the sound stream opened now, a second before the blow:
        // decoding them at the blow made the sin come late (ffmpeg, slower still under a game)
        Sounds.warm(calm ? "circleSoft" : "circle");
        Sounds.warmSin(id);
        AppDuck.duck();
        _atDark = atDark;
        _then = then;
        _dark = false;
        _hit = false;
        veil = 0;
        title = 0;
        _t0 = Date.now();
        active = true;
        clock.start();
    }
    Timer {
        id: clock
        interval: 33
        repeat: true
        onTriggered: root.step()
    }
    function steps(x, n) {
        return Math.floor(Math.max(0, Math.min(1, x)) * n) / n;
    }
    function step() {
        const t = Date.now() - _t0;
        veil = t < tIn ? steps(t / tIn, 8) : t < tLift ? 1 : 1 - steps((t - tLift) / tOut, 8);
        title = t < tTitle ? 0 : t < tTitle + tTitleIn ? steps((t - tTitle) / tTitleIn, 6) : t < tLift ? 1 : 1 - steps((t - tLift) / (tOut * 0.6), 6);
        // the switch waits two frames after the dark is whole: it holds the shell for a moment
        // (the circle's look re-binds), and run in the same tick it froze the dark at 7/8
        if (t >= tIn + 70 && !_dark) {
            _dark = true;
            const f = _atDark;
            _atDark = null;
            if (f)
                f();
        }
        if (t >= tHit && !_hit) {
            _hit = true;
            Sounds.play(calm ? "circleSoft" : "circle");
            // and the circle's own sin on top: coins, a punch, a snicker (softer when calm)
            Sounds.playSin(target, calm ? 0.45 : 1);
        }
        if (t >= tLift + tOut) {
            clock.stop();
            AppDuck.release();
            active = false;
            veil = 0;
            title = 0;
            const f = _then;
            _then = null;
            if (f)
                f();
        }
    }
}
