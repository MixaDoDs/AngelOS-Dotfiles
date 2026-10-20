pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// One level of a pixel menu (PxMenu's own, a PxMenuSub's): the look's frame (services/MenuLook),
// an optional title, the rows of `items`, room for a menu's own parts above (`header`) and
// below (`footer`) the rows, and the keyboard — the same in every menu:
// ↑↓ go round, → opens a submenu, ← goes back, Enter/Space choose, Esc closes this level,
// a letter jumps to the next entry starting with it. Rows taller than `maxHeight` scroll.
Item {
    id: list

    property var menu: null                 // the PxMenu it belongs to
    property int level: 0                   // 0: the menu itself, 1… its submenus
    property var items: []                  // see PxMenu for the entry schema
    property string title: ""
    property string look: "classic"
    // what PxMenuItems inside take their colours from (MenuLook.tokensFor), plugins' rows too
    readonly property var menuTokens: MenuLook.tokens(look)
    readonly property var t: menuTokens
    property int minWidth: MenuLook.minWidth
    property int maxWidth: MenuLook.maxWidth
    property int maxHeight: 0               // the level's height at most (0: no limit): its rows scroll
    property bool icons: true
    property int current: -1                // the lit entry: the keyboard's, or the one under the pointer
    property alias header: headCol.data
    property alias footer: footCol.data
    readonly property alias frame: frame

    width: frame.width
    height: frame.height
    focus: true
    // entries swapped while open (a menu whose entries come late, the tray's): the lit one stays lit
    property var shown: []
    onItemsChanged: {
        const was = current >= 0 ? shown[current] : null;
        shown = items;
        current = was ? find(was) : -1;
    }
    // where entry `e` is now: the same object, else the first with its label (-1: gone)
    function find(e) {
        const n = items ? items.length : 0;
        for (let i = 0; i < n; i++)
            if (items[i] === e)
                return i;
        const l = e && !e.separator ? String(e.label || "") : "";
        for (let i = 0; l !== "" && i < n; i++)
            if (!items[i].separator && String(items[i].label || "") === l)
                return i;
        return -1;
    }
    // the keyboard's entry scrolled into view
    function select(i) {
        current = i;
        const r = rows.itemAt(i), f = scroll.flick;
        if (!r || !scroll.overflows)
            return;
        if (r.y < f.contentY)
            f.contentY = r.y;
        else if (r.y + r.height > f.contentY + f.height)
            f.contentY = r.y + r.height - f.height;
    }

    function need(c) {
        return c.visible === false ? 0 : c.implicitWidth || 0;
    }
    function rowAt(i) {
        return rows.itemAt(i);
    }
    function usable(i) {
        const it = items[i], r = rows.itemAt(i);
        return !!it && !it.separator && MenuLook.on(it.enabled, true) && !!r && r.visible;
    }
    // the next usable entry from `current` (none: from the top or the bottom), round
    function step(dir) {
        const n = items.length;
        let i = current < 0 ? (dir > 0 ? -1 : n) : current;
        for (let k = 0; k < n; k++) {
            i = ((i + dir) % n + n) % n;
            if (usable(i))
                return i;
        }
        return current;
    }
    function jump(ch) {
        const n = items.length, c = String(ch).toLowerCase();
        for (let k = 1; k <= n; k++) {
            const i = ((current + k) % n + n) % n;
            if (usable(i) && String(items[i].label || "").trim().toLowerCase().startsWith(c))
                return i;
        }
        return -1;
    }

    Keys.onPressed: e => {
        if (!menu)
            return;
        const k = e.key;
        e.accepted = true;
        if (k === Qt.Key_Down || k === Qt.Key_Up)
            select(step(k === Qt.Key_Down ? 1 : -1));
        else if (k === Qt.Key_Right) {
            if (current >= 0 && MenuLook.hasKids(items[current]))
                menu.activate(list, current, true);
        } else if (k === Qt.Key_Left) {
            if (level > 0)
                menu.collapse(level);
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            if (current >= 0)
                menu.activate(list, current, true);
        } else if (k === Qt.Key_Escape) {
            if (level > 0)
                menu.collapse(level);
            else
                menu.close();
        } else if (e.text.length === 1 && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            const i = jump(e.text);
            if (i >= 0)
                select(i);
        } else {
            e.accepted = false;
        }
    }

    // a little pop as it opens (the desktop's: Settings → Right-click menu → Animation)
    function popNow() {
        popAnim.restart();
    }
    transformOrigin: Item.TopLeft
    scale: popAnim.running ? popAnim.v : 1
    NumberAnimation {
        id: popAnim
        property real v: 1
        target: popAnim
        property: "v"
        from: 0.92
        to: 1
        duration: Motion.ms(120)
        easing.type: Easing.OutCubic
    }

    PxBox {
        id: frame
        readonly property real natural: Math.max(list.minWidth, titleNeed, ...rowCol.children.map(list.need), ...headCol.children.map(list.need), ...footCol.children.map(list.need))
        readonly property real titleNeed: list.title === "" ? 0 : list.t.head === "bar" ? barText.implicitWidth + (badge.visible ? badge.implicitWidth + Theme.u * 12 : Theme.u * 8) : list.t.head === "ink" ? inkText.implicitWidth + Theme.u * (list.t.pad + 20) : plainText.implicitWidth + Theme.u * 8
        // the scroll bar's room on top of the widest row
        width: Math.min(list.maxWidth, Math.ceil(natural)) + inset * 2 + (scroll.barVisible ? Theme.u * 11 : 0)
        height: col.implicitHeight + inset * 2
        // everything but the rows: what a limited height leaves them
        readonly property real chrome: (plainText.visible ? plainText.height : 0) + (barHead.visible ? barHead.height : 0) + (inkHead.visible ? inkHead.height : 0) + headCol.height + footCol.height + col.topPadding + col.bottomPadding + inset * 2
        hell: list.t.hellBox
        color: list.t.face
        outline: list.t.outline
        flat: list.t.flat
        hiColor: list.t.hi
        loColor: list.t.lo
        edgeColor: list.t.edge
        shadow: Config.appearance.shadows && list.t.shadow
        shadowColor: list.t.shadowColor
        shadowSize: Theme.u * list.t.shadowU

        // Y2K gloss: the chrome bubble instead of the bevelled box
        Y2kGloss {
            visible: !!list.t.y2k
            anchors.fill: parent
            z: -1
            sparkles: list.level === 0
        }
        // the sticker: the notebook's squares and its red margin
        Image {
            visible: !!list.t.grid
            anchors.fill: parent
            fillMode: Image.Tile
            smooth: false
            source: list.t.grid ? MenuLook.gridTile(Theme.u * list.t.gridCell, list.t.grid) : ""
        }
        Rectangle {
            visible: !!list.t.margin
            x: Theme.u * (list.t.pad + 14)
            y: headCol.height > 0 ? headCol.y + headCol.height : 0
            width: Theme.u
            height: parent.height - y
            color: list.t.margin || "transparent"
        }

        Column {
            id: col
            width: parent.width
            topPadding: list.t.y2k && list.level > 0 ? Theme.u * 4 : 0
            bottomPadding: list.t.y2k ? Theme.u * (list.level > 0 ? 2 : 3) : 0

            // the title: small and dim (classic), the accent bar (save), ink underlined in red (sticker)
            PxText {
                id: plainText
                visible: list.title !== "" && list.t.head === "plain"
                x: Theme.u * 4
                topPadding: Theme.u * 2
                bottomPadding: Theme.u
                width: col.width - Theme.u * 8
                elide: Text.ElideRight
                kind: "tiny"
                dim: true
                color: list.t.headText
                text: list.title
            }
            Item {
                id: barHead
                visible: list.title !== "" && list.t.head === "bar"
                width: col.width
                height: bar.height + Theme.u * 2
                Rectangle {
                    id: bar
                    width: parent.width
                    height: barText.implicitHeight + Theme.u * 4
                    color: list.t.headBg
                    PxText {
                        id: barText
                        x: Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - (badge.visible ? badge.implicitWidth + Theme.u * 8 : Theme.u * 4)
                        elide: Text.ElideRight
                        kind: "tiny"
                        font.bold: true
                        color: list.t.headText
                        text: list.t.caps ? list.title.toUpperCase() : list.title
                    }
                    PxText {
                        id: badge
                        visible: list.t.badge !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "tiny"
                        color: list.t.headText
                        text: list.t.badge
                    }
                }
            }
            Item {
                id: inkHead
                visible: list.title !== "" && list.t.head === "ink"
                width: col.width
                height: inkText.implicitHeight + Theme.u * 6
                PxText {
                    id: inkText
                    x: Theme.u * (list.t.pad + 16)
                    y: Theme.u * 2
                    width: parent.width - x - Theme.u * 4
                    elide: Text.ElideRight
                    font.bold: true
                    color: list.t.headText
                    text: list.title
                }
                Row {
                    x: inkText.x
                    y: inkText.y + inkText.implicitHeight + Theme.u
                    spacing: Theme.u
                    Repeater {
                        model: Math.max(0, Math.floor(Math.min(inkText.implicitWidth, inkText.width) / (Theme.u * 2)))
                        Rectangle {
                            width: Theme.u
                            height: Theme.u
                            color: list.t.margin || list.t.headText
                        }
                    }
                }
            }

            // the menu's own parts over the rows (the desktop's quick tiles)
            Column {
                id: headCol
                width: parent.width
            }
            PxScroll {
                id: scroll
                width: parent.width
                height: list.maxHeight > 0 ? Math.min(rowCol.implicitHeight, Math.max(Theme.u * 24, list.maxHeight - Math.ceil(frame.chrome))) : rowCol.implicitHeight
                contentHeight: rowCol.implicitHeight
                trackColor: list.t.face
                handleColor: list.t.dim
                // a submenu hangs where its entry was: it closes when the rows move
                Connections {
                    target: scroll.flick
                    function onContentYChanged() {
                        if (list.menu)
                            list.menu.collapse(list.level + 1);
                    }
                }

                Column {
                    id: rowCol
                    width: scroll.flick.width
                    Repeater {
                        id: rows
                        model: list.items
                        PxMenuItem {
                            required property var modelData
                            required property int index
                            separator: !!modelData.separator
                            text: modelData.label || ""
                            icon: list.icons ? (modelData.icon || "") : ""
                            hint: modelData.hint || ""
                            keys: modelData.keys || ""
                            submenu: MenuLook.hasKids(modelData)
                            checkable: !!modelData.checkable
                            // a function is read live: the tick follows the setting while open (issue #5)
                            checked: typeof modelData.checked === "function" ? !!modelData.checked() : !!modelData.checked
                            enabled: MenuLook.on(modelData.enabled, true)
                            hoverLights: false
                            highlighted: list.current === index
                            onHoveredChanged: if (hovered && list.menu)
                                list.menu.rowHovered(list, index)
                            onTriggered: if (list.menu)
                                list.menu.activate(list, index, false)
                        }
                    }
                }
            }
            // …and under them (plugins' QML entries)
            Column {
                id: footCol
                width: parent.width
            }
        }
    }
}
