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
// next kick of the bass (services/LiveBeat). An eye the author pointed at ("blink") blinks on
// its own slow clock. The author's other hints (snow, fireworks, a garland, CRT screens, smoke:
// info.extras) are drawn all the time; Motion.calm keeps the fireworks off and the rest gentler.
// Where the author marked an empty place for it ("music"), lines move with the music: `levels`,
// a cava spectrum the wallpaper's window runs while `hearsMusic` (modules/background/WallpaperView).
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

    readonly property bool running: visible && !Shell.stillScreen(screenName)

    property real time: 0
    // Config.wallpaper.liveFps: 12 / 24 / 60 a second, or 0 — every frame of the screen. On a
    // laptop's battery never more than 24: the scene shares its window with the desktop widgets,
    // so «Monitor» on a 144 Hz laptop redrew the wallpaper and every widget 144 times a second,
    // whatever was open over them (a sixth of a core and the GPU busy all day, #60) — the cap is
    // DeskClock.sceneFps, so on battery «Monitor» runs on the clock at 24 too.
    readonly property int fps: DeskClock.sceneFps
    // The timed ones tick on the desk's one clock (services/DeskClock), with a live music
    // spectrum in the same window at least its 30 (on battery 24 for both): one frame a tick
    // for both, not one for each
    readonly property bool timed: fps > 0 && running
    property bool counted: false
    onTimedChanged: count(timed)
    Component.onCompleted: {
        LiveWalls.request(path);
        count(timed);
    }
    Component.onDestruction: count(false)
    function count(on) {
        if (on === counted)
            return;
        counted = on;
        DeskClock.walls += on ? 1 : -1;
    }
    Connections {
        target: DeskClock
        enabled: root.timed
        function onTick(dt) {
            root.time += dt;
        }
    }
    FrameAnimation {
        running: root.fps <= 0 && root.running
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
        if (fx && fx.water && Wallpapers.own(root.path, "liveWater") && allowedFx("gust"))
            k.push(3);
        // the Ophanim near (Uriel): an eye in a cloud at night, rings over the water
        if ((scene.eyes || []).length > 0 && night >= 0.5 && allowedFx("eye"))
            k.push(4);
        if (fx && fx.water && Wallpapers.own(root.path, "liveWater") && (scene.ponds || []).length > 0 && allowedFx("rings"))
            k.push(5);
        return k;
    }
    readonly property var lengths: [0, 5, 3, 6, 6, 6, 1.2]
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
        // the blink (6) is never one of the random ones: its own clock, below
        const can = want === 6 ? !!extras.blink : kinds.length > 0 && (!want || kinds.includes(want));
        if (!running || !can)
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
        running: root.running && root.kinds.length > 0 && Wallpapers.own(root.path, "liveEvents")
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

    // the eye blinks rarely: 90–180 s apart, and not over another event
    Timer {
        interval: 90000 + Math.random() * 90000
        repeat: true
        running: root.running && !!root.extras.blink && Wallpapers.own(root.path, "liveEvents")
        onTriggered: {
            interval = 90000 + Math.random() * 90000;
            if (root.event === 0)
                root.begin(6);
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
    readonly property var extras: info.extras || ({})
    property var source: picture
    property var mask: maskImg
    property real strength: Wallpapers.own(root.path, "liveStrength") / 100 * fade
    property real night: fx ? fx.night : 0
    property real axis: fx ? fx.axis : 0.65
    property real mirror: fx && fx.mirror ? 1 : 0
    property real skyMode: fx ? fx.skyMode : 2
    property real waterMode: fx ? fx.waterMode : 2
    property real stars: Wallpapers.own(root.path, "liveStars") && allowedFx("stars") ? 1 : 0
    property real meteors: Wallpapers.own(root.path, "liveMeteors") && allowedFx("meteors") ? 1 : 0
    property real water: Wallpapers.own(root.path, "liveWater") && allowedFx("water") ? 1 : 0
    property real lights: Wallpapers.own(root.path, "liveLights") && allowedFx("lights") ? 1 : 0
    property real pixelArt: info.pixelArt ? 1 : 0
    property real seed: screenName.length * 7.13
    property size resolution: Qt.size(width, height)
    property size imgSize: info.size ? Qt.size(info.size[0], info.size[1]) : Qt.size(width, height)
    property vector4d grid: info.grid ? Qt.vector4d(info.grid[0], info.grid[1], info.grid[2], info.grid[3]) : Qt.vector4d(1, 1, 0, 0)
    // the author's hints (all 0 when there are none: the shader skips them)
    function rect(r) {
        return r ? Qt.vector4d(r[0], r[1], r[2], r[3]) : Qt.vector4d(0, 0, 0, 0);
    }
    readonly property var musicPlaces: allowedFx("music") ? extras.music || [] : []
    readonly property bool hearsMusic: visible && musicPlaces.length > 0
    property var levels: []
    property vector4d music0: rect(musicPlaces[0])
    property vector4d music1: rect(musicPlaces[1])
    property vector4d music2: rect(musicPlaces[2])
    // 16 bands, each easing towards cava's newest frame (tetoOS's 0.45), so the lines glide
    property var eased: []
    onLevelsChanged: {
        const src = levels || [];
        const next = [];
        for (let i = 0; i < 16; i++) {
            const v = src.length ? src[Math.min(src.length - 1, Math.floor(i * src.length / 16))] : 0;
            const was = eased[i] || 0;
            next.push(was + (v - was) * 0.45);
        }
        eased = next;
    }
    property vector4d bandsA: Qt.vector4d(eased[0] || 0, eased[1] || 0, eased[2] || 0, eased[3] || 0)
    property vector4d bandsB: Qt.vector4d(eased[4] || 0, eased[5] || 0, eased[6] || 0, eased[7] || 0)
    property vector4d bandsC: Qt.vector4d(eased[8] || 0, eased[9] || 0, eased[10] || 0, eased[11] || 0)
    property vector4d bandsD: Qt.vector4d(eased[12] || 0, eased[13] || 0, eased[14] || 0, eased[15] || 0)
    property real loud: (levels || []).length > 0 ? 1 : 0
    Behavior on loud {
        NumberAnimation {
            duration: 1200
            easing.type: Easing.InOutSine
        }
    }
    property vector4d lid: rect(extras.blink)
    // fireworks are flashes, however dim: none in calm
    property vector4d fireworks: Motion.calm ? rect(null) : rect((extras.fireworks || [])[0])
    property vector4d fireworks2: Motion.calm ? rect(null) : rect((extras.fireworks || [])[1])
    property vector4d smoke: extras.smoke ? Qt.vector4d(extras.smoke[0], extras.smoke[1], extras.smoke[2], 1) : Qt.vector4d(0, 0, 0, 0)
    property real snow: extras.snow || 0
    property real calm: Motion.calm ? 1 : 0
    fragmentShader: Qt.resolvedUrl("../shaders/live_wall.frag.qsb")
}
