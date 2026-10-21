pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// A flyout of the ring / pentagram menus: a column of pills bent along the circle next to
// the entry it came from — equal steps down, each pill touching `radius` (right of the
// middle for entries on the right, left otherwise), never closer than `reach`.
Item {
    id: root

    required property var menu              // RadialMenu
    property real radius: 100
    property real reach: 80
    property real angle: 0                  // where the entry sits
    property bool hell: false
    anchors.fill: parent

    readonly property real rowStep: Math.round(Theme.u * 14 * root.menu.k) + Theme.u * 2
    readonly property real margin: Theme.u * 2
    readonly property real fullHeight: root.menu.flyItems.length * rowStep
    function ensureIndex(index) {
        const rowTop = index * rowStep;
        const rowBottom = rowTop + rowStep;
        if (rowTop < viewport.contentY)
            viewport.contentY = rowTop;
        else if (rowBottom > viewport.contentY + viewport.height)
            viewport.contentY = rowBottom - viewport.height;
    }
    Flickable {
        id: viewport
        x: 0
        y: root.menu.clamp(root.menu.cy + Math.sin(root.angle) * root.radius - height / 2, root.margin, Math.max(root.margin, root.height - height - root.margin))
        width: root.width
        height: Math.max(0, Math.min(root.fullHeight, root.height - root.margin * 2))
        contentWidth: width
        contentHeight: Math.max(height, root.fullHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        WheelHandler {
            onWheel: event => {
                const dy = event.angleDelta.y || event.pixelDelta.y;
                viewport.contentY = Math.max(0, Math.min(viewport.contentHeight - viewport.height, viewport.contentY - dy));
                event.accepted = true;
            }
        }
        Connections {
            target: root.menu
            function onSubCurrentChanged() {
                if (root.menu.subCurrent >= 0)
                    root.ensureIndex(root.menu.subCurrent);
            }
        }
        Repeater {
            model: root.menu.flyItems
            Item {
                id: pill
                required property var modelData
                required property int index
                readonly property bool rightSide: Math.cos(root.angle) >= -0.05
                readonly property real step: root.rowStep
                readonly property real yy: index * step + step / 2
                readonly property real dy: viewport.y + yy - viewport.contentY - root.menu.cy
                readonly property real dx: Math.max(Math.sqrt(Math.max(0, root.radius * root.radius - dy * dy)), Math.abs(dy) < root.reach ? Math.sqrt(root.reach * root.reach - dy * dy) + Theme.u * 6 : 0)
                readonly property bool sel: root.menu.subCurrent === index
                readonly property bool checked: typeof modelData.checked === "function" ? !!modelData.checked() : !!modelData.checked
                x: root.menu.clamp(rightSide ? root.menu.cx + dx : root.menu.cx - dx - box.width, Theme.u * 2, root.width - box.width - Theme.u * 2)
                y: yy - box.height / 2
                width: box.width
                height: box.height
                // they fan out one after another
                property real shown: 0
                NumberAnimation on shown {
                    from: 0
                    to: 1
                    duration: Motion.ms(Config.desktop.menuAnim !== false ? 120 + pill.index * 20 : 1)
                }
                opacity: shown
                Rectangle {
                    id: box
                    width: pillRow.implicitWidth + Theme.u * 8
                    height: Math.round(Theme.u * 14 * root.menu.k)
                    radius: root.hell ? 0 : Theme.u * 2
                    color: root.hell ? (pill.sel || pillMouse.containsMouse ? Theme.hellFaceAlt : Qt.alpha(Theme.hellPlate, 0.96)) : (pill.sel || pillMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.4) : Qt.alpha(Theme.menuSurface, Math.max(0.9, Theme.panelAlpha)))
                    border.width: Math.max(1, Theme.u / 2)
                    border.color: root.hell ? (pill.sel || pillMouse.containsMouse ? Theme.hellAccent : Theme.hellRim) : Theme.menuBorder
                    opacity: pill.modelData.enabled === false ? 0.5 : 1
                    Row {
                        id: pillRow
                        x: Theme.u * 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.u * 3
                        PxIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!pill.modelData.icon || pill.modelData.checkable
                            name: pill.modelData.checkable ? (pill.checked ? "check" : "minus") : pill.modelData.icon || "heart"
                            ink: root.hell ? Theme.hellText : (Theme.dark ? Theme.text : Theme.edge)
                            fill: root.hell ? Theme.hellBlood : pill.checked ? Theme.ok : Theme.accent
                            fill2: root.hell ? Theme.hellRim : Theme.accent2
                            fill3: root.hell ? Theme.hellTextDim : Theme.accent3
                            body: root.hell ? Theme.hellFaceAlt : (Theme.dark ? Theme.faceAlt : Theme.sunken)
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.label(pill.modelData.label || "")
                            font.bold: pill.sel
                            color: root.hell ? Theme.hellText : Theme.text
                        }
                        PxText {
                            visible: !!pill.modelData.hint
                            anchors.verticalCenter: parent.verticalCenter
                            text: pill.modelData.hint || ""
                            kind: "tiny"
                            color: root.hell ? Theme.hellTextDim : Theme.textDim
                        }
                    }
                }
                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.menu.subCurrent = pill.index
                    onClicked: root.menu.activateSub(pill.index)
                }
            }
        }
    }
    // nothing in the flyout (no plugins with menu entries)
    Rectangle {
        visible: !!root.menu.fly && root.menu.flyItems.length === 0
        x: root.menu.cx + Math.cos(root.angle) * root.radius - width / 2
        y: root.menu.cy + Math.sin(root.angle) * root.radius - height / 2
        width: emptyText.implicitWidth + Theme.u * 8
        height: emptyText.implicitHeight + Theme.u * 4
        color: root.hell ? Theme.hellPlate : Qt.alpha(Theme.menuSurface, 0.92)
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.hell ? Theme.hellRim : Theme.menuBorder
        PxText {
            id: emptyText
            anchors.centerIn: parent
            kind: "tiny"
            color: root.hell ? Theme.hellTextDim : Theme.textDim
            text: I18n.t("пусто", "empty")
        }
    }
}
