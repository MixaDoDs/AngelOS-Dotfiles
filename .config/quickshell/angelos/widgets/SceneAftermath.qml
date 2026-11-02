pragma ComponentBehavior: Bound

import QtQuick

// What the night's event leaves behind (widgets/SceneWall, scene.json "night" → "debris"): the
// meteor does not fall for nothing. The blast's wave running through the yard as a sweep of
// embers; a column of smoke from where it fell, behind the houses, thinning and sinking back
// behind them within an hour and a half; stone shards thrown out of the fire that fly to the yard
// in arcs, hop where they land in a splash of sparks, lie white-hot in the meteor's colour with
// their shadow and their glow on the ground, cool to glowing cracks and to the scene's own stone,
// and go one by one over the day (the last by evening); ash drifting down for the first hour. All
// a function of the event's age, so the debug timeline runs it too. The delegates sit among the
// scene's layers (a Repeater's items are the wall's children): the smoke in the sky, the shards
// on the ground behind the plants (their blades over them), on the bench in front of it, in the
// air in front of everything, the embers and the ash in front of everything.
Repeater {
    id: after

    required property Item wall
    readonly property var info: wall.nightInfo
    readonly property real age: wall.afterAge
    readonly property bool on: wall.afterOn
    readonly property var debris: info && info.debris ? info.debris : []
    readonly property int ashCount: 24
    readonly property int emberCount: 110
    readonly property int pebbleCount: 18
    // the scene's camera for what the blast throws (scene.json "night" → "throw")
    readonly property var cam: info && info.throw ? info.throw : null
    // a dark stone's smoke, lighter to darker
    readonly property var smokes: [wall.paletteNear(0.36, 0.15), wall.paletteNear(0.26, 0.15), wall.paletteNear(0.17, 0.15)]

    function smooth(x) {
        return wall.smooth(x);
    }
    // how much smoke and ash there is at the event's age
    // the smoke: full while the fire smoulders (20 min), then it thins, the wind takes it and it
    // sinks behind the houses it rose from — gone by an hour and a half (it lay there all morning)
    // (it comes out of the fire once the fire is there, not with the impact)
    readonly property real smoke: !on ? 0 : smooth((age - 3) / 60) * (1 - smooth((age - 1200) / 4200))
    readonly property real smokeGoing: !on ? 0 : smooth((age - 1200) / 3600)
    readonly property real ash: !on ? 0 : smooth((age - 20) / 40) * (1 - smooth((age - 1200) / 4800))
    // the meteor's colours (SceneWall.flame: deep, mid, hot)
    readonly property var fire: wall.flame
    // the fire's foot, art px
    readonly property var foot: info && info.event ? info.event.fire.origin : [0, 0]
    readonly property color ashColor: wall.paletteNear(0.5, 0.2)

    model: on ? 1 + debris.length + ashCount + emberCount + pebbleCount : 0

    Item {
        id: one
        required property int index
        readonly property string kind: index === 0 ? "smoke" : index <= after.debris.length ? "shard" : index <= after.debris.length + after.ashCount ? "ash" : index <= after.debris.length + after.ashCount + after.emberCount ? "ember" : "pebble"
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
                property real rise: Math.min(foot0[1] + 30, 20 + Math.max(0, after.age - 3) * 0.9) * (1 - after.smokeGoing)
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

        // ---- a shard (scripts/scene-shards.py): thrown out of the fire with the flash, it flies
        // to the yard (widgets/SceneThrow: a speck out of the fire, over the house's roof, rushing
        // in, growing, tumbling, its tail of fire or smoke), lands its own way; it lies where the scene has room for it
        // (paving, in the grass under the scene's own blades, on the bench's seat), white-hot →
        // glowing cracks → the scene's stone, with its shadow, its scorch and its glow on the
        // ground (shaders/scene_shard.frag); it goes, dithered away, over its last two minutes ----
        Loader {
            active: one.kind === "shard"
            sourceComponent: Item {
                id: shard
                readonly property var d: one.d
                readonly property real since: after.age - d.lands
                readonly property real launch: 0.03 + 0.25 * after.wall.hash(one.index * 4.7 + 2)
                readonly property bool on: after.age >= launch && after.age < d.gone
                // each its own: a big one thuds down in dust, a middling one hops, a small one
                // bounces twice and rolls; some come white-hot, some dark, smoking, only their
                // cracks aglow
                readonly property int big: Math.max(d.size[0], d.size[1])
                readonly property int hops: d.on === "seat" ? 1 : big >= 17 ? 0 : big >= 14 ? 1 : 2
                readonly property real hopFor: hops === 0 ? 0 : hops === 1 ? 0.3 : 0.5
                readonly property real heat0: after.wall.hash(one.index * 6.1 + 3) < 0.35 ? 0.55 : 1
                readonly property real heat: since < 0 ? heat0 : heat0 * Math.exp(-since / d.cools)
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
                Image {
                    id: map
                    visible: false
                    smooth: false
                    source: "file://" + after.wall.dir + "/logical/" + shard.d.map
                }
                Loader {
                    active: !!after.cam && after.age < shard.d.lands + 1
                    sourceComponent: SceneThrow {
                        parent: after.wall
                        wall: after.wall
                        cam: after.cam
                        fire: after.foot
                        rest: shard.d.at
                        launch: shard.launch
                        lands: shard.d.lands
                        peak: 25 + 70 * after.wall.hash(one.index * 2.3 + 5)
                        hops: shard.hops
                        roll: shard.hops === 2 ? 7 : shard.hops === 1 && shard.d.on !== "seat" ? 3 : 0
                        heat0: shard.heat0
                        spin: 4 + 6 * after.wall.hash(one.index * 8.3 + 1)
                        sw: shard.sw
                        sh: shard.sh
                        mapItem: map
                        restZ: shard.d.z
                        trail: shard.heat0 > 0.8 ? [after.fire[2], after.fire[1], after.fire[0]] : after.smokes
                        rocks: [shard.hue("rock", 0), shard.hue("rock", 1), shard.hue("rock", 2), shard.hue("rock", 3)]
                        earth: shard.hue("ground")
                    }
                }
                ShaderEffect {
                    visible: shard.on && shard.since >= shard.hopFor && map.status === Image.Ready
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

        // ---- an ember of the blast's wave: it lights where the wave reaches (SceneWall.shockSpeed:
        // across the whole yard in a second and a half), is blown on away from the fire,
        // falls, cools and flickers out ----
        Loader {
            active: one.kind === "ember" && after.age < 6
            sourceComponent: Rectangle {
                readonly property int e: one.index - 1 - after.debris.length - after.ashCount
                function h(n) {
                    return after.wall.hash(e * 7.7 + n);
                }
                readonly property real x0: h(1) * after.wall.cw
                readonly property real y0: 20 + h(2) * after.wall.ch * 0.8
                readonly property real dx: x0 - after.foot[0]
                readonly property real dy: y0 - after.foot[1]
                readonly property real far: Math.max(1, Math.hypot(dx, dy))
                readonly property real born: far / after.wall.shockSpeed
                readonly property real life: 1 + 1.2 * h(3)
                readonly property real s: after.age - born
                readonly property real old: s / life
                readonly property real speed: 18 + 30 * h(4)
                readonly property real ex: x0 + dx / far * speed * s + after.wall.windDir * 6 * s
                readonly property real ey: y0 + dy / far * speed * s + 14 * s * s
                visible: s >= 0 && s < life && after.wall.hash(e * 3.1 + Math.floor(s * 20)) < 1 - after.smooth((old - 0.5) / 0.5)
                x: Math.round(after.wall.ox + (Math.round(ex) + after.wall.panShift.x) * after.wall.k)
                y: Math.round(after.wall.oy + (Math.round(ey) + after.wall.panShift.y) * after.wall.k)
                width: Math.round(after.wall.k)
                height: Math.round(after.wall.k)
                color: old < 0.25 ? after.fire[2] : old < 0.6 ? after.fire[1] : after.fire[0]
            }
        }

        // ---- a pebble: the blast throws them all round in the distance — specks out of the fire
        // that come down far off (some behind the trees), lie there glowing a while and go dark ----
        Loader {
            active: one.kind === "pebble" && !!after.cam && after.age < 1500
            sourceComponent: Item {
                id: peb
                readonly property int e: one.index - 1 - after.debris.length - after.ashCount - after.emberCount
                function h(n) {
                    return after.wall.hash(e * 9.1 + n * 1.3 + 40);
                }
                readonly property var rest: [Math.round(after.cam.wall[0] + 6 + h(1) * (after.wall.cw - after.cam.wall[0] - 10)), Math.round(after.cam.horizon + 4 + h(2) * h(2) * 44)]
                readonly property real launch: 0.02 + 0.3 * h(3)
                readonly property real lands: launch + 1 + 1.6 * h(4)
                readonly property real heat0: h(5) < 0.3 ? 0.6 : 1
                readonly property real speck: rest[1] - after.cam.horizon > 26 ? 2 : 1
                readonly property real since: after.age - lands
                readonly property real heat: heat0 * Math.exp(-Math.max(0, since) / (200 + 500 * h(6)))
                Loader {
                    active: after.age < peb.lands + 1
                    sourceComponent: SceneThrow {
                        parent: after.wall
                        wall: after.wall
                        cam: after.cam
                        fire: after.foot
                        rest: peb.rest
                        launch: peb.launch
                        lands: peb.lands
                        peak: after.foot[1] - 15 - 70 * peb.h(7)
                        hops: 0
                        heat0: peb.heat0
                        speck: peb.speck
                        nearZ: 22
                        trail: [after.fire[1], after.fire[0], after.fire[0]]
                        earth: after.wall.paletteNear(0.15, 0.2)
                    }
                }
                Rectangle {
                    parent: after.wall
                    z: 22
                    visible: peb.since >= 0 && peb.heat > 0.12
                    x: Math.round(after.wall.ox + (peb.rest[0] - Math.floor(peb.speck / 2) + after.wall.panShift.x) * after.wall.k)
                    y: Math.round(after.wall.oy + (peb.rest[1] - peb.speck + after.wall.panShift.y) * after.wall.k)
                    width: peb.speck * after.wall.k
                    height: peb.speck * after.wall.k
                    color: peb.heat > 0.7 ? after.fire[2] : peb.heat > 0.35 ? after.fire[1] : after.fire[0]
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
