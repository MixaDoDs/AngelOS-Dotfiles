pragma ComponentBehavior: Bound

import QtQuick

// One layer of a layered scene (widgets/SceneWall), drawn at its place on the wall's canvas:
// its frame of the moment, its parallax, the puppet warp of a plant. A pure function of the
// wall's time and camera, so a second one (SceneFront, the scene's nearer layers over a desktop
// widget) draws the very same pixels.
Item {
    id: layer

    required property var modelData
    required property Item wall
    // bend by the kick's wave itself: the wall bends as a whole (WallpaperView), a SceneFront's
    // layers over a widget must bend alike on their own
    property bool wave: false
    readonly property var anim: modelData.animation || ({})
    readonly property real t: wall.time
    readonly property int frame: {
        if (!wall.moving)
            return 0;
        // a strong gust makes the CRT stutter
        if (anim.type === "frame_sequence")
            return Math.floor(t * (wall.pulse > 0.5 ? anim.fps * 3 : anim.fps)) % modelData.frames.length;
        // a glint held 0.7 s every 17 s, a different window each time; frame 0 is empty — the
        // sun's, so none at night
        if (anim.type === "glint")
            return wall.nightMix < 0.5 && t % 17 >= 12 && t % 17 < 12.7 ? 1 + (Math.floor(t / 17) * 3) % 7 : 0;
        return 0;
    }
    readonly property var par: modelData.parallax_max_logical || [0, 0]
    readonly property bool plant: anim.type === "wind"
    readonly property bool bends: plant && wall.moving && wall.flexReady
    // the layer's rectangle with room to move, on the canvas
    readonly property real pad: Math.ceil(Math.abs(par[0]) + Math.abs(par[1]) + wall.bend * 2.5 + 2)
    readonly property var b: modelData.bounds_logical || [0, 0, wall.cw, wall.ch]
    readonly property real x0: Math.max(0, b[0] - pad)
    readonly property real y0: Math.max(0, b[1] - pad)
    readonly property real x1: Math.min(wall.cw, b[2] + pad)
    readonly property real y1: Math.min(wall.ch, b[3] + pad)

    z: modelData.z
    x: wall.ox + x0 * wall.k
    y: wall.oy + y0 * wall.k
    width: (x1 - x0) * wall.k
    height: (y1 - y0) * wall.k

    Repeater {
        id: frames
        model: layer.modelData.frames
        Image {
            required property string modelData
            source: "file://" + wall.dir + "/logical/" + modelData
            smooth: false
            mipmap: false
            visible: false
        }
    }

    // the layer at night (scripts/scene-night.py), frame for frame; a layer that keeps its own
    // (the CRT's screen glows the same) or a scene without a night has none
    readonly property bool ownNight: wall.nightInfo !== null && !(wall.nightInfo.keep || []).includes(modelData.id) && modelData.id !== "windows"
    Repeater {
        id: nightFrames
        model: layer.ownNight ? layer.modelData.frames : []
        Image {
            required property string modelData
            source: "file://" + wall.dir + "/logical/" + wall.nightInfo.layers + modelData
            smooth: false
            mipmap: false
            visible: false
        }
    }

    // the layer at dusk or at dawn (scripts/scene-twilight.py), only while it shows
    readonly property bool ownTwilight: ownNight && wall.twilightInfo !== null && wall.twilightMix > 0 && wall.nightMix < 1
    Repeater {
        id: twilightFrames
        model: layer.ownTwilight ? layer.modelData.frames : []
        Image {
            required property string modelData
            source: "file://" + wall.dir + "/logical/" + wall.twilightInfo.layers + modelData
            smooth: false
            mipmap: false
            visible: false
        }
    }

    ShaderEffect {
        anchors.fill: parent
        property var source: frames.count > layer.frame ? frames.itemAt(layer.frame) : null
        property var nightSource: nightFrames.count > layer.frame && nightFrames.itemAt(layer.frame).status === Image.Ready ? nightFrames.itemAt(layer.frame) : source
        property real night: layer.ownNight || layer.modelData.role === "screen" ? wall.nightMix : 0
        readonly property bool twilightReady: twilightFrames.count > layer.frame && twilightFrames.itemAt(layer.frame).status === Image.Ready
        property var twilightSource: twilightReady ? twilightFrames.itemAt(layer.frame) : source
        property real twilight: twilightReady ? wall.twilightMix : 0
        property real glowNear: wall.glowNear
        property real glowBlast: wall.glowBlast
        property color nearColor: wall.nearColor
        property color blastColor: wall.blastColor
        property real screenHit: layer.modelData.role === "screen" ? wall.screenHit : 0
        property real kick: wall.kick
        property real kickAt: wall.kickAt
        property point kickFrom: wall.kickFrom
        property real wave: layer.wave ? 1 : 0
        property real flare: layer.modelData.role === "screen" ? 1 : 0
        property var light: wall.lightReady ? wall.lightImage : source
        property size canvas: Qt.size(wall.cw, wall.ch)
        property point origin: Qt.point(layer.x0, layer.y0)
        property size area: Qt.size(layer.x1 - layer.x0, layer.y1 - layer.y0)
        property point shift: layer.plant
            ? (layer.bends ? Qt.point(-wall.camera.x * wall.plantDepth.x * wall.depthGain * wall.strength, -wall.camera.y * wall.plantDepth.y * wall.depthGain * wall.strength) : Qt.point(0, 0))
            : wall.moving ? Qt.point(-wall.camera.x * layer.par[0] * wall.depthGain * wall.strength
                       // clouds lean the way the wind blows, as far as their room allows
                       + (layer.anim.type === "cloud_drift" ? layer.anim.amplitude * wall.strength * (0.6 * wall.windDir * Math.min(1, wall.wind * 1.5) + 0.4 * Math.sin(2 * Math.PI * layer.t / layer.anim.period)) : 0),
                       -wall.camera.y * layer.par[1] * wall.depthGain * wall.strength)
            : Qt.point(0, 0)
        property point pan: wall.panShift
        property real clampEdge: layer.modelData.edge_mode === "clamp" ? 1 : 0
        property real warp: layer.bends ? wall.bend * wall.strength : 0
        property real time: layer.t
        property real wind: wall.windNow
        property real windDir: wall.windDir
        property real pinned: layer.plant ? 1 : 0
        // any texture when there is none: nothing bends then
        property var flex: wall.flexReady ? wall.flexImage : source
        visible: source !== null
        fragmentShader: Qt.resolvedUrl("../shaders/scene_layer.frag.qsb")
    }
}
