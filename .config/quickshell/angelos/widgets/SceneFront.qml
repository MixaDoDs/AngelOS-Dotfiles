pragma ComponentBehavior: Bound

import QtQuick

// The nearer layers of a layered scene (SceneWall) once more, over something put between its
// layers that is drawn above the wall (a desktop widget, Background): only the layers nearer
// than `plane` and only inside `area` (the wall's px), the very pixels the wall draws there.
Item {
    id: root

    property Item wall: null
    property rect area
    property real plane: Infinity
    // the wall the layers are drawn from: kept while it goes away (a transition hides the scene,
    // and the layers are not gone yet when `wall` is null already)
    property Item drawn: null
    onWallChanged: if (wall)
        drawn = wall

    // the area on the canvas, art px: only the layers that reach into it are drawn
    readonly property var art: wall ? [(area.x - wall.ox) / wall.k, (area.y - wall.oy) / wall.k, (area.x + area.width - wall.ox) / wall.k, (area.y + area.height - wall.oy) / wall.k] : [0, 0, 0, 0]
    readonly property var nearer: !wall || plane === Infinity ? [] : wall.layers.filter(l => {
        const b = l.bounds_logical || [0, 0, wall.cw, wall.ch];
        // room for the warp and the parallax (SceneLayer's pad)
        const p = 6;
        return l.z > plane && b[0] - p < art[2] && b[2] + p > art[0] && b[1] - p < art[3] && b[3] + p > art[1];
    })

    visible: !!drawn && nearer.length > 0
    x: area.x
    y: area.y
    width: area.width
    height: area.height
    clip: true

    Item {
        x: -root.area.x
        y: -root.area.y
        Repeater {
            model: root.nearer
            SceneLayer {
                wall: root.drawn
            }
        }
    }
}
