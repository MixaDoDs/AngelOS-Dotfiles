import QtQuick

// One piece the meteor's blast throws (widgets/SceneAftermath): out of the fire, along a real
// ballistic arc seen through the scene's camera (scene.json "night" → "throw": the horizon, the
// focal length, how deep the fire is, the wall of the house in front of it), to where it lands
// and comes to rest. Far off it is a speck; it grows as it comes near, and the last of the arc is
// quick, as it is with anything coming at you. Behind the house's wall while it is deeper than
// it (it comes over the roof, not out of the bricks); in front of everything once nearer; at its
// own depth for its last few pixels down. On the ground it thuds (a big one, in dust), hops once
// or bounces twice and rolls a little (a small one), in a splash of sparks and earth. Then
// shaders/scene_shard.frag (or the pebble's dot) has it. All a function of the event's age.
ShaderEffect {
    id: fly

    required property Item wall
    required property var cam
    required property var fire          // [x, y]: the fire's foot on the canvas
    required property var rest          // [x, y]: where it lies at last (its bottom middle)
    required property real launch       // event age it is thrown
    required property real lands        // event age it touches down
    property real peak: 60              // where the top of its arc should be on the canvas, y
    property int hops: 1                // 0 a thud, 1 a hop, 2 two bounces and a roll
    property real roll: 0               // art px it rolls on after touching down
    property real heat0: 1              // 1 white-hot, less a dark stone glowing in its cracks
    property real spin: 7               // quarter turns a second
    property int sw: 0                  // its map's size; 0: a pebble, a speck of `speck` px
    property int sh: 0
    property real speck: 2
    property var mapItem: null
    property int restZ: 22
    property int nearZ: 95
    property var trail: ["#000000", "#000000", "#000000"]
    property var rocks: ["#000000", "#000000", "#000000", "#000000"]
    property color earth: "black"

    readonly property real age: wall.afterAge
    readonly property real hopFor: hops === 0 ? 0 : hops === 1 ? 0.3 : 0.5
    readonly property real since: age - lands
    readonly property bool flying: age >= launch && since < Math.max(0.9, hopFor)
    // where it touches down: short of its rest by its roll, the way it flies
    readonly property real way: rest[0] >= fire[0] ? 1 : -1
    readonly property var to: [rest[0] - way * roll, rest[1]]

    // ---- the camera: art px on the canvas ⇄ the world (units of the camera's height over the
    // ground, depth along the view) ----
    readonly property real cx: wall.cw / 2
    readonly property real f: cam.focal
    readonly property real hz: cam.horizon
    function ground(x, y) {
        const z = f / Math.max(1, y - hz);
        return [(x - cx) * z / f, 0, z];
    }
    function screen(w) {
        return [cx + f * w[0] / w[2], hz - f * (w[1] - 1) / w[2]];
    }
    function world(a, v) {
        return [eW[0] + (pW[0] - eW[0]) * v, eW[1] + (pW[1] - eW[1]) * v + 4 * a * v * (1 - v), eW[2] + (pW[2] - eW[2]) * v];
    }
    readonly property var eW: [(fire[0] - cx) * cam.depth / f, 1 + (hz - fire[1]) * cam.depth / f, cam.depth]
    readonly property var pW: ground(to[0], to[1])
    // how high it goes (units): its top near `peak` on the canvas, and over the roof (out of the
    // view) by the time it comes out in front of the house's wall
    readonly property real arcUp: {
        let best = 0.5;
        for (let a = 0.5; a < 400; a *= 1.12) {
            best = a;
            let top = 1e9, overWall = true;
            for (let i = 0; i <= 48; i++) {
                const w = world(a, i / 48);
                const s = screen(w);
                top = Math.min(top, s[1]);
                if (w[2] <= cam.wall[1] && s[0] < cam.wall[0] && s[1] > -2) {
                    const prev = world(a, (i - 1) / 48);
                    if (prev[2] > cam.wall[1])
                        overWall = false;
                }
            }
            if (top <= peak && overWall)
                break;
        }
        return best;
    }
    // the box it can draw in: its arc on the canvas and the splash round its landing
    readonly property int reach: 36
    readonly property var box: {
        let x0 = Math.min(to[0], rest[0]), x1 = Math.max(to[0], rest[0]), y0 = to[1];
        for (let i = 0; i <= 48; i++) {
            const s = screen(world(arcUp, i / 48));
            x0 = Math.min(x0, s[0]);
            x1 = Math.max(x1, s[0]);
            y0 = Math.min(y0, s[1]);
        }
        const m = Math.max(sw, sh, 2) + reach;
        return [Math.floor(Math.max(-12, x0 - m)), Math.floor(Math.max(-12, y0 - m)), Math.ceil(Math.min(wall.cw + 12, x1 + m)), Math.ceil(to[1] + 4)];
    }
    readonly property real u: Math.max(0, Math.min(1, (age - launch) / (lands - launch)))
    readonly property var nowW: world(arcUp, u)
    readonly property real nowY: screen(nowW)[1]

    visible: flying && (sw === 0 || (mapItem && mapItem.status === Image.Ready))
    // in front of everything once nearer than the house's wall, at its own depth near the ground
    z: since >= 0 || (nowW[2] <= cam.wall[1] && nowY > to[1] - 16) ? restZ : nowW[2] > cam.wall[1] ? Math.min(restZ, 22) : nearZ
    x: Math.round(wall.ox + (box[0] + wall.panShift.x) * wall.k)
    y: Math.round(wall.oy + (box[1] + wall.panShift.y) * wall.k)
    width: (box[2] - box[0]) * wall.k
    height: (box[3] - box[1]) * wall.k

    property point origin: Qt.point(box[0], box[1])
    property size area: Qt.size(box[2] - box[0], box[3] - box[1])
    property real centre: cx
    property real horizon: hz
    property real focal: f
    property vector3d from: Qt.vector3d(eW[0], eW[1], eW[2])
    property vector3d dest: Qt.vector3d(pW[0], pW[1], pW[2])
    property real arc: arcUp
    property point wallAt: Qt.point(cam.wall[0], cam.wall[1])
    property real progress: u
    property real tail: 0.022 / (lands - launch)
    property real turn: since < 0 ? Math.floor((lands - age) * spin) % 4 : since < hopFor ? Math.floor((hopFor - since) * 10) % 4 : 0
    property real hop: since >= 0 ? since : -1
    property real hopCount: hops
    property point restAt: Qt.point(rest[0], rest[1])
    property size size: Qt.size(sw, sh)
    property real speckSize: speck
    property real heat: heat0
    property color fire0: wall.flame[0]
    property color fire1: wall.flame[1]
    property color fire2: wall.flame[2]
    property color trail0: trail[0]
    property color trail1: trail[1]
    property color trail2: trail[2]
    property color rock0: rocks[0]
    property color rock1: rocks[1]
    property color rock2: rocks[2]
    property color rock3: rocks[3]
    property color ground0: earth
    // a pebble reads no map: any texture will do
    property var map: mapItem || wall.lightImage
    fragmentShader: Qt.resolvedUrl("../shaders/scene_flight.frag.qsb")
}
