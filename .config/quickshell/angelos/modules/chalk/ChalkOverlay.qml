pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The chalk (services/Chalk): while its key is held, the mouse draws chalk over one screen,
// pixel by pixel on the shell's grid, no click needed. Let go and it melts: each step a part
// of it crumbles away and some of the rest runs a pixel down, then the overlay is gone. It
// takes the pointer only while drawing; melting, the clicks go through.
Scope {
    LazyLoader {
        active: Chalk.shown && !!Shell.screenByName(Chalk.screenName)

        PanelWindow {
            id: win
            screen: Shell.screenByName(Chalk.screenName)
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-chalk"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                item: Chalk.held ? area : null
            }

            // one chalk pixel; a stroke is two of them wide
            readonly property int cell: Math.max(2, Theme.u * 2)
            // the theme's, then pixel red, yellow, green, cyan, white; the wheel steps through them
            readonly property var inks: [String(Angel.demon ? Theme.hellAccent : Theme.accent), "#ff4d4d", "#ffd23f", "#5ce65c", "#4dc3ff", "#ffffff"]
            readonly property string ink: inks[Chalk.hue % inks.length]
            readonly property string grain: String(Qt.lighter(ink, 1.45))
            // "x,y" (in cells) → its colour: the stroke drawn now; the ones let go melt each on
            // its own clock ({cells, steps}), on while a new one is drawn
            property var cells: ({})
            property var melting: []
            property real wheelLeft: 0
            property var fresh: []
            property var last: null

            function dab(cx, cy) {
                for (let i = 0; i < 4; i++) {
                    const x = cx + (i & 1), y = cy + (i >> 1), k = x + "," + y;
                    if (cells[k])
                        continue;
                    cells[k] = Math.random() < 0.25 ? grain : ink;
                    fresh.push(k);
                }
            }
            function draw(px, py) {
                if (!Chalk.held)
                    return;
                const cx = Math.floor(px / cell), cy = Math.floor(py / cell);
                // the cells in between: a fast stroke stays whole
                const [x0, y0] = last || [cx, cy];
                const n = Math.max(Math.abs(cx - x0), Math.abs(cy - y0), 1);
                for (let i = 1; i <= n; i++)
                    dab(Math.round(x0 + (cx - x0) * i / n), Math.round(y0 + (cy - y0) * i / n));
                last = [cx, cy];
                canvas.requestPaint();
            }

            Connections {
                target: Chalk
                function onHeldChanged() {
                    win.last = null;
                    if (Chalk.held)
                        return;
                    win.melting.push({
                        "cells": win.cells,
                        "steps": 0
                    });
                    win.cells = {};
                    melt.running = true;
                }
            }

            RightClickGuard {}
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                onPositionChanged: m => win.draw(m.x, m.y)
                onExited: win.last = null
                // a notch (120) a colour, down the next one
                onWheel: w => {
                    win.wheelLeft += w.angleDelta.y;
                    const n = win.inks.length;
                    while (Math.abs(win.wheelLeft) >= 120) {
                        Chalk.hue = (Chalk.hue + (win.wheelLeft < 0 ? 1 : n - 1)) % n;
                        win.wheelLeft -= Math.sign(win.wheelLeft) * 120;
                    }
                }
            }

            Canvas {
                id: canvas
                anchors.fill: parent
                property bool full: false
                onPaint: {
                    const ctx = getContext("2d");
                    const c = win.cell;
                    const layers = full ? win.melting.map(b => b.cells).concat([win.cells]) : [win.cells];
                    if (full)
                        ctx.clearRect(0, 0, width, height);
                    for (const cells of layers) {
                        for (const k of full ? Object.keys(cells) : win.fresh) {
                            const v = cells[k];
                            if (!v)
                                continue;
                            const [x, y] = k.split(",");
                            ctx.fillStyle = v;
                            ctx.fillRect(x * c, y * c, c, c);
                        }
                    }
                    win.fresh = [];
                    full = false;
                }
            }

            // the chalk's tip beside the pointer, in its colour: the wheel's choice seen before a stroke
            Rectangle {
                visible: Chalk.held && area.containsMouse
                x: Math.floor(area.mouseX / win.cell) * win.cell + win.cell * 2
                y: Math.floor(area.mouseY / win.cell) * win.cell + win.cell * 2
                width: win.cell * 2
                height: win.cell * 2
                color: win.ink
                border.width: Math.max(1, win.cell / 2)
                border.color: "#000000"
            }

            // melting: a step every 80 ms; a tenth crumbles, a sixth of the rest runs a cell
            // down; after 3 s whatever is left goes at once
            Timer {
                id: melt
                interval: 80
                repeat: true
                onTriggered: {
                    win.melting = win.melting.map(b => {
                        const next = {};
                        for (const k in b.cells) {
                            const r = Math.random();
                            if (r < 0.1)
                                continue;
                            const [x, y] = k.split(",").map(Number);
                            const down = x + "," + (y + 1);
                            next[r < 0.27 && !b.cells[down] && !next[down] ? down : k] = b.cells[k];
                        }
                        return {
                            "cells": next,
                            "steps": b.steps + 1
                        };
                    }).filter(b => b.steps <= 37 && Object.keys(b.cells).length > 0);
                    if (win.melting.length === 0) {
                        running = false;
                        // drawing again meanwhile: the overlay stays for the new stroke
                        if (!Chalk.held) {
                            Chalk.shown = false;
                            return;
                        }
                    }
                    canvas.full = true;
                    canvas.requestPaint();
                }
            }
        }
    }
}
