pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The wind of the layered scenes (widgets/SceneWall), one for every screen, with no network: a
// climate of its own for every machine (its seed is /etc/machine-id), calm hours and windy ones
// from the real clock; it dies down while nobody is at the computer and greets them with a gust
// when they come back; now and then (4–15 min, the seed's own times) a strong gust tears leaves
// off. The scene adds its gusts and the gust front on top (SceneWall: wind, windDir, pulse).
//   SceneWind.strength   0..1, the hour's wind (eased)
//   SceneWind.dir        -1..1, where it blows (eased)
//   SceneWind.pulse      0..1, a gust from an event, decaying
//   SceneWind.seed       0..1, this machine's
Singleton {
    id: root

    property real seed: 0.5
    property real climate: 0.35     // the hour's strength before the people
    property real climateDir: 1
    readonly property real strength: Math.max(0.05, climate * calm)
    property real calm: 1           // 1 at the computer, 0.25 away
    property real dir: 1
    property real pulse: 0

    // where they are headed: the values above go there a step a second (about 20 s, 30 s and
    // a minute to arrive). Not a Behavior: an animation ticks every frame of the screen, and with
    // the weather new every minute it never stopped — every scene drew at the screen's rate
    // (165 a second) instead of its own (Config.wallpaper.liveFps)
    property real climateTo: 0.35
    property real calmTo: 1
    readonly property bool settled: Math.abs(climate - climateTo) < 0.002 && Math.abs(calm - calmTo) < 0.002 && Math.abs(dir - climateDir) < 0.002
    Timer {
        interval: 1000
        repeat: true
        running: !root.settled
        onTriggered: {
            const near = (v, to, k) => Math.abs(to - v) < 0.002 ? to : v + (to - v) * k;
            root.climate = near(root.climate, root.climateTo, 0.06);
            root.calm = near(root.calm, root.calmTo, 0.15);
            root.dir = near(root.dir, root.climateDir, 0.1);
        }
    }

    function hash(n) {
        const x = Math.sin(n * 127.1 + seed * 311.7) * 43758.5453;
        return x - Math.floor(x);
    }
    // smooth value noise over the hours: the climate never jumps
    function noise(x) {
        const i = Math.floor(x), f = x - i, s = f * f * (3 - 2 * f);
        return hash(i) * (1 - s) + hash(i + 1) * s;
    }
    function weather() {
        const h = Date.now() / 3600000;
        // mostly a breeze, some still hours, now and then a windy afternoon
        const n = noise(h / 2.5) * 0.7 + noise(h / 0.7 + 50) * 0.3;
        climateTo = 0.12 + Math.pow(n, 1.6) * 1.0;
        climateDir = noise(h / 5 + 90) < 0.5 ? -1 : 1;
    }
    function gust(size) {
        pulse = Math.max(pulse, size);
        decay.restart();
    }

    FileView {
        path: "/etc/machine-id"
        onLoaded: {
            let h = 0;
            for (const c of text().trim())
                h = (h * 31 + c.charCodeAt(0)) % 1000003;
            root.seed = h / 1000003;
            root.weather();
            events.schedule();
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.weather()
    }

    // nobody at the computer for 3 min: the wind dies down; back: a gust says hello
    IdleWatch {
        id: away
        timeout: 180
        onIsIdleChanged: {
            root.calmTo = isIdle ? 0.25 : 1;
            if (!isIdle)
                root.gust(0.9);
        }
    }

    NumberAnimation {
        id: decay
        target: root
        property: "pulse"
        to: 0
        duration: 4500
        easing.type: Easing.OutCubic
    }
    // the rare strong gust
    Timer {
        id: events
        property int n: 0
        function schedule() {
            interval = Math.round((4 + 11 * root.hash(1000 + n)) * 60000);
            n++;
            restart();
        }
        onTriggered: {
            if (!away.isIdle)
                root.gust(1);
            schedule();
        }
    }
}
