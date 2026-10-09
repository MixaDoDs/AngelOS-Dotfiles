import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Popup window anchored to a bar item, framed as a small NGO window — or, in the Golden Gate
// look (services/Skin.mac), a Liquid Glass popover under the menu bar extra: rounded glass, the
// title in plain words (a ".exe"/".sh"/".bin" a plugin passes is dropped), no window buttons.
// The content is the same item either way: it moves into the frame of the look in use, and sees
// settingsSkin, so the shared controls inside take that look too.
PopupWindow {
    id: root

    required property Item anchorItem
    property string title: ""
    property string panelId: title
    readonly property string outputName: anchorItem && anchorItem.QsWindow.window && anchorItem.QsWindow.window.screen ? anchorItem.QsWindow.window.screen.name : ""
    Component.onCompleted: PopupManager.registerPopup(root)
    Component.onDestruction: PopupManager.unregisterPopup(root)
    property string icon: "heart"
    property bool above: false
    property int contentWidth: Theme.u * 140
    property int contentHeight: Theme.u * 80
    default property alias content: holder.data
    readonly property bool mac: Skin.mac
    readonly property int macPad: GoldenGate.px(12)
    readonly property int macTitleH: root.macTitle !== "" ? GoldenGate.px(26) : 0
    readonly property string macTitle: String(title).replace(/\.(exe|sh|bin)$/i, "")

    function toggle() {
        PopupManager.toggle(root);
    }

    // a taskbar on the left or the right edge (BarLayout.side): the popup opens beside it, from
    // the item's top down (sliding up where the screen ends)
    property string side: BarLayout.side
    anchor.item: anchorItem
    anchor.rect.x: side === "left" ? anchorItem.width + Theme.u * 2 : side === "right" ? -Theme.u * 2 : 0
    anchor.rect.y: side ? 0 : mac ? (above ? -GoldenGate.px(4) : anchorItem.height + GoldenGate.px(4)) : above ? -Theme.u * 2 : anchorItem.height + Theme.u * 2
    anchor.rect.width: side ? 1 : anchorItem.width
    anchor.rect.height: side ? anchorItem.height : 1
    anchor.edges: side === "left" ? Edges.Top | Edges.Right : side === "right" ? Edges.Top | Edges.Left : (above ? Edges.Top : Edges.Bottom) | Edges.Right
    anchor.gravity: side === "left" ? Edges.Bottom | Edges.Right : side === "right" ? Edges.Bottom | Edges.Left : (above ? Edges.Top : Edges.Bottom) | Edges.Left
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    grabFocus: true
    color: "transparent"
    // (the Mac popover keeps room for its shadow around the glass)
    implicitWidth: mac ? contentWidth + macPad * 2 + GoldenGate.px(24) : contentWidth + Theme.u * 3
    implicitHeight: mac ? macTitleH + contentHeight + macPad * 2 + GoldenGate.px(24) : win.titleHeight + contentHeight + Theme.pad * 2 + Theme.u * 8
    visible: false
    onVisibleChanged: {
        if (visible && PopupManager.active !== root) {
            if (PopupManager.active)
                PopupManager.close(PopupManager.active);
            PopupManager.active = root;
        }
        if (!visible && PopupManager.active === root)
            PopupManager.active = null;
    }

    BackgroundEffect.blurRegion: root.mac ? (GoldenGate.blurOn ? macBlur : null) : Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: win
    }
    Region {
        id: macBlur
        item: macPanel
        radius: macPanel.radius
    }

    PxWindow {
        id: win
        visible: !root.mac
        width: root.contentWidth
        height: root.implicitHeight - Theme.u * 3
        title: root.title
        icon: root.icon
        compact: true
        onCloseClicked: PopupManager.close(root)
        focus: !root.mac
        Keys.onEscapePressed: PopupManager.close(root)
    }

    MacGlass {
        id: macPanel
        visible: root.mac
        x: GoldenGate.px(12)
        y: root.above ? GoldenGate.px(4) : GoldenGate.px(8)
        width: root.contentWidth + root.macPad * 2
        height: root.macTitleH + root.contentHeight + root.macPad * 2
        radius: GoldenGate.px(14)
        shadowSize: GoldenGate.px(20)
        shadowY: GoldenGate.px(5)
        focus: root.mac
        Keys.onEscapePressed: PopupManager.close(root)
        MacText {
            visible: root.macTitleH > 0
            x: root.macPad
            y: root.macPad
            width: parent.width - root.macPad * 2
            text: root.macTitle
            semibold: true
            elide: Text.ElideRight
        }
        Item {
            id: macBody
            x: root.macPad
            y: root.macPad + root.macTitleH
            width: root.contentWidth
            height: root.contentHeight
        }
    }

    // the content: in the pixel window's body or in the glass
    Item {
        id: holder
        readonly property string settingsSkin: root.mac ? "goldengate" : win.settingsSkin
        parent: root.mac ? macBody : win.bodyItem
        anchors.fill: parent
    }

    RightClickGuard {}
}
