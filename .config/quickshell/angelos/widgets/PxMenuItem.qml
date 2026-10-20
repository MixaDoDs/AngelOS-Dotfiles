import QtQuick
import qs.config
import qs.services
import "A11y.js" as A11y

// Menu row: icon + label (+ optional hint or shortcut / check mark / submenu arrow).
// separator: true draws a line. It wears the look of the menu it stands in (services/MenuLook:
// the nearest PxMenuList's tokens), classic outside one.
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
    property bool hoverLights: true         // false: only `highlighted` lights it (PxMenuList moves it with the pointer)
    property var tokens: MenuLook.tokensFor(root.parent)
    readonly property var t: tokens || MenuLook.plain
    property string skin: t.y2k ? "y2k" : "" // "" | y2k (glossy pill highlight, rainbow lines)
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
    implicitWidth: separator ? Theme.u * 20 : row.implicitWidth + side.implicitWidth + Theme.u * (24 + root.t.pad - 5)
    implicitHeight: separator ? Theme.u * 5 : Theme.sizeBody + Theme.u * 8
    opacity: enabled ? 1 : 0.45

    // y2k: a rainbow line
    Rectangle {
        visible: root.separator && root.skin === "y2k"
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.u * 4
        width: parent.width - Theme.u * 8
        height: Math.max(1, Theme.u / 2)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: 0.2
                color: "#ff6fb0"
            }
            GradientStop {
                position: 0.5
                color: "#ffe066"
            }
            GradientStop {
                position: 0.8
                color: "#8fe3ff"
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
    Rectangle {
        visible: root.separator && root.skin !== "y2k"
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

    // the highlight: a fill (classic), a faint tint under a ► marker (save), a highlighter
    // stripe from the label on (sticker)
    Rectangle {
        visible: !root.separator && root.skin !== "y2k" && root.t.marker !== "stripe"
        anchors.fill: parent
        color: root.lit ? root.t.lit : "transparent"
    }
    PxIcon {
        visible: !root.separator && root.lit && root.t.marker === "arrow"
        x: Theme.u * 2
        anchors.verticalCenter: parent.verticalCenter
        bitmap: ["#..", "##.", "###", "##.", "#.."]
        ink: root.t.markerColor
    }
    Rectangle {
        visible: !root.separator && root.lit && root.t.marker === "stripe"
        x: row.x + label.x - Theme.u * 2
        y: Theme.u
        width: parent.width - x - Theme.u * 2
        height: parent.height - Theme.u * 2
        color: root.t.lit
    }
    // y2k: a glossy pill
    Rectangle {
        visible: !root.separator && root.skin === "y2k" && root.lit
        anchors.fill: parent
        anchors.leftMargin: Theme.u * 2
        anchors.rightMargin: Theme.u * 2
        anchors.topMargin: Theme.u / 2
        anchors.bottomMargin: Theme.u / 2
        radius: height / 2
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.mix(Theme.accent, "#ffffff", 0.45)
            }
            GradientStop {
                position: 0.5
                color: Theme.accent
            }
            GradientStop {
                position: 1
                color: Theme.mix(Theme.accent, Theme.edge, 0.2)
            }
        }
        border.width: Math.max(1, Theme.u / 2)
        border.color: Qt.alpha("#ffffff", 0.6)
        Rectangle {
            x: parent.radius / 2
            y: Math.max(1, Theme.u / 2)
            width: parent.width - parent.radius
            height: parent.height * 0.42
            radius: height / 2
            color: Qt.alpha("#ffffff", 0.35)
        }
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
            width: Math.max(0, Math.min(implicitWidth, root.width - x - row.anchors.leftMargin - (side.visible ? side.implicitWidth + Theme.u * 9 : Theme.u * 5)))
            elide: Text.ElideRight
        }
    }
    // the right side: the submenu's arrow, else a check-box entry's tick (room kept for it
    // unticked), else the shortcut or the hint
    Item {
        id: side
        readonly property bool tick: root.checkable && !root.submenu
        visible: !root.separator && (root.submenu || tick || hintText.text !== "")
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
            text: root.submenu ? (root.skin === "y2k" ? "✦" : "▸") : root.keyText || root.hint
            dim: !root.lit
            color: root.lit ? root.t.litText : root.t.dim
            style: root.t.outlineText !== "transparent" ? Text.Outline : Text.Normal
            styleColor: root.t.outlineText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
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
