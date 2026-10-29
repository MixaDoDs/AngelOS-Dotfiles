pragma ComponentBehavior: Bound

import QtQuick

// The night's event in a layered scene (widgets/SceneWall, scene.json "night" → "event"): a
// meteor that comes near for forty minutes, growing along its path, then a dome of fire rising
// behind the scene's houses and dying down. Drawn at the event's depth (between the clouds and
// the houses), so the nearer layers cover it and it shows only in the sky; sprites nearest, at
// art pixels, faded by dithering. The meteor is light added (black is nothing), the fire is over.
Item {
    id: ev

    required property Item wall
    readonly property var info: wall.nightEventInfo
    readonly property real age: wall.eventAge
    // the sky it can be in, art px: from left of the impact to the right edge, the top down to it
    readonly property var r: info ? [Math.max(0, info.fire.origin[0] - 120), 0, wall.cw, Math.min(wall.ch, info.fire.origin[1] + 12)] : [0, 0, 1, 1]
    readonly property bool coming: wall.eventOn && age < 0
    readonly property bool burning: wall.eventOn && age >= 0 && wall.fireFade > 0

    // the meteor's head along its path (scene.json: three points, the bend at 52 %)
    readonly property real q: coming ? (age + 2400) / 2400 : 0
    readonly property point head: {
        if (!info)
            return Qt.point(0, 0);
        const p = info.meteor.path;
        const a = q < 0.52 ? p[0] : p[1], b = q < 0.52 ? p[1] : p[2];
        const u = q < 0.52 ? q / 0.52 : (q - 0.52) / 0.48;
        // whole art pixels: it creeps a pixel at a time, never shimmers between two
        return Qt.point(Math.round(a[0] + (b[0] - a[0]) * u), Math.round(a[1] + (b[1] - a[1]) * u));
    }

    visible: info !== null && (coming || burning)
    z: info ? info.z : 0
    x: wall.ox + r[0] * wall.k
    y: wall.oy + r[1] * wall.k
    width: (r[2] - r[0]) * wall.k
    height: (r[3] - r[1]) * wall.k

    Image {
        id: meteorImg
        source: ev.info ? "file://" + ev.wall.dir + "/logical/" + ev.info.meteor.file : ""
        smooth: false
        visible: false
    }
    Image {
        id: fireImg
        source: ev.info ? "file://" + ev.wall.dir + "/logical/" + ev.info.fire.file : ""
        smooth: false
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        visible: meteorImg.status === Image.Ready && fireImg.status === Image.Ready
        property var meteor: meteorImg
        property var fire: fireImg
        property size canvas: Qt.size(ev.wall.cw, ev.wall.ch)
        property point origin: Qt.point(ev.r[0], ev.r[1])
        property size area: Qt.size(ev.r[2] - ev.r[0], ev.r[3] - ev.r[1])
        property point pan: ev.wall.panShift
        property real night: ev.wall.nightMix
        property point head: ev.head
        property point headIn: ev.info ? Qt.point(ev.info.meteor.head[0], ev.info.meteor.head[1]) : Qt.point(0, 0)
        property size meteorSize: Qt.size(meteorImg.implicitWidth, meteorImg.implicitHeight)
        property real meteorScale: ev.info ? ev.info.meteor.scale[0] + (ev.info.meteor.scale[1] - ev.info.meteor.scale[0]) * ev.wall.smooth(ev.q) : 1
        // it comes out of the dark over the first minutes
        property real meteorAlpha: ev.coming ? ev.wall.smooth(ev.q / 0.12) : 0
        property point fireOrigin: ev.info ? Qt.point(ev.info.fire.origin[0], ev.info.fire.origin[1]) : Qt.point(0, 0)
        property size fireSize: Qt.size(fireImg.implicitWidth, fireImg.implicitHeight)
        property real fireScale: ev.info ? (ev.info.fire.scale || 0.65) * (0.08 + 1.5 * ev.wall.fireRise) : 1
        // whole while it burns, a fire either is or is not; dithered away as it dies down
        property real fireAlpha: ev.burning ? ev.wall.fireFade : 0
        // another colour tonight: the sprites' lightness through its ramp (SceneWall.fire)
        property real tint: ev.wall.fire ? 1 : 0
        property color deep: ev.wall.fire ? ev.wall.fire[0] : "black"
        property color mid: ev.wall.fire ? ev.wall.fire[1] : "black"
        property color hot: ev.wall.fire ? ev.wall.fire[2] : "black"
        fragmentShader: Qt.resolvedUrl("../shaders/scene_event.frag.qsb")
    }
}
