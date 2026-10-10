pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The wallpaper, half alive (modules/background/WallpaperView; Settings → Wallpaper shows it small) (services/LiveWalls, shaders/live_wall.frag): drawn over the
// picture once its transition is over; fades in, gone at once when the picture changes.
// The clock stops while nobody sees the scene: locked, a fullscreen window — and with the
// stream's effects off on a streamed screen. Ordinary windows over it don't stop it.
// Every 12–35 s one rare event (shaders/live_wall.frag): a glint over a ring in the sky, a
// pebble off the edge, a gust over the water, an eye opening in a cloud (night), rings on open
// water — what the scene has; with music playing it waits for the
// next kick of the bass (services/LiveBeat).
ShaderEffect {
    id: root

    required property string screenName
    property string path: ""
    property var picture: null              // the shown picture as a texture (WallpaperView)
    property bool allowed: true             // false while a transition runs

    readonly property var fx: LiveWalls.effective(path)
    readonly property bool wanted: LiveWalls.on && !!fx && fx.alive && !Theme.hell && StreamMode.effectsOn(screenName)
    readonly property bool maskCurrent: maskImg.status === Image.Ready && maskUrl !== "" && maskImg.source.toString() === maskUrl
    readonly property bool ready: wanted && allowed && maskCurrent
    readonly property string maskUrl: {
        const i = LiveWalls.info(path);
        return i && i.mask ? "file://" + i.mask : "";
    }
    onPathChanged: LiveWalls.request(path)
    Component.onCompleted: LiveWalls.request(path)

    property real fade: ready ? 1 : 0
    Behavior on fade {
        enabled: root.allowed
        NumberAnimation {
            duration: 1400
            easing.type: Easing.InOutSine
        }
    }
    // another picture: off until its mask is there (no fading the old one's over it)
    visible: allowed && maskCurrent && fade > 0

    readonly property bool running: visible && !Shell.hiddenScreen(screenName)

    property real time: 0
    // Config.wallpaper.liveFps: 12 / 24 / 60 a second, or 0 — every frame of the screen
    Timer {
        interval: Math.round(1000 / Math.max(1, Config.wallpaper.liveFps))
        repeat: true
        running: Config.wallpaper.liveFps > 0 && root.running
        onTriggered: root.time += interval / 1000
    }
    FrameAnimation {
        running: Config.wallpaper.liveFps <= 0 && root.running
        onTriggered: root.time += Math.min(frameTime, 0.1)
    }

    // ---- the rare events ----
    readonly property var scene: info.scene || ({})
    // what the picture's author switched off for it (<name>.scene.json "effects", the scene editor)
    readonly property var off: info.effects || ({})
    function allowedFx(name) {
        return off[name] !== false;
    }
    readonly property var kinds: {
        const k = [];
        if ((scene.objects || 0) > 0 && allowedFx("glint"))
            k.push(1);
        if ((scene.rims || []).length > 0 && allowedFx("pebble"))
            k.push(2);
        if (fx && fx.water && Config.wallpaper.liveWater && allowedFx("gust"))
            k.push(3);
        // the Ophanim near (Uriel): an eye in a cloud at night, rings over the water
        if ((scene.eyes || []).length > 0 && night >= 0.5 && allowedFx("eye"))
            k.push(4);
        if (fx && fx.water && Config.wallpaper.liveWater && (scene.ponds || []).length > 0 && allowedFx("rings"))
            k.push(5);
        return k;
    }
    readonly property var lengths: [0, 5, 3, 6, 6, 6]
    property int last: 0
    property real event: 0
    property real eventStart: 0
    property real eventAge: event > 0 ? time - eventStart : 0
    property real eventSeed: 0
    property point eventAt: Qt.point(0.5, 0.5)
    property bool asked: false
    onTimeChanged: if (event > 0 && time - eventStart > lengths[event])
        event = 0
    function begin(want) {
        asked = false;
        if (!running || kinds.length === 0 || (want && !kinds.includes(want)))
            return;
        const pool = kinds.length > 1 ? kinds.filter(k => k !== last) : kinds;
        const k = want || pool[Math.floor(Math.random() * pool.length)];
        if (k === 2 || k === 4 || k === 5) {
            const list = k === 2 ? scene.rims : k === 4 ? scene.eyes : scene.ponds;
            const r = list[Math.floor(Math.random() * list.length)];
            eventAt = Qt.point(r[0], r[1]);
        }
        eventSeed = Math.random();
        eventStart = time;
        last = k;
        event = k;
    }
    Connections {
        target: LiveWalls
        function onPoke(kind) {
            root.begin(kind);
        }
    }
    Timer {
        id: nextEvent
        interval: 12000 + Math.random() * 23000
        repeat: true
        running: root.running && root.kinds.length > 0 && Config.wallpaper.liveEvents
        onTriggered: {
            interval = 12000 + Math.random() * 23000;
            if (root.event > 0 || root.asked)
                return;
            root.asked = true;
            if (Lyrics.playing)
                LiveBeat.next(root.begin);
            else
                root.begin();
        }
    }

    Image {
        id: maskImg
        source: root.maskUrl
        visible: false
        smooth: false
        mipmap: false
        cache: false
        asynchronous: true
    }

    readonly property var info: LiveWalls.info(path) || ({})
    property var source: picture
    property var mask: maskImg
    property real strength: Config.wallpaper.liveStrength / 100 * fade
    property real night: fx ? fx.night : 0
    property real axis: fx ? fx.axis : 0.65
    property real mirror: fx && fx.mirror ? 1 : 0
    property real skyMode: fx ? fx.skyMode : 2
    property real waterMode: fx ? fx.waterMode : 2
    property real stars: Config.wallpaper.liveStars && allowedFx("stars") ? 1 : 0
    property real meteors: Config.wallpaper.liveMeteors && allowedFx("meteors") ? 1 : 0
    property real water: Config.wallpaper.liveWater && allowedFx("water") ? 1 : 0
    property real lights: Config.wallpaper.liveLights && allowedFx("lights") ? 1 : 0
    property real pixelArt: info.pixelArt ? 1 : 0
    property real seed: screenName.length * 7.13
    property size resolution: Qt.size(width, height)
    property size imgSize: info.size ? Qt.size(info.size[0], info.size[1]) : Qt.size(width, height)
    property vector4d grid: info.grid ? Qt.vector4d(info.grid[0], info.grid[1], info.grid[2], info.grid[3]) : Qt.vector4d(1, 1, 0, 0)
    fragmentShader: Qt.resolvedUrl("../shaders/live_wall.frag.qsb")
}
