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
    readonly property var anim: modelData.animation || ({})
    readonly property real t: wall.time
    readonly property int frame: {
        if (!wall.moving)
            return 0;
        // a strong gust makes the CRT stutter
        if (anim.type === "frame_sequence")
            return Math.floor(t * (wall.pulse > 0.5 ? anim.fps * 3 : anim.fps)) % modelData.frames.length;
        // a glint held 0.7 s every 17 s, a different window each time; frame 0 is empty
        if (anim.type === "glint")
            return t % 17 >= 12 && t % 17 < 12.7 ? 1 + (Math.floor(t / 17) * 3) % 7 : 0;
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

    ShaderEffect {
        anchors.fill: parent
        property var source: frames.count > layer.frame ? frames.itemAt(layer.frame) : null
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
