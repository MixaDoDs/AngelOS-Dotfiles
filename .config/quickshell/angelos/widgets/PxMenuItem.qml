import QtQuick
import qs.config
import qs.services
import "A11y.js" as A11y

// Menu row: icon + label (+ optional hint or shortcut / check mark / submenu arrow, or a few
// small `choices` buttons on the right instead: the desks 1 2 3 4). separator: true draws a
// line. It wears the colours of the menu it stands in (services/MenuLook: the nearest
// PxMenuList's tokens), classic outside one.
Item {
    id: root

    property string text: ""
    property string icon: ""
    property string hint: ""
    property var keys: ""                   // a shortcut, ["Mod", "T"] or "Mod+T": right-aligned, one format
    property bool separator: false
    property bool submenu: false
    property bool checked: false
    property bool checkable: false
    property bool highlighted: false        // keyboard selection
    property var choices: []                // [{label, checked}]: buttons on the right
    property int choice: Math.max(0, choices.findIndex(c => MenuLook.on(c.checked, false))) // the keyboard's one
    signal choiceTriggered(int index)
    property bool hoverLights: true         // false: only `highlighted` lights it (PxMenuList moves it with the pointer)
    property var tokens: MenuLook.tokensFor(root.parent)
    readonly property var t: tokens || MenuLook.plain
    property real iconScale: 1              // bigger or smaller icons (Start → Fine-tune → Icons)
    readonly property bool hovered: mouse.containsMouse
    readonly property bool lit: ((hoverLights && mouse.containsMouse) || highlighted) && enabled
    readonly property string keyText: MenuLook.keyText(keys)
    signal triggered

    Accessible.role: Accessible.MenuItem
    Accessible.name: A11y.name(text, root, icon)
    Accessible.description: keyText || hint
    Accessible.checkable: checkable
    Accessible.checked: checked
    Accessible.onPressAction: if (enabled)
        triggered()

    width: parent ? parent.width : implicitWidth
    implicitWidth: separator ? Theme.u * 20 : row.implicitWidth + (choiceRow.visible ? choiceRow.implicitWidth : side.implicitWidth) + Theme.u * (24 + root.t.pad - 5)
    implicitHeight: separator ? Theme.u * 5 : Theme.sizeBody + Theme.u * 8
    opacity: enabled ? 1 : 0.45

    Rectangle {
        visible: root.separator
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.u * 2
        width: parent.width - Theme.u * 4
        height: Math.max(1, Theme.u / 2)
        color: root.t.sepLo
        Rectangle {
            y: parent.height
            width: parent.width
            height: parent.height
            color: root.t.sepHi
        }
    }

    // the highlight
    Rectangle {
        visible: !root.separator
        anchors.fill: parent
        color: root.lit ? root.t.lit : "transparent"
    }

    Row {
        id: row
        visible: !root.separator
        anchors.left: parent.left
        anchors.leftMargin: Theme.u * root.t.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.u * 4
        Item {
            width: Math.round(Theme.u * 12 * root.iconScale)
            height: Math.round(Theme.u * 11 * root.iconScale)
            anchors.verticalCenter: parent.verticalCenter
            // the entry's own icon, checked or not: the tick goes on the right
            PxIcon {
                anchors.centerIn: parent
                exactPixel: root.iconScale !== 1 ? Theme.u * root.iconScale : 0
                visible: root.icon !== ""
                name: root.icon || "heart"
                ink: root.lit ? root.t.litInk : root.t.ink
            }
        }
        PxText {
            id: label
            text: root.text
            color: root.lit ? root.t.litText : root.t.text
            style: root.t.outlineText !== "transparent" ? Text.Outline : Text.Normal
            styleColor: root.t.outlineText
            anchors.verticalCenter: parent.verticalCenter
            // never under the hint (bigger fonts, a narrow menu): it elides instead
            width: Math.max(0, Math.min(implicitWidth, root.width - x - row.anchors.leftMargin - (choiceRow.visible ? choiceRow.implicitWidth + Theme.u * 9 : side.visible ? side.implicitWidth + Theme.u * 9 : Theme.u * 5)))
            elide: Text.ElideRight
        }
    }
    // the right side: the submenu's arrow, else a check-box entry's tick (room kept for it
    // unticked), else the shortcut or the hint
    Item {
        id: side
        readonly property bool tick: root.checkable && !root.submenu
        visible: !root.separator && !choiceRow.visible && (root.submenu || tick || hintText.text !== "")
        anchors.right: parent.right
        anchors.rightMargin: Theme.u * 5
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: tick ? check.width : hintText.implicitWidth
        implicitHeight: parent.height
        PxIcon {
            id: check
            visible: side.tick && root.checked
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            name: "check"
            ink: root.lit ? root.t.litInk : root.t.ink
        }
        PxText {
            id: hintText
            visible: !side.tick
            text: root.submenu ? "▸" : root.keyText || root.hint
            dim: !root.lit
            color: root.lit ? root.t.litText : root.t.dim
            style: root.t.outlineText !== "transparent" ? Text.Outline : Text.Normal
            styleColor: root.t.outlineText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // the choices: small boxes, the current one filled, the keyboard's one outlined
    Row {
        id: choiceRow
        visible: !root.separator && root.choices.length > 0
        anchors.right: parent.right
        anchors.rightMargin: Theme.u * 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.u
        z: 2
        Repeater {
            model: root.choices
            Rectangle {
                id: chip
                required property var modelData
                required property int index
                readonly property bool on: MenuLook.on(modelData.checked, false)
                width: Math.max(Theme.u * 9, chipText.implicitWidth + Theme.u * 4)
                height: Theme.u * 9
                color: on ? Theme.accent : chipMouse.containsMouse ? Qt.alpha(Theme.accent, 0.3) : Qt.alpha(root.t.lo, 0.5)
                border.width: root.highlighted && root.choice === index ? Theme.u : Math.max(1, Theme.u / 2)
                border.color: root.highlighted && root.choice === index ? root.t.litText : root.t.edge
                PxText {
                    id: chipText
                    anchors.centerIn: parent
                    kind: "tiny"
                    text: chip.modelData.label || ""
                    color: chip.on ? Theme.selectText : root.lit ? root.t.litText : root.t.text
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.choiceTriggered(chip.index)
                }
            }
        }
    }

    MouseArea {
        id: mouse
        visible: !root.separator
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
