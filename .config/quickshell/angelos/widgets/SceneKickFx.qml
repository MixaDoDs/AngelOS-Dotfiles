pragma ComponentBehavior: Bound

import QtQuick

// The music's and the meteor's bend over a layered scene (shaders/scene_kick), as a `layer.effect`:
// on the wall itself (modules/background/WallpaperView, the wallpaper editor's picture) and, with
// `widgets`, on the desktop widgets, which feel the waves but not the swelling zones.
ShaderEffect {
    property Item wall: null
    property bool widgets: false

    function px(v, o) {
        const k = wall.k;
        return Qt.vector4d(o + v.x * k, o + v.y * k, o + v.z * k, o + v.w * k);
    }
    readonly property vector4d none: Qt.vector4d(0, 0, 0, 0)
    property size size: Qt.size(width, height)
    property vector4d kickX: wall ? px(wall.kicksX, wall.ox) : none
    property vector4d kickY: wall ? px(wall.kicksY, wall.oy) : none
    property vector4d kickRate: wall ? wall.kicksRate : Qt.vector4d(1, 1, 1, 1)
    property real k: wall ? wall.k : 1
    property real kick: wall ? wall.kick : 0
    property vector4d kickAt: wall ? wall.kicksAt : Qt.vector4d(-9, -9, -9, -9)
    property vector4d kickGain: !wall ? none : widgets ? wall.kicksOnWidgets : wall.kicksGain
    property real time: wall ? wall.time : 0
    property vector4d hype: wall ? wall.kicksHype : none
    property real blast: wall && wall.shockAge < 3 ? wall.shockAge : -1
    property point blastFrom: wall ? Qt.point(wall.ox + (wall.shockFrom.x + wall.panShift.x) * wall.k, wall.oy + (wall.shockFrom.y + wall.panShift.y) * wall.k) : Qt.point(0, 0)
    property real blastSpeed: wall ? wall.shockSpeed : 420
    property real edge: wall ? wall.edge : 0
    property real edgeAt: wall ? wall.snareAt : -1
    property real breath: wall ? wall.breath : 0
    property real zones: wall && !widgets && wall.modsOn && wall.zoneMods.length > 0 ? 1 : 0
    property vector4d zoneA: wall ? wall.zoneA : none
    property vector4d zoneB: wall ? wall.zoneB : none
    property vector4d zoneC: wall ? wall.zoneC : none
    property vector4d zoneD: wall ? wall.zoneD : none
    property vector4d zoneAt: wall ? wall.zonesAt : none
    property vector4d zoneGain: wall ? wall.zonesGain : none
    property vector4d zoneRelease: wall ? wall.zonesRelease : Qt.vector4d(1, 1, 1, 1)
    property real holdOn: wall && wall.holdReady ? 1 : 0
    property vector4d holdRect: wall ? Qt.vector4d(wall.ox + wall.panShift.x * wall.k, wall.oy + wall.panShift.y * wall.k, wall.cw * wall.k, wall.ch * wall.k) : Qt.vector4d(0, 0, 1, 1)
    property var hold: wall ? wall.holdImage : null
    fragmentShader: Qt.resolvedUrl("../shaders/scene_kick.frag.qsb")
}
