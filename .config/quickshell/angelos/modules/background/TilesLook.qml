pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The tiles look of RadialMenu, like a Control Center: a frosted panel next to the pointer
// with big square tiles; a flyout takes the panel's place as tiles of its own (toggles
// light up when on) with a "‹ back" tile first.
Item {
    id: look

    required property var menu
    readonly property real k: menu.k
    readonly property real reach: 0         // the panel places itself
    readonly property Item blurItem: panel
    readonly property real tile: Math.round(Theme.u * 34 * k)
    readonly property real gap: Theme.u * 3
    readonly property bool flying: menu.fly !== ""
    readonly property var list: flying ? menu.flyItems : menu.slots
    readonly property int count: list.length + (flying ? 1 : 0)
    readonly property real m: Theme.u * 3
    // no wider than the screen (a big UI on a small one), and a long flyout scrolls (below)
    readonly property var zone: menu.zone   // the bars' edges: the panel keeps off them
    readonly property int fitCols: Math.max(1, Math.floor((width - zone.left - zone.right - m * 4 + gap) / (tile + gap)))
    readonly property int cols: Math.min(fitCols, Math.max(3, Math.min(4, Math.ceil(Math.sqrt(count)))))
    // scroll the selected tile into view (the "‹ back" tile comes first in a flyout)
    function ensureIndex(i) {
        const top = Math.floor((i + (flying ? 1 : 0)) / cols) * (tile + gap);
        if (top < viewport.contentY)
            viewport.contentY = top;
        else if (top + tile > viewport.contentY + viewport.height)
            viewport.contentY = top + tile - viewport.height;
    }
    onFlyingChanged: {
        viewport.contentY = 0;
        // back from a flyout: the tile it opened from in sight again
        if (!flying)
            Qt.callLater(() => ensureIndex(menu.current));
    }
    function nav(e) {
        const n = list.length;
        let cur = flying ? menu.subCurrent : menu.current;
        let step = 0;
        if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)
            step = 1;
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab)
            step = -1;
        else if (e.key === Qt.Key_Down)
            step = cols;
        else if (e.key === Qt.Key_Up)
            step = -cols;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            if (flying && cur >= 0)
                menu.activateSub(cur);
            else if (!flying && cur >= 0)
                menu.activate(cur);
            return true;
        } else if (e.key === Qt.Key_Backspace && flying) {
            menu.fly = "";
            return true;
        } else {
            return false;
        }
        cur = cur < 0 ? 0 : Math.max(0, Math.min(n - 1, cur + step));
        if (flying)
            menu.subCurrent = cur;
        else
            menu.current = cur;
        ensureIndex(cur);
        return true;
    }
    anchors.fill: parent

    Rectangle {
        id: panel
        readonly property real m: look.m
        width: grid.width + m * 2
        height: head.height + viewport.height + m * 3
        // next to the pointer, turned to where there is room
        x: look.menu.clamp(look.menu.cx + width + m > look.width - look.zone.right ? look.menu.cx - width - Theme.u * 2 : look.menu.cx + Theme.u * 2, m + look.zone.left, look.width - width - m - look.zone.right)
        y: look.menu.clamp(look.menu.cy + height + m > look.height - look.zone.bottom ? look.menu.cy - height - Theme.u * 2 : look.menu.cy + Theme.u * 2, m + look.zone.top, look.height - height - m - look.zone.bottom)
        radius: Theme.u * 8
        color: Qt.alpha(Theme.menuSurface, Config.appearance.blur ? 0.78 : 0.97)
        border.width: Math.max(1, Theme.u / 2)
        border.color: Qt.alpha("#ffffff", Theme.dark ? 0.16 : 0.5)
        opacity: look.menu.reveal
        scale: 0.92 + 0.08 * look.menu.reveal
        transformOrigin: Item.TopLeft
        MouseArea {
            anchors.fill: parent
        }

        // header: the logo and the menu's name, or the flyout's with a way back
        Item {
            id: head
            x: panel.m
            y: panel.m
            width: grid.width
            height: Theme.u * 14
            AngelLogo {
                visible: !look.flying
                anchors.verticalCenter: parent.verticalCenter
                emblemOnly: true
                pixel: Math.max(1, Math.round(Theme.u / 2))
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                x: look.flying ? 0 : Theme.u * 14
                font.bold: true
                text: look.flying ? (DeskMenu.entry(look.menu.fly) || {}).label || "" : (look.menu.hoveredEntry ? look.menu.hoveredEntry.label : I18n.t("Рабочий стол", "Desktop"))
                elide: Text.ElideRight
                width: parent.width - x
            }
        }

        Flickable {
            id: viewport
            x: panel.m
            y: head.y + head.height + panel.m
            width: grid.width
            // the panel stays a margin off the screen's edges and the bars
            height: Math.max(0, Math.min(grid.height, look.height - look.zone.top - look.zone.bottom - head.height - panel.m * 5))
            contentWidth: grid.width
            contentHeight: grid.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: false
            WheelHandler {
                // a real wheel on Wayland may come as a non-mouse device: take any
                acceptedDevices: PointerDevice.AllDevices
                onWheel: event => {
                    const dy = event.angleDelta.y || event.pixelDelta.y;
                    viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height, viewport.contentY - dy));
                    event.accepted = true;
                }
            }

            Grid {
                id: grid
                columns: look.cols
                spacing: look.gap

                // back out of a flyout
                Rectangle {
                    visible: look.flying
                    width: look.tile
                    height: look.tile
                    radius: Theme.u * 6
                    color: backMouse.containsMouse ? Theme.mix(Theme.faceAlt, Theme.accent, 0.3) : Qt.alpha(Theme.faceAlt, 0.7)
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.u
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "arrowLeft"
                            pixel: look.k > 1.1 ? Theme.u * 2 : Theme.u
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            kind: "tiny"
                            text: I18n.t("Назад", "Back")
                        }
                    }
                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: look.menu.fly = ""
                    }
                }

                Repeater {
                    model: look.list
                    Rectangle {
                        id: t
                        required property var modelData
                        required property int index
                        // an entry id (main grid) or a flyout item
                        readonly property var e: look.flying ? null : DeskMenu.entry(modelData)
                        readonly property var item: look.flying ? modelData : null
                        readonly property bool sel: look.flying ? look.menu.subCurrent === index : look.menu.current === index
                        readonly property bool on: !!item && !!item.checkable && (typeof item.checked === "function" ? !!item.checked() : !!item.checked)
                        width: look.tile
                        height: look.tile
                        radius: Theme.u * 6
                        color: on ? Theme.accent : sel || tm.containsMouse ? Theme.mix(Theme.faceAlt, Theme.accent, 0.3) : Qt.alpha(Theme.faceAlt, 0.7)
                        border.width: sel ? Math.max(1, Theme.u / 2) : 0
                        border.color: Theme.accent
                        scale: tm.pressed ? 0.94 : 1
                        opacity: t.item && t.item.enabled === false ? 0.5 : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: Motion.ms(80)
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            width: parent.width - Theme.u * 4
                            spacing: Theme.u * 2
                            PxIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: t.item ? (t.item.checkable ? (t.on ? "check" : t.item.icon || "minus") : t.item.icon || "heart") : (t.e ? t.e.icon : "heart")
                                pixel: look.k > 1.1 ? Theme.u * 2 : Theme.u
                                ink: t.on ? Theme.selectText : (Theme.dark ? Theme.text : Theme.edge)
                                fill: t.on ? "#ffffff" : Theme.accent
                            }
                            PxText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                kind: "tiny"
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                color: t.on ? Theme.selectText : Theme.text
                                text: t.item ? I18n.label(t.item.label || "") : t.e ? (t.e.short || t.e.label) : ""
                            }
                        }
                        // a flyout: a corner mark
                        PxText {
                            visible: !!(t.e && t.e.flyout)
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.u * 2
                            kind: "tiny"
                            color: Theme.accent
                            text: "▸"
                        }
                        MouseArea {
                            id: tm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (look.flying)
                                    look.menu.subCurrent = t.index;
                                else
                                    look.menu.current = t.index;
                            }
                            onClicked: {
                                if (look.flying)
                                    look.menu.activateSub(t.index);
                                else
                                    look.menu.activate(t.index);
                            }
                        }
                    }
                }
            }
        }
    }
}
