pragma Singleton

import QtQuick
import Quickshell

// Snap Layouts and Snap Assist, as in Windows 11, on angel-niri's snap-window (the stacking mode).
// The green button's menu shows the screen's layouts (DesktopMenu → SnapLayouts): a part picked
// snaps the window there, then the rest of that layout offers the desk's other windows one part at
// a time (modules/snap/SnapAssistView); a window dragged to an edge or sent with Mod+arrows gets
// the same offer for what is left. Esc or a click beside it lets the offer go. Any window, its
// title bar ours or its own, dragged near the top of a screen brings the layouts down there
// (the snap bar, modules/snap/SnapBarView): let go on a part, it snaps there.
Singleton {
    id: root

    // each part as fractions of the room the parts divide: x, y, w, h (angel-niri's Snap::rect)
    readonly property var zones: ({
            "left": [0, 0, 1 / 2, 1],
            "right": [1 / 2, 0, 1 / 2, 1],
            "top": [0, 0, 1, 1 / 2],
            "bottom": [0, 1 / 2, 1, 1 / 2],
            "top-left": [0, 0, 1 / 2, 1 / 2],
            "top-right": [1 / 2, 0, 1 / 2, 1 / 2],
            "bottom-left": [0, 1 / 2, 1 / 2, 1 / 2],
            "bottom-right": [1 / 2, 1 / 2, 1 / 2, 1 / 2],
            "left-third": [0, 0, 1 / 3, 1],
            "middle-third": [1 / 3, 0, 1 / 3, 1],
            "right-third": [2 / 3, 0, 1 / 3, 1],
            "left-two-thirds": [0, 0, 2 / 3, 1],
            "right-two-thirds": [1 / 3, 0, 2 / 3, 1]
        })
    // the layouts of a wide screen and of one standing upright
    readonly property var wide: [["left", "right"], ["left-two-thirds", "right-third"], ["left-third", "middle-third", "right-third"], ["left", "top-right", "bottom-right"], ["top-left", "top-right", "bottom-left", "bottom-right"]]
    readonly property var tall: [["top", "bottom"], ["top-left", "top-right", "bottom-left", "bottom-right"]]
    function layoutsFor(screen) {
        return screen && screen.height > screen.width ? tall : wide;
    }
    // a part on screen: `area` [x, y, w, h] cut the way angel-niri cuts it (edges rounded)
    function rectOf(zone, area) {
        const f = zones[zone] || [0, 0, 1, 1];
        const x0 = Math.round(area[2] * f[0]), x1 = Math.round(area[2] * (f[0] + f[2]));
        const y0 = Math.round(area[3] * f[1]), y1 = Math.round(area[3] * (f[1] + f[3]));
        return Qt.rect(area[0] + x0, area[1] + y0, x1 - x0, y1 - y0);
    }

    // where each window sits snapped now: id → zone
    property var snaps: ({})
    // the layout being filled on each output: output → its parts
    property var filling: ({})
    // the snap bar: {id, output, pos} while a window is dragged near the top; let go there, the
    // bar takes it (barDropped) if it was over one of its parts
    property var bar: null
    signal barDropped(int id, string output, var pos)

    // the offer shown: {output, area, zone, wins}
    property var offer: null
    readonly property bool shown: offer !== null

    // the green menu's pick: the window to `zone` of `layout`, the rest offered after
    function snap(id, zone, layout, output) {
        const f = Object.assign({}, filling);
        f[output] = layout;
        filling = f;
        Niri.action("SnapWindow", {
            "id": id,
            "zone": zone
        });
    }
    function fill(w) {
        if (offer)
            Niri.action("SnapWindow", {
                "id": w.id,
                "zone": offer.zone
            });
    }
    function dismiss() {
        if (!offer)
            return;
        const f = Object.assign({}, filling);
        delete f[offer.output];
        filling = f;
        offer = null;
    }

    // the next part of the output's layout no window fills, and who could fill it
    function next(output, area) {
        const layout = filling[output];
        const ws = Niri.activeWorkspace(output);
        const here = !ws ? [] : Niri.windows.filter(w => w.workspace_id === ws.id && w.is_floating && !Minimize.isMinimized(w) && !Minimize.isAppHidden(w));
        const inLayout = w => layout.includes(snaps[w.id]);
        const free = layout.find(z => !here.some(w => snaps[w.id] === z));
        const wins = here.filter(w => !inLayout(w));
        if (!free || wins.length === 0) {
            offer = null;
            const f = Object.assign({}, filling);
            delete f[output];
            filling = f;
            return;
        }
        offer = {
            "output": output,
            "area": area,
            "zone": free,
            "wins": wins
        };
    }

    Connections {
        target: Niri
        function onWindowSnapped(id, output, zone, area) {
            const s = Object.assign({}, root.snaps);
            if (zone && zone !== "maximized")
                s[id] = zone;
            else
                delete s[id];
            root.snaps = s;
            if (!zone || zone === "maximized") {
                if (root.offer && root.offer.output === output)
                    root.dismiss();
                return;
            }
            // dragged to an edge, Mod+arrows: the first layout with that part
            let layout = root.filling[output];
            if (!layout || !layout.includes(zone)) {
                layout = root.layoutsFor(Shell.screenByName(output)).find(l => l.includes(zone)) || [zone];
                const f = Object.assign({}, root.filling);
                f[output] = layout;
                root.filling = f;
            }
            root.next(output, area);
        }
        function onWindowDraggedNearTop(id, output, pos, dropped) {
            if (dropped && pos)
                root.barDropped(id, output, pos);
            root.bar = pos && !dropped ? {
                "id": id,
                "output": output,
                "pos": pos
            } : null;
        }
        function onWindowClosed(id) {
            if (root.snaps[id] === undefined)
                return;
            const s = Object.assign({}, root.snaps);
            delete s[id];
            root.snaps = s;
        }
    }
}
