pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// «Privacy ON» for the viewers, where a hidden window is. niri can only paint a hidden window
// black in the screencast (block-out-from); this window, as big as the streamed screen, draws a
// plate over each hidden window's place, and OBS lays it over the screen capture ("Window
// capture (PipeWire)" → "angelOS · Privacy для OBS", stretched over the whole screen, above
// it): the viewers see the plate, you see your window. Like the angel's window for OBS
// (StreamerCast) it is see-through on your own screens (its niri rule: opacity 0, rules.kdl;
// a window cast takes it as drawn), click-through, tucked into a corner of a screen nobody
// streams, kept out of the taskbar (Niri.plateWindowId).
//
// Where a window is on the screen: floating ones niri says; a tiled one only by its column, so
// the strip is worked out like niri lays it (center-focused-column "always": the active column
// in the middle, the others beside it with the gaps). With another centring and columns wider
// than the screen the place is not known: no plate there, the black stays.
Scope {
    id: root

    readonly property string output: (StreamMode.screens || [])[0] || ""
    readonly property var outScreen: Quickshell.screens.find(s => s.name === root.output) || null
    // open the whole time OBS runs, so OBS is pointed at it once and always has it
    readonly property bool wanted: Config.ready && Config.stream.privacyPlates && StreamMode.obsUp && !!outScreen && !Shell.dev

    // niri's layout settings (cfg/layout.kdl): the gaps and how the focused column is centred
    property int gaps: 16
    property string centering: "never"
    FileView {
        path: Config.home + "/.config/niri/cfg/layout.kdl"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            const g = t.match(/^\s*gaps\s+(\d+)/m);
            root.gaps = g ? parseInt(g[1]) : 16;
            const c = t.match(/^\s*center-focused-column\s+"(\w[\w-]*)"/m);
            root.centering = c ? c[1] : "never";
        }
    }

    readonly property var ws: Niri.allWorkspaces.find(w => w.output === root.output && w.is_active) || null
    readonly property var hiddenIds: Privacy.hiddenNow.map(a => a.id)
    // [{x, y, w, h}] in the streamed screen's logical pixels
    readonly property var rects: {
        if (!ws || !outScreen || hiddenIds.length === 0)
            return [];
        const W = outScreen.width, H = outScreen.height, g = gaps;
        const mine = Niri.windows.filter(w => w.workspace_id === ws.id && w.layout);
        const tiled = mine.filter(w => !w.is_floating && w.layout.pos_in_scrolling_layout);
        // the columns: their widths, and the tiles in each from the top
        const cols = {};
        for (const w of tiled) {
            const [c, r] = w.layout.pos_in_scrolling_layout;
            (cols[c] = cols[c] || []).push(w);
        }
        const keys = Object.keys(cols).map(Number).sort((a, b) => a - b);
        const width = {};
        let workH = 0;
        for (const c of keys) {
            cols[c].sort((a, b) => a.layout.pos_in_scrolling_layout[1] - b.layout.pos_in_scrolling_layout[1]);
            width[c] = Math.max(...cols[c].map(w => w.layout.tile_size[0]));
            workH = Math.max(workH, cols[c].reduce((s, w) => s + w.layout.tile_size[1], 0) + g * (cols[c].length + 1));
        }
        // the working area: the screen less the bar (a column fills it from top to bottom)
        workH = workH > 0 ? Math.min(H, workH) : H;
        const top = BarLayout.edge === "top" ? H - workH : 0;
        // where each column starts
        const x = {};
        const active = Niri.windows.find(w => w.id === ws.active_window_id && !w.is_floating && w.layout && w.layout.pos_in_scrolling_layout);
        const total = keys.reduce((s, c) => s + width[c] + g, g);
        if (keys.length && centering === "always" && active) {
            const a = active.layout.pos_in_scrolling_layout[0];
            x[a] = (W - width[a]) / 2;
            for (let i = keys.indexOf(a) - 1; i >= 0; i--)
                x[keys[i]] = x[keys[i + 1]] - g - width[keys[i]];
            for (let i = keys.indexOf(a) + 1; i < keys.length; i++)
                x[keys[i]] = x[keys[i - 1]] + width[keys[i - 1]] + g;
        } else if (keys.length && total <= W) {
            // everything fits: niri lays the strip from the left
            let at = g;
            for (const c of keys) {
                x[c] = at;
                at += width[c] + g;
            }
        }
        const out = [];
        for (const w of mine) {
            if (!hiddenIds.includes(w.app_id))
                continue;
            const L = w.layout, off = L.window_offset_in_tile || [0, 0];
            if (L.window_size[0] >= W && L.window_size[1] >= H) {
                out.push({"x": 0, "y": 0, "w": W, "h": H});            // fullscreen
            } else if (w.is_floating && L.tile_pos_in_workspace_view) {
                out.push({"x": L.tile_pos_in_workspace_view[0] + off[0], "y": top + L.tile_pos_in_workspace_view[1] + off[1], "w": L.window_size[0], "h": L.window_size[1]});
            } else if (L.pos_in_scrolling_layout && x[L.pos_in_scrolling_layout[0]] !== undefined) {
                const c = L.pos_in_scrolling_layout[0];
                let y = top + g;
                for (const t of cols[c]) {
                    if (t.id === w.id)
                        break;
                    y += t.layout.tile_size[1] + g;
                }
                out.push({"x": x[c] + off[0], "y": y + off[1], "w": L.window_size[0], "h": L.window_size[1]});
            }
        }
        return out.filter(r => r.x + r.w > 0 && r.x < W && r.y + r.h > 0 && r.y < H);
    }

    // where it lives: the active workspace of a screen nobody streams, tucked into a corner
    readonly property string home: {
        const off = Shell.screens.find(s => !StreamMode.onStream(s.name) && !(StreamMode.screens || []).includes(s.name));
        return off ? off.name : root.output;
    }
    readonly property var hostWs: Niri.allWorkspaces.find(w => w.output === root.home && w.is_active) || null
    readonly property bool astray: Niri.plateWindowId >= 0 && !!hostWs && Niri.plateWindowWs !== hostWs.id
    onAstrayChanged: if (astray)
        Niri.action("MoveWindowToWorkspace", {
            "window_id": Niri.plateWindowId,
            "reference": {
                "Id": root.hostWs.id
            },
            "focus": false
        })
    function tuck() {
        if (Niri.plateWindowId >= 0)
            Niri.action("MoveFloatingWindow", {
                "id": Niri.plateWindowId,
                "x": {
                    "SetFixed": -100000
                },
                "y": {
                    "SetFixed": 100000
                }
            });
    }
    Connections {
        target: Niri
        function onPlateWindowWsChanged() {
            if (Niri.plateWindowId >= 0 && !root.astray)
                tuckLater.restart();
        }
        function onPlateWindowIdChanged() {
            tuckLater.restart();
        }
    }
    Timer {
        id: tuckLater
        interval: 250
        onTriggered: root.tuck()
    }

    LazyLoader {
        active: root.wanted

        FloatingWindow {
            id: win
            title: Niri.plateTitle
            color: "transparent"
            mask: Region {}
            readonly property size fixed: Qt.size(root.outScreen ? root.outScreen.width : 1920, root.outScreen ? root.outScreen.height : 1080)
            implicitWidth: fixed.width
            implicitHeight: fixed.height
            minimumSize: fixed
            maximumSize: fixed

            Repeater {
                model: root.rects
                Item {
                    id: plate
                    required property var modelData
                    x: Math.round(modelData.x)
                    y: Math.round(modelData.y)
                    width: Math.round(modelData.w)
                    height: Math.round(modelData.h)
                    // the window's place, closed: the theme's own face with a pixel frame
                    PxBox {
                        anchors.fill: parent
                        color: Theme.desk
                        edgeColor: Theme.accent
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.u * 4
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "eye"
                            pixel: Math.max(2, Math.min(6, Math.floor(plate.height / 80)))
                            visible: plate.height > Theme.u * 40
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            kind: "title"
                            color: Theme.accent
                            text: "Privacy ON"
                        }
                    }
                }
            }

            RightClickGuard {}
        }
    }
}
