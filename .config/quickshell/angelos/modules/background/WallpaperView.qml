pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.desktop

// Two stacked images blended by the pixel transition shader.
Item {
    id: root

    required property string screenName
    readonly property var activeWs: Niri.activeWorkspace(screenName)
    readonly property string target: Wallpapers.resolve(screenName, activeWs ? activeWs.idx : 1)
    property string shown: ""
    // decoded at the screen's real pixels: Qt reads sourceSize as physical
    // pixels, so logical ones blur the picture on a scaled monitor (issue #18)
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    property real progress: 1
    // -1 = no transition; "random" picks again for every change
    property int styleIndex: Wallpapers.transitionIndex(Config.wallpaper.transition)
    readonly property bool verdict: styleIndex >= 0 && styleIndex === Wallpapers.transitionIndex("verdict")
    // the verdict's word: which way the change went (into hell or out of it), else down
    property bool wasHell: Wallpapers.hellOn
    property string verdictWord: ""
    // the layered scene on show (widgets/SceneWall), for the desktop widgets to stand in; else null
    readonly property Item sceneItem: sceneWall.covers ? sceneWall : null

    // the part of a scene's picture SceneWall shows (its canvas inside the margin), or null
    function sceneView(p) {
        const m = Wallpapers.sceneOf(p) ? Wallpapers.meta[p] : null;
        return m && m.w ? Qt.rect(sceneWall.margin, sceneWall.margin, m.w - 2 * sceneWall.margin, m.h - 2 * sceneWall.margin) : null;
    }
    // the codename of the release a scene came with (Pictures/AngelOS/NN-name/), else this one's
    function releaseName(folder) {
        const r = Wallpapers.releases.find(r => folder === r.dir || folder.startsWith(r.dir + "/")) || Updates.release;
        return r ? r.codename || "angelOS " + r.number : "";
    }
    function url(p) {
        // a scene with a night of its own, at night: the night's still, so the scene takes over
        // without a flash of day
        const d = Wallpapers.still(p, new Date());
        return d ? (d.startsWith("/") ? "file://" + d : d) : "";
    }
    function load(img, p) {
        img.path = p;
        img.source = url(p);
    }
    // the old picture is only needed while a transition runs
    function freeFrom() {
        fromImg.path = "";
        fromImg.source = "";
    }
    // a picture too big for Qt came back as a fitted copy: show that instead
    Connections {
        target: Wallpapers
        function onFittedChanged() {
            for (const img of [fromImg, toImg])
                if (Wallpapers.fitted[img.path])
                    img.source = root.url(img.path);
        }
    }

    // pixel transition only when the picture itself is changed (settings / IPC);
    // switching workspaces swaps instantly, even with per-workspace wallpapers
    readonly property string configKey: Wallpapers.stateKey
    property bool configChanged: false
    onConfigKeyChanged: configChanged = true

    function go(path) {
        styleIndex = Qt.binding(() => Wallpapers.transitionIndex(Config.wallpaper.transition));
        // another file of the same wallpaper (day ⇄ night, the screen turned): a change too
        const variant = Wallpapers.settled && Wallpapers.sameSet(shown, path);
        const animate = (configChanged || variant) && styleIndex >= 0 && Niri.ready && shown !== "" && !Motion.still;
        configChanged = false;
        // (local patch 56) a change while the gate runs (the day/night file resolved a moment
        // later, another pick) goes into the scene; once it covers the screen, under it at once
        if (gate.busy) {
            gate.path = path;
            if (gate.swapped) {
                shown = path;
                freeFrom();
                load(toImg, path);
                progress = 1;
            }
            return;
        }
        anim.stop();
        const t = Config.wallpaper.verdictTitle;
        verdictWord = t === "off" ? "" : t && t !== "auto" ? t : !Wallpapers.hellOn && wasHell ? "ASCEND" : "DESCEND";
        wasHell = Wallpapers.hellOn;
        // (local patch 56) Heaven's Gate: the scene freezes the screen first and the picture
        // changes under it (gate.onCovered); over a full-screen window, or with no frame in
        // time, the shader's cinema instead
        const st = Wallpapers.transitions[styleIndex];
        if (animate && st && st.scene) {
            if (!gateFailed && !Shell.fullscreenOn(screenName) && gate.start(path)) {
                Sounds.quietWallpaper(1500);
                return;
            }
            styleIndex = Wallpapers.transitionIndex("cinema");
        }
        gateFailed = false;
        if (!animate) {
            shown = path;
            freeFrom();
            load(toImg, path);
            progress = 1;
            return;
        }
        load(fromImg, shown);
        shown = path;
        load(toImg, path);
        progress = 0;
        if (toImg.status === Image.Ready)
            anim.start();
        else
            waitingForLoad = true;
    }
    property bool waitingForLoad: false
    property bool gateFailed: false

    GateScene {
        id: gate
        screenName: root.screenName
        // a newer change while the scene ran went its own way: this one is stale
        onCovered: path => {
            if (path !== root.target)
                return;
            anim.stop();
            root.shown = path;
            root.freeFrom();
            root.load(toImg, path);
            root.progress = 1;
        }
        onFailed: path => {
            if (path !== root.target)
                return;
            root.gateFailed = true;
            root.configChanged = true;
            root.go(path);
        }
    }

    // a change while a transition plays waits for its end: then only the latest one, if any
    onTargetChanged: if (target !== shown && !anim.running)
        Qt.callLater(() => go(target))
    Component.onCompleted: {
        shown = target;
        load(toImg, target);
        configChanged = false;
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Motion.ms(root.verdict ? 800 : Wallpapers.transitionMs(root.styleIndex))
        easing.type: Easing.Linear
        onFinished: {
            root.freeFrom();
            if (root.target !== root.shown)
                Qt.callLater(() => root.go(root.target));
        }
    }
    VerdictTitle {
        id: verdictTitle
        text: root.verdict ? root.verdictWord : ""
    }

    Image {
        id: fromImg
        property string path
        // a layered scene's still: its neutral frame, cut to the scene's view and drawn pixel
        // for pixel as SceneWall draws it, so the scene takes over without a jump
        readonly property var sceneRect: root.sceneView(path)
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: sceneRect ? undefined : Qt.size(Math.ceil(root.width * root.dpr), Math.ceil(root.height * root.dpr))
        sourceClipRect: sceneRect || Qt.rect(0, 0, 0, 0)
        asynchronous: true
        cache: true
        smooth: !sceneRect
        visible: false
        onStatusChanged: if (status === Image.Error)
            Wallpapers.fit(path)
    }
    Image {
        id: toImg
        property string path
        // a layered scene's still: its neutral frame, cut to the scene's view and drawn pixel
        // for pixel as SceneWall draws it, so the scene takes over without a jump
        readonly property var sceneRect: root.sceneView(path)
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: sceneRect ? undefined : Qt.size(Math.ceil(root.width * root.dpr), Math.ceil(root.height * root.dpr))
        sourceClipRect: sceneRect || Qt.rect(0, 0, 0, 0)
        asynchronous: true
        cache: true
        smooth: !sceneRect
        visible: false
        onStatusChanged: {
            if (status === Image.Error)
                Wallpapers.fit(path);
            else if (status === Image.Ready && root.waitingForLoad) {
                root.waitingForLoad = false;
                anim.start();
            }
        }
    }

    ShaderEffectSource {
        id: fromSrc
        textureSize: Qt.size(Math.ceil(root.width * root.dpr), Math.ceil(root.height * root.dpr))
        sourceItem: fromImg
        hideSource: true
        live: root.progress < 1
        visible: false
    }
    ShaderEffectSource {
        id: toSrc
        textureSize: Qt.size(Math.ceil(root.width * root.dpr), Math.ceil(root.height * root.dpr))
        sourceItem: toImg
        hideSource: true
        live: true
        visible: false
    }

    Item {
        anchors.fill: parent
        // in hell the circle lays its dark over the picture (HellLook.backdrop); heaven
        // draws the wallpaper untouched
        layer.enabled: Theme.hell
        layer.smooth: false
        layer.effect: ShaderEffect {
            readonly property var b: HellLook.backdrop || ({})
            property real dim: b.dim !== undefined ? b.dim : 0.5
            property real desat: b.desat !== undefined ? b.desat : 0.3
            property real vignette: b.vignette !== undefined ? b.vignette : 0.6
            property real cell: Theme.u * 2 * root.dpr
            property size resolution: Qt.size(root.width * root.dpr, root.height * root.dpr)
            property color tint: b.tint || Theme.hellBody
            // the circle's ambient (fog, rain, the Styx…), still but for the rare event
            readonly property var kinds: ["", "fog", "wind", "rain", "dust", "ripple", "embers", "sand", "pitch", "ice"]
            property real kind: Math.max(0, kinds.indexOf(HellLook.ambient))
            property real event: HellLook.eventTarget === -2 ? HellLook.event : 0
            property real phase: HellLook.eventTarget === -2 ? HellLook.phase : 0
            property real seed: root.screenName.length
            property color light: Theme.hellTextDim
            property color accent: Theme.hellAccent
            fragmentShader: Qt.resolvedUrl("../../shaders/hell_backdrop.frag.qsb")
        }

        // the transition, and at rest the still picture (p >= 1 draws just toTex) whenever
        // LiveWall doesn't cover it: live off, hell, no mask yet, nothing alive in the picture
        // (#98, #100). Off only under a drawn LiveWall: no second full-screen pass under it
        ShaderEffect {
            anchors.fill: parent
            visible: root.progress < 1 || !(live.visible || sceneWall.covers)
            property var fromTex: fromSrc
            property var toTex: toSrc
            property real progress: root.progress
            property real maxBlock: Config.wallpaper.maxBlock
            property real style: Math.max(0, root.styleIndex)
            property size resolution: Qt.size(width, height)
            property color accent: Theme.accent
            property size phys: Qt.size(Math.ceil(width * root.dpr), Math.ceil(height * root.dpr))
            property var titleTex: verdictTitle.texture
            property size titleSize: verdictTitle.size
            fragmentShader: Qt.resolvedUrl("../../shaders/pixel_transition.frag.qsb")
        }

        // the picture, half alive (stars, water): over it once a transition is over
        LiveWall {
            id: live
            anchors.fill: parent
            screenName: root.screenName
            path: Wallpapers.sceneOf(root.shown) ? "" : root.shown
            picture: toSrc
            allowed: root.progress >= 1 && !anim.running
            levels: hearing.item ? hearing.item.levels : []
        }
        // a layered scene (widgets/SceneWall: parallax, wind, frames) over its still once the
        // transition is over; still under Motion.still and with the stream's effects off
        SceneWall {
            id: sceneWall
            readonly property string folder: Wallpapers.sceneOf(root.shown)
            readonly property bool covers: visible && scene !== null
            anchors.fill: parent
            visible: folder !== "" && root.progress >= 1 && !anim.running && !Theme.hell
            dir: visible ? folder : ""
            still: Motion.still || !StreamMode.effectsOn(root.screenName)
            wind: SceneWind.strength
            windDir: SceneWind.dir
            pulse: SceneWind.pulse
            seed: SceneWind.seed
            // its night by the clock or its own pick (Settings → Wallpaper → Time of day), and
            // the night's event at four in the morning
            nightMix: Wallpapers.nightMix(root.shown, nightClock.date)
            twilightMix: Wallpapers.twilightMix(root.shown, nightClock.date)
            twilightKind: Wallpapers.twilightKind(nightClock.date)
            eventAge: Wallpapers.nightEvent(nightClock.date)
            variant: Wallpapers.nightVariant(nightClock.date)
            // the desk and the taskbar say where the pointer is; elsewhere the camera eases home
            pointer: Pointer.screen === root.screenName && Pointer.over
                ? Qt.point(Math.max(-1, Math.min(1, Pointer.x / Math.max(1, width) * 2 - 1)), Math.max(-1, Math.min(1, Pointer.y / Math.max(1, height) * 2 - 1)))
                : Qt.point(0, 0)

            // time on the desk's one clock like LiveWall (Config.wallpaper.liveFps, 24 on battery),
            // or every frame of the screen; stopped in a fullscreen app or a game; wrapped hourly:
            // float time in the shaders loses its fractions after days
            readonly property bool running: visible && !still && !Shell.stillScreen(root.screenName)
            readonly property bool timed: DeskClock.sceneFps > 0 && running
            property bool counted: false
            function count(on) {
                if (on === counted)
                    return;
                counted = on;
                DeskClock.walls += on ? 1 : -1;
            }
            function advance(dt) {
                time = (time + Math.min(dt, 0.1)) % 3600;
            }
            onTimedChanged: count(timed)
            Component.onDestruction: {
                count(false);
                listen(false);
            }

            // each kick of the music sends a wave through it (Settings → Wallpaper → Wallpaper sounds),
            // as strong as the player really plays (LyricsGlow.loud: its sound after its slider and
            // the master volume). Never through the night's event
            readonly property bool hearsBass: running && !eventOn && Wallpapers.own(folder, "sceneBass") === true
            property real kickGain: 0
            kick: hearsBass ? kickGain : 0
            Connections {
                target: Bass
                enabled: sceneWall.hearsBass
                function onKicked() {
                    sceneWall.kickAt = sceneWall.time;
                    sceneWall.kickGain = LyricsGlow.loud;
                }
            }
            property bool listening: false
            function listen(on) {
                if (on === listening)
                    return;
                listening = on;
                Bass.walls += on ? 1 : -1;
            }
            onHearsBassChanged: listen(hearsBass)
            Component.onCompleted: listen(hearsBass)
            // the wave bends all the wall draws at once: shards, the text, leaves (shaders/scene_kick)
            layer.enabled: hearsBass
            layer.smooth: false
            layer.effect: ShaderEffect {
                property size size: Qt.size(sceneWall.width, sceneWall.height)
                property point from: Qt.point(sceneWall.ox + sceneWall.kickFrom.x * sceneWall.k, sceneWall.oy + sceneWall.kickFrom.y * sceneWall.k)
                property real k: sceneWall.k
                property real kick: sceneWall.kick
                property real kickAt: sceneWall.kickAt
                property real time: sceneWall.time
                fragmentShader: Qt.resolvedUrl("../../shaders/scene_kick.frag.qsb")
            }
            Connections {
                target: DeskClock
                enabled: sceneWall.timed
                function onTick(dt) {
                    sceneWall.advance(dt);
                }
            }
            FrameAnimation {
                running: DeskClock.sceneFps <= 0 && sceneWall.running
                onTriggered: sceneWall.advance(frameTime)
            }

            // behind the nearer layers: the clock or the release's name (Settings → Wallpaper)
            depth: SceneDepthText {
                visible: text !== ""
                k: sceneWall.k
                palette: sceneWall.palette
                backdrop: sceneWall.depthBackdrop
                // the night has its own place for it: it fades out and in there, not jumps
                opacity: sceneWall.depthFade
                fixed: sceneWall.depthText || ({})
                look: Wallpapers.own(sceneWall.folder, "sceneDepthStyle")
                textured: Wallpapers.own(sceneWall.folder, "sceneDepthTexture")
                textureSource: sceneWall.depthTexture
                textureFrom: sceneWall.depthTextureFrom
                reflectionSource: sceneWall.depthReflection
                canvasSize: Qt.size(sceneWall.cw, sceneWall.ch)
                time: sceneWall.time
                text: Wallpapers.own(sceneWall.folder, "sceneDepth") === "clock" ? Qt.formatTime(clock.date, "hh:mm") : Wallpapers.own(sceneWall.folder, "sceneDepth") === "release" ? root.releaseName(sceneWall.folder) : ""
            }
            SystemClock {
                id: nightClock
                enabled: sceneWall.visible && Wallpapers.nightOf(root.shown) !== ""
                precision: SystemClock.Seconds
            }
            SystemClock {
                id: clock
                enabled: sceneWall.visible && Wallpapers.own(sceneWall.folder, "sceneDepth") === "clock"
                precision: SystemClock.Minutes
            }
        }
        // the cava behind the wallpaper's music lines: only while a picture with a place for
        // them is shown (MusicSpectrum: and only while music plays, and the desk is seen)
        Loader {
            id: hearing
            active: live.hearsMusic
            sourceComponent: MusicSpectrum {
                screenName: root.screenName
                widget: ({
                        "uid": "wall-" + root.screenName,
                        "settings": {
                            "bars": 16
                        }
                    })
                rows: 0
                mac: false
                opacity: 0                       // numbers only: the lines are the shader's
            }
        }
    }
}
