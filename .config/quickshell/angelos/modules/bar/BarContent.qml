import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Left / center / right sections from BarLayout. `inline` packs everything in one row (island,
// dock). Capsules: the full-width layout, each section as wide as it needs (the window draws
// a capsule behind each: leftBox / centerBox / rightBox give their places). In hell
// (BarLayout.hell) the widgets draw themselves in the circle's colours — the bar's roles
// (Theme.hellBar*, HellLook.barRoles): icons as outlines in one colour on one grid, a square
// cell each, a flat plate only while hovered or open (one height, one rule: BarItem,
// PxButton.barInk), the accent only for a state; app icons and plugins without a hell look
// of their own through the sprite ramp (HellBarTint) — and `hellPlates` tells the window's
// HellBarFrame where the runs of widgets are, so they sit on a calm plate and never on the
// pattern. Nothing is re-rendered as a whole: each widget repaints only itself. The dock
// stays as it is in hell.
Item {
    id: root

    required property string screenName
    required property var barWindow
    required property string style        // BarLayout.styles
    readonly property bool hug: style === "capsules"
    property bool compact: false
    property bool inline: false
    // a taskbar on the left or the right edge (BarLayout.vertical, like Windows 10): one column —
    // Start, the workspaces and the windows from the top, the rest (the centre's widgets
    // without the lyrics, then the right side's) at the bottom
    property bool vertical: false
    property int itemHeight: Theme.u * 15
    readonly property bool above: (style === "taskbar" && BarLayout.edge === "bottom") || style === "dock" || style === "windose"
    // the sections, for the capsules behind them (CapsuleWindow)
    readonly property alias leftBox: left
    readonly property alias centerBox: center
    readonly property alias rightBox: right
    readonly property bool hellInk: BarLayout.hell && style !== "dock"
    // where a section's widgets really are, in its own coordinates: [from, to] or null (a
    // stretched "Windows" counts as wide as its buttons)
    function usedRange(sec) {
        let a = Infinity, b = -Infinity;
        for (const c of sec.children) {
            if (c.wid === undefined || !c.visible || c.width <= 0)
                continue;
            if (vertical) {         // upright: the run from top to bottom
                const h = c.wid === "tasks" && c.item && c.item.naturalHeight !== undefined ? Math.min(c.height, c.item.naturalHeight) : c.height;
                if (h <= 0)
                    continue;
                a = Math.min(a, c.y);
                b = Math.max(b, c.y + h);
                continue;
            }
            const w = c.wid === "tasks" && c.item && c.item.naturalWidth !== undefined ? Math.min(c.width, c.item.naturalWidth) : c.width;
            if (w <= 0)
                continue;
            a = Math.min(a, c.x);
            b = Math.max(b, c.x + w);
        }
        return a < b ? [a, b] : null;
    }
    // the runs of widgets in hell, in this item's coordinates: [{x, y, w, h}]
    readonly property var hellPlates: {
        if (!hellInk)
            return [];
        const out = [];
        const pad = Theme.u * 2;
        const h = itemHeight + Theme.u * 2;
        const y = Math.round((height - h) / 2);
        const secs = inline ? [[inlineRow.children[0], inlineRow], [inlineRow.children[1], inlineRow], [inlineRow.children[2], inlineRow]] : vertical ? [[vTop, column], [vBottom, column]] : [[left, full], [center, full], [right, full]];
        for (const [sec, holder] of secs) {
            if (!sec || !sec.visible)
                continue;
            const r = usedRange(sec);
            if (!r)
                continue;
            if (vertical) {
                out.push({
                    "x": Theme.u,
                    "y": holder.y + sec.y + r[0] - pad,
                    "w": width - Theme.u * 2,
                    "h": r[1] - r[0] + pad * 2
                });
                continue;
            }
            const x0 = holder.x + sec.x + r[0] - pad;
            out.push({
                "x": x0,
                "y": y,
                "w": r[1] - r[0] + pad * 2,
                "h": h
            });
        }
        return out;
    }
    readonly property var layout: BarLayout.effective
    readonly property bool lyricsShown: BarLayout.has("lyrics") && Config.lyrics.enabled && Lyrics.visibleToggle && Lyrics.hasLyrics && (!Config.lyrics.screens.length || Config.lyrics.screens.includes(screenName))
    readonly property int gap: Theme.u * 4

    Component.onCompleted: Shell.barViews[screenName] = root
    Component.onDestruction: {
        if (Shell.barViews[screenName] === root)
            delete Shell.barViews[screenName];
    }
    // upright: the widgets shown, in this item's coordinates (the self-test's check of the column)
    function columnItems() {
        const out = [];
        for (const sec of [vTop, vBottom])
            for (const c of sec.children) {
                if (c.wid === undefined || !c.visible || c.width <= 0 || c.height <= 0)
                    continue;
                const p = c.mapToItem(root, 0, 0);
                out.push({
                    "wid": c.wid,
                    "x": p.x,
                    "y": p.y,
                    "w": c.width,
                    "h": c.height
                });
            }
        return out;
    }
    function diagnostics() {
        return {
            width: width,
            lyricsShown: lyricsShown,
            leftWidth: left.width,
            leftImplicit: left.implicitWidth,
            rightX: right.x,
            rightWidth: right.width,
            centerX: center.x,
            centerWidth: center.width,
            centerImplicit: center.implicitWidth,
            leftNeed: center.leftNeed,
            lyricsMax: center.lyricsMax
        };
    }
    implicitWidth: inline ? inlineRow.implicitWidth : 0
    implicitHeight: itemHeight

    // Behind the widgets: right-clicks on task buttons keep their own action.
    ContextClick {
        anchors.fill: parent
        onMenu: (x, y) => panelMenu.openAt(x, y)
    }
    PanelMenu {
        id: panelMenu
        anchorItem: root
        above: root.above
    }
    // Over the widgets: any press on the bar closes the open popup first (the
    // grab of an xdg popup does not end on clicks inside the same client), then
    // lets the press through to whatever is underneath.
    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            PopupManager.barPressed();
            mouse.accepted = false;
        }
    }

    // ---- inline (island) ----
    Row {
        id: inlineRow
        visible: root.inline
        anchors.centerIn: parent
        spacing: Theme.u * 5
        BarSection {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.layout.left.length > 0
            ids: root.inline ? root.layout.left : []
            bar: root
            centered: root.style === "dock"
            lyricsMax: root.compact ? Theme.u * 110 : Theme.u * 200
        }
        BarSection {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.layout.center.length > 0
            ids: root.inline ? root.layout.center : []
            bar: root
            centered: root.style === "dock"
            lyricsMax: root.compact ? Theme.u * 110 : Theme.u * 200
        }
        BarSection {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.layout.right.length > 0
            ids: root.inline ? root.layout.right : []
            bar: root
            centered: root.style === "dock"
            lyricsMax: root.compact ? Theme.u * 110 : Theme.u * 200
            density: Config.bar.rightDensity || "normal"
        }
    }

    // ---- upright (a taskbar on the left or the right edge) ----
    Item {
        id: column
        anchors.fill: parent
        visible: root.vertical && !root.inline
        // sunken Win98 notification area behind the bottom run, as across
        PxBox {
            visible: vBottom.implicitHeight > 0 && !root.hellInk
            x: Theme.u
            y: vBottom.y - Theme.u * 3
            width: parent.width - Theme.u * 2
            height: vBottom.height + Theme.u * 5
            sunken: true
            outline: false
            color: Qt.alpha(Theme.sunken, 0.35)
        }
        BarSection {
            id: vTop
            anchors.top: parent.top
            anchors.topMargin: Theme.u * 2
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: vBottom.top
            anchors.bottomMargin: root.gap + Theme.u * 3
            ids: root.vertical && !root.inline ? root.layout.left : []
            bar: root
            fillTasks: true
        }
        BarSection {
            id: vBottom
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.u * 2
            anchors.left: parent.left
            anchors.right: parent.right
            ids: root.vertical && !root.inline ? root.layout.center.filter(id => id !== "lyrics").concat(root.layout.right) : []
            bar: root
            density: Config.bar.rightDensity || "normal"
        }
    }

    // ---- full width (taskbar / top) ----
    Item {
        id: full
        anchors.fill: parent
        visible: !root.inline && !root.vertical

        readonly property bool tasksLeft: root.layout.left.includes("tasks")
        readonly property real mid: width / 2
        // Settings → Bar → Start → "Taskbar": like Windows 11, Start with the window buttons in
        // the middle (they slide there and back); the lyrics then take the room on the left
        readonly property bool centered: Config.bar.taskbarAlign === "center"

        // sunken Win98 notification area behind the right side of the taskbar
        PxBox {
            visible: (root.style === "taskbar") && right.implicitWidth > 0 && !root.hellInk
            x: right.x - Theme.u * 4
            width: right.width + Theme.u * 6
            height: root.itemHeight
            anchors.verticalCenter: parent.verticalCenter
            sunken: true
            outline: false
            color: Qt.alpha(Theme.sunken, 0.35)
        }

        BarSection {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 2
            anchors.verticalCenter: parent.verticalCenter
            ids: root.inline || root.vertical ? [] : root.layout.right
            bar: root
            lyricsMax: Theme.u * 150
            density: Config.bar.rightDensity || "normal"
        }

        BarSection {
            id: center
            anchors.verticalCenter: parent.verticalCenter
            x: parent.centered && !root.hug ? Theme.u * 2 : Math.round(Math.max(leftNeed, Math.min(parent.mid - width / 2, right.x - root.gap - width)))
            ids: root.inline || root.vertical ? [] : root.layout.center
            bar: root
            // widest centred run that still leaves room for the left side (+ a few task buttons) and the right side
            readonly property real leftNeed: Theme.u * 2 + left.implicitWidth + (parent.tasksLeft && !root.hug ? (root.compact ? Theme.u * 4 : Theme.u * 44) : 0) + root.gap + (root.hug ? Theme.u * 10 : 0)
            // the lyrics box takes the song's longest line, up to all the room between the sides
            // (centred taskbar: the room left of the centred group)
            lyricsMax: parent.centered && !root.hug ? Math.max(0, left.x - root.gap - Theme.u * 2 - (root.layout.center.length > 1 ? Theme.u * 60 : 0)) : Math.max(0, Math.min(parent.width * 0.6, right.x - root.gap - leftNeed - (root.hug ? Theme.u * 10 : 0) - (root.layout.center.length > 1 ? Theme.u * 60 : 0)))
        }

        BarSection {
            id: left
            anchors.verticalCenter: parent.verticalCenter
            // left: from the edge to the lyrics; centred: as wide as it needs, in the middle
            readonly property real room: right.x - root.gap - Theme.u * 2
            readonly property real centeredX: Math.round(Math.max(Theme.u * 2, Math.min((parent.width - width) / 2, right.x - root.gap - width)))
            x: parent.centered && !root.hug ? centeredX : Theme.u * 2
            width: parent.centered || root.hug ? Math.min(implicitWidth, room) : Math.max(implicitWidth, (center.implicitWidth > 0 && center.visible ? center.x : right.x - Theme.u * 6) - root.gap - x)
            ids: root.inline || root.vertical ? [] : root.layout.left
            bar: root
            fillTasks: !parent.centered && !root.hug
            centered: parent.centered || root.hug
            lyricsMax: Theme.u * 150
            // the Windows 11 slide when the alignment changes or a window button comes and goes
            Behavior on x {
                NumberAnimation {
                    duration: Motion.ms(320)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
