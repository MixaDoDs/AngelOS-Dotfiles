import QtQuick
import qs.services

// Where a desktop widget stands in a layered wallpaper (widgets/SceneWall), like the scene's
// depth text: between its layers, the nearer ones over it (Background: SceneFront), moving with
// the camera as the layer behind it does, its shadow on that layer. The depth is the widget's
// own (its menu → Depth, DesktopWidgets.depthOf): by itself the deepest at which the nearer
// layers cover a fifth of it at most, deeper (under half), just behind a thing of the scene
// (the bench, the TV: anything standing there), or over the wallpaper as before.
// While it is moved about (edit mode, a drag) it stands still in front of it all, and while
// its input copy is on show (the pointer on its buttons) it comes out from behind the leaves.
QtObject {
    id: root

    property Item host: null      // the face (DesktopWidgetHost)
    property Item wall: null      // the screen's SceneWall, null for any other wallpaper

    readonly property string mode: host ? DesktopWidgets.depthOf(host.widget) : "front"
    readonly property bool on: !!wall && !!host && mode !== "front"
    readonly property bool settled: !DesktopWidgets.editMode && !!host && !host.dragging
    // behind a thing: just under its z; a scene without that thing takes it by itself
    readonly property var thing: on && mode.startsWith("behind:") ? wall.layers.find(l => l.id === mode.slice(7)) || null : null
    readonly property real plane: !on ? Infinity : thing ? thing.z - 0.5 : wall.planeFor(Qt.rect(host.x, host.y, host.width, host.height), mode === "deep" ? 0.45 : 0.2)
    readonly property bool placed: on && plane !== Infinity
    readonly property point shift: {
        if (!placed || !settled)
            return Qt.point(0, 0);
        const s = wall.shiftAt(plane);
        return Qt.point(Math.round(s.x), Math.round(s.y));
    }
    readonly property bool covered: placed && settled && !(host.twin && host.twin.shown)
    // the shadow: the scene's darkest colour, a few art px down and to the right, past the
    // frame's own hard one, and a little away from the pointer as the camera moves
    readonly property bool shadowed: placed && host.visible && (host.mac || host.frameKind !== "none")
    readonly property point shadowOffset: wall ? Qt.point(Math.round((6 - 2 * wall.camera.x * wall.strength * (settled ? 1 : 0)) * wall.k), Math.round((8 - 2 * wall.camera.y * wall.strength * (settled ? 1 : 0)) * wall.k)) : Qt.point(0, 0)
    readonly property color shade: {
        const p = wall ? wall.palette : [];
        const c = p.reduce((a, c) => c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11 < a[0] * 0.3 + a[1] * 0.59 + a[2] * 0.11 ? c : a, p[0] || [0, 0, 0]);
        return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 0.32);
    }
}
