pragma ComponentBehavior: Bound

import QtQuick

// What the night's event leaves behind (widgets/SceneWall, scene.json "night" → "debris"): the
// meteor does not fall for nothing. A column of smoke from where it fell, behind the houses,
// thinning and sinking back behind them within an hour and a half; stone shards that come down
// as sparks a few seconds after the impact, lie white-hot in the meteor's colour with their
// shadow and their glow on the ground, cool to glowing cracks and to the scene's own stone, and
// go one by one over the day (the last by evening); ash drifting down for the first hour. All a
// function of the event's age, so the debug timeline runs it too. The delegates sit among the
// scene's layers (a Repeater's items are the wall's children): the smoke in the sky, the shards
// on the ground behind the plants (their blades over them), on the bench in front of it, the ash
// in front of everything.
Repeater {
    id: after

    required property Item wall
    readonly property var info: wall.nightInfo
    readonly property real age: wall.afterAge
    readonly property bool on: wall.afterOn
    readonly property var debris: info && info.debris ? info.debris : []
    readonly property int ashCount: 24

    function smooth(x) {
        return wall.smooth(x);
    }
    // how much smoke and ash there is at the event's age
    // the smoke: full while the fire smoulders (20 min), then it thins, the wind takes it and it
    // sinks behind the houses it rose from — gone by an hour and a half (it lay there all morning)
    readonly property real smoke: !on ? 0 : smooth(age / 90) * (1 - smooth((age - 1200) / 4200))
    readonly property real smokeGoing: !on ? 0 : smooth((age - 1200) / 3600)
    readonly property real ash: !on ? 0 : smooth((age - 20) / 40) * (1 - smooth((age - 1200) / 4800))
    // the meteor's colours (SceneWall.fire: deep, mid, hot), embers' own for its own fire
    readonly property var fire: wall.fire || ["#8a1a0c", "#ff8a1e", "#fff0b0"]
    readonly property color ashColor: wall.paletteNear(0.5, 0.2)

    model: on ? 1 + debris.length + ashCount : 0

    Item {
        id: one
        required property int index
        readonly property string kind: index === 0 ? "smoke" : index <= after.debris.length ? "shard" : "ash"
        readonly property var d: kind === "shard" ? after.debris[index - 1] : null
        z: kind === "smoke" ? (after.info && after.info.event ? after.info.event.z : 15) : kind === "shard" ? d.z : 95
        anchors.fill: parent

        // ---- the smoke ----
        Loader {
            active: one.kind === "smoke" && after.smoke > 0 && !!after.info && !!after.info.event
            sourceComponent: ShaderEffect {
                readonly property var foot0: after.info && after.info.event ? after.info.event.fire.origin : [0, 0]
                x: after.wall.ox
                y: after.wall.oy
                width: after.wall.cw * after.wall.k
                height: (foot0[1] + 2) * after.wall.k
                property point origin: Qt.point(0, 0)
                property size area: Qt.size(after.wall.cw, foot0[1] + 2)
                property point pan: after.wall.panShift
                property point foot: Qt.point(foot0[0], foot0[1])
                property real strength: after.smoke
                property real rise: Math.min(foot0[1] + 30, 20 + after.age * 0.9) * (1 - after.smokeGoing)
                // out over the open sky (this scene's is to the right), the wind bends it more or less
                property real lean: 0.7 + 0.3 * after.wall.windDir * Math.min(1, after.wall.windNow) + 0.8 * after.smokeGoing
                property real time: after.wall.time
                property real glow: after.wall.fireFade * 0.9 + (after.age < 3600 ? 0.35 * (1 - after.age / 3600) : 0)
                // greys, lighter by day
                property color dark: after.wall.paletteNear(0.16 + 0.3 * (1 - after.wall.nightMix), 0.18)
                property color light: after.wall.paletteNear(0.26 + 0.4 * (1 - after.wall.nightMix), 0.18)
                property color glowColor: after.fire[1]
                fragmentShader: Qt.resolvedUrl("../shaders/scene_smoke.frag.qsb")
            }
        }

        // ---- a shard (scripts/scene-shards.py): it comes down as a spark for its last second and
        // a bit, lies where the scene has room for it (paving, in the grass under the scene's own
        // blades, on the bench's seat), white-hot → glowing cracks → the scene's stone, with its
        // shadow, its scorch and its glow on the ground (shaders/scene_shard.frag); it goes, dithered
        // away, over its last two minutes ----
        Loader {
            active: one.kind === "shard"
            sourceComponent: Item {
                id: shard
                readonly property var d: one.d
                readonly property real since: after.age - d.lands
                readonly property bool on: since > -1.2 && after.age < d.gone
                readonly property real fall: Math.max(0, -since)
                readonly property real heat: since < 0 ? 1 : Math.exp(-since / d.cools)
                // its colours flow from the day's into the night's with the scene
                function hue(key, i) {
                    const a = Qt.color(i === undefined ? d.day[key] : d.day[key][i]);
                    const b = Qt.color(i === undefined ? d.night[key] : d.night[key][i]);
                    const t = after.wall.nightMix;
                    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
                }
                readonly property int sw: d.size[0]
                readonly property int sh: d.size[1]
                // the box: the stone and the ground it touches (shadow, scorch, glow)
                readonly property int mx: Math.ceil(sw * 0.8 + 3)
                readonly property int my: Math.ceil(Math.max(2.5, sw * 0.22) + 2)
                readonly property int bx: d.at[0] - mx
                readonly property int by: d.at[1] - sh - 1
                Rectangle {
                    // the spark coming down at a slant
                    visible: shard.on && shard.fall > 0
                    x: Math.round(after.wall.ox + (shard.d.at[0] + after.wall.panShift.x - shard.fall * 18) * after.wall.k)
                    y: Math.round(after.wall.oy + (shard.d.at[1] - 2 + after.wall.panShift.y - shard.fall * 70) * after.wall.k)
                    width: Math.round(2 * after.wall.k)
                    height: Math.round(2 * after.wall.k)
                    color: after.fire[2]
                }
                Image {
                    id: map
                    visible: false
                    smooth: false
                    source: "file://" + after.wall.dir + "/logical/" + shard.d.map
                }
                ShaderEffect {
                    visible: shard.on && shard.fall <= 0 && map.status === Image.Ready
                    x: Math.round(after.wall.ox + (shard.bx + after.wall.panShift.x) * after.wall.k)
                    y: Math.round(after.wall.oy + (shard.by + after.wall.panShift.y) * after.wall.k)
                    width: (2 * shard.mx + 1) * after.wall.k
                    height: (shard.sh + 1 + shard.my) * after.wall.k
                    property point origin: Qt.point(shard.bx, shard.by)
                    property size area: Qt.size(2 * shard.mx + 1, shard.sh + 1 + shard.my)
                    property point at: Qt.point(shard.d.at[0], shard.d.at[1])
                    property size size: Qt.size(shard.sw, shard.sh)
                    property real heat: shard.heat
                    property real lean: (shard.d.lean || 0) * (1 - after.wall.nightMix)
                    property real scorch: after.smooth(shard.since / 90)
                    property real glowK: 0.2 + 0.4 * after.wall.nightMix
                    property real fade: after.smooth((after.age - shard.d.gone + 120) / 120)
                    property color rock0: shard.hue("rock", 0)
                    property color rock1: shard.hue("rock", 1)
                    property color rock2: shard.hue("rock", 2)
                    property color rock3: shard.hue("rock", 3)
                    property color fire0: after.fire[0]
                    property color fire1: after.fire[1]
                    property color fire2: after.fire[2]
                    property color shadow: shard.hue("shadow")
                    property color burnt: shard.hue("scorch")
                    property var map: map
                    fragmentShader: Qt.resolvedUrl("../shaders/scene_shard.frag.qsb")
                }
            }
        }

        // ---- ash: a slot with its own cycle, like the wind's leaves ----
        Loader {
            active: one.kind === "ash" && after.ash > 0
            sourceComponent: Rectangle {
                readonly property real life: 9 + 6 * after.wall.hash(one.index * 5.3 + 11)
                readonly property real cyc: (after.wall.time + after.wall.hash(one.index * 2.9 + 4) * life) / life
                readonly property real u: cyc - Math.floor(cyc)
                readonly property real ax: after.wall.hash(one.index * 3.3 + Math.floor(cyc)) * after.wall.cw + after.wall.windDir * 30 * u + 2 * Math.sin(u * 9 + one.index)
                readonly property real ay: u * after.wall.ch * 0.9
                visible: after.wall.hash(one.index * 7.1 + Math.floor(cyc) * 3.7) < after.ash
                x: Math.round(after.wall.ox + (ax + after.wall.panShift.x) * after.wall.k)
                y: Math.round(after.wall.oy + (ay + after.wall.panShift.y) * after.wall.k)
                width: Math.round(after.wall.k)
                height: Math.round(after.wall.k)
                color: after.ashColor
            }
        }
    }
}
