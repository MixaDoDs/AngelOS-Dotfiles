import QtQuick
import qs.config
import qs.services
import "MacIcons.js" as MacIcons

// A group of settings. Classic: like macOS's System Settings — a caption above a raised
// pixel card that holds the rows (SettingRow draws the hairlines between them); Windose
// and Stream: their own boxes.
// `advanced` groups are sub-pages (the macOS "Title ›"): on their page they are not shown,
// the page lists them as links at its top (PxPage) and opens one on its own
// (Shell.settingsSub = its title); then the other groups of the page step aside. An
// advanced group that is only there sometimes says so with `shown`, not `visible`.
Item {
    id: root

    property string title: ""
    // the group's key in the settings tree (modules/settings/tree.json: "page/name"): pages are
    // put together from groups by it, the search and old links find it by it
    property string name: ""
    property string icon: ""
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    // Settings in the Windows 11 look: a caption over a container whose rows are cards of
    // their own (SettingRow); a sub-page (`advanced`) is a card that unfolds in place
    readonly property bool fluent: Theme.fluentFor(root.parent)
    // the Golden Gate skin's System Settings: the rows in one rounded box, a shade off the page
    readonly property bool mac: settingsSkin === "goldengate"
    property bool unfolded: false
    readonly property bool folded: fluent && advanced && !unfolded && openSub !== title
    property int spacing: Theme.u * 5
    property bool advanced: false
    property bool shown: true
    default property alias content: col.data

    // the page this is on (PxPage: focusGroup), if any
    readonly property var page: {
        for (let p = root.parent; p; p = p.parent)
            if (p.focusGroup !== undefined)
                return p;
        return null;
    }
    readonly property string openSub: page ? page.focusGroup : ""
    // a part of a page put together from groups shows only the groups it was given
    readonly property bool leftOut: !!page && !!page.wants && !page.wants(root)
    // a sub-page that isn't the one open, or another group while a sub-page is open
    readonly property bool steppedAside: leftOut || (!fluent && !!page && (openSub !== "" ? title !== openSub : advanced))
    // a group's own `visible: …` (a page's) or this one comes back after stepping aside — a
    // binding, never a value: the value read then is the item's effective visibility, false
    // while the page is hidden for a moment (moved into another dress's frame), and the group
    // would stay hidden for good
    visible: root.shown
    Binding {
        target: root
        property: "visible"
        value: root.shown && !root.steppedAside
        when: root.steppedAside || (root.advanced && root.openSub === root.title)
        restoreMode: Binding.RestoreBinding
    }

    readonly property bool classic: settingsSkin === "classic" && !fluent
    readonly property int b: Math.max(1, Theme.u / 2)
    implicitWidth: col.implicitWidth + Theme.pad * 2
    implicitHeight: fluent ? (advanced ? fold.y + fold.height + (folded ? 0 : col.implicitHeight + Theme.u * 4) : container.y + col.implicitHeight + Theme.u * 6) : classic ? card.y + col.implicitHeight + Theme.pad * 2 : col.y + col.implicitHeight + Theme.pad

    // ---- Windows 11: the container under the caption, or the card that unfolds ----
    Rectangle {
        id: container
        visible: root.fluent
        y: root.advanced ? fold.y : head.height + Theme.u * 2
        width: root.width
        height: root.height - y
        radius: root.mac ? Theme.u * 5 : 0
        color: root.mac ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.035)) : Theme.mix(Theme.face, Theme.sunken, Theme.dark ? 0.45 : 0.3)
        border.width: root.mac ? 0 : Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(Theme.lo, Theme.dark ? 0.85 : 0.45)
    }
    Rectangle {
        id: fold
        visible: root.fluent && root.advanced
        width: root.width
        height: Math.max(Theme.fit(22), foldText.implicitHeight + Theme.u * 8)
        radius: root.mac ? Theme.u * 5 : 0
        color: root.mac ? (foldMouse.containsMouse ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)) : (Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.035))) : foldMouse.containsMouse ? Theme.mix(Theme.faceAlt, Theme.accent, 0.12) : Theme.mix(Theme.face, Theme.faceAlt, 0.55)
        border.width: root.mac ? 0 : Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(Theme.lo, Theme.dark ? 0.9 : 0.5)
        SettingsTile {
            id: foldTile
            x: Theme.u * 5
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon || "gear"
            tint: Theme.mix(Theme.accent, Theme.face, 0.25)
            opacity: root.mac ? 0 : 1
        }
        // …a Mac's coloured icon square instead
        Rectangle {
            visible: root.mac
            anchors.centerIn: foldTile
            width: GoldenGate.px(24)
            height: width
            radius: GoldenGate.px(6)
            color: Theme.accent
            MacIcon {
                anchors.centerIn: parent
                name: MacIcons.fromPixel(root.icon || "gear") || "settings"
                size: parent.width * 0.66
                stroke: 2
                color: "#ffffff"
            }
        }
        Column {
            id: foldText
            anchors.left: foldTile.right
            anchors.leftMargin: Theme.u * 5
            anchors.right: foldArrow.left
            anchors.rightMargin: Theme.u * 4
            anchors.verticalCenter: parent.verticalCenter
            PxText {
                width: parent.width
                text: root.title
                elide: Text.ElideRight
            }
            // what is inside: the first few rows' names
            PxText {
                visible: text !== ""
                width: parent.width
                text: root.summary
                kind: "tiny"
                dim: true
                elide: Text.ElideRight
            }
        }
        PxText {
            id: foldArrow
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 5
            anchors.verticalCenter: parent.verticalCenter
            text: root.mac ? (root.folded ? "›" : "⌄") : root.folded ? "▾" : "▴"
            kind: "title"
            dim: true
        }
        MouseArea {
            id: foldMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const open = root.folded;
                root.unfolded = open;
                if (!open && root.openSub === root.title)
                    Shell.settingsSub = "";
            }
        }
    }
    // the names of the rows inside a folded card
    readonly property string summary: {
        if (!fluent || !advanced)
            return "";
        const names = [];
        for (const c of col.children)
            if (c.label !== undefined && c.hint !== undefined && c.label && names.length < 4)
                names.push(c.label);
        return names.join(", ");
    }

    // ---- Windose / Stream ----
    Rectangle {
        visible: !root.classic && !root.fluent
        anchors.fill: parent
        radius: root.settingsSkin === "stream" ? Theme.u * 3 : 0
        color: root.settingsSkin === "stream" ? Theme.streamPanel : Theme.windosePaper
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.settingsSkin === "stream" ? Theme.mix(Theme.streamLive, Theme.streamPanel, 0.38) : Theme.windoseLine
    }
    Rectangle {
        visible: !root.classic && !root.fluent
        x: Theme.u
        y: Theme.u
        width: root.width - Theme.u * 2
        height: head.height + Theme.u * 4
        radius: root.settingsSkin === "stream" ? Theme.u * 2 : 0
        color: root.settingsSkin === "stream" ? Theme.mix(Theme.streamPanel, Theme.streamLive, 0.14) : Theme.mix(Theme.windosePaper, Theme.windoseRose, 0.22)
    }

    // ---- classic: the card under the caption ----
    PxBox {
        id: card
        visible: root.classic
        y: head.height + Theme.u * 2
        width: root.width
        height: root.height - y
        color: Theme.mix(Theme.face, Theme.faceAlt, 0.35)
    }

    Row {
        id: head
        // open as a sub-page, its title is the page's heading already (the folding card says it)
        visible: root.openSub !== root.title && !(root.fluent && root.advanced) && root.title !== ""
        height: visible ? implicitHeight : 0
        x: root.classic ? Theme.u * 2 : Theme.u * 6
        y: root.classic ? 0 : Theme.u * 3
        spacing: Theme.u * 3
        leftPadding: root.classic ? 0 : Theme.u * 2
        rightPadding: Theme.u * 2
        // the Golden Gate skin: no icon by a group's caption, as in System Settings
        PxIcon {
            visible: root.icon !== "" && !root.mac
            name: root.icon || "heart"
            anchors.verticalCenter: parent.verticalCenter
            pixel: root.classic ? Math.max(1, Theme.u - 1) : Theme.u
            ink: root.settingsSkin === "stream" ? Theme.streamLive : root.settingsSkin === "windose" ? Theme.windoseRose : Theme.textDim
        }
        PxText {
            text: root.title
            kind: root.classic || root.fluent ? "body" : "title"
            color: root.settingsSkin === "stream" ? Theme.streamText : root.settingsSkin === "windose" ? Theme.windoseInk : Theme.textDim
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: col
        readonly property bool fixedWidth: true // PxToggle wraps its label to fit
        visible: !root.folded
        x: root.fluent ? Theme.u * 3 : Theme.pad
        y: root.fluent ? (root.advanced ? fold.y + fold.height + Theme.u * 3 : container.y + Theme.u * 3) : root.classic ? card.y + Theme.pad : head.y + head.height + Theme.u * 4
        width: root.width - (root.fluent ? Theme.u * 6 : Theme.pad * 2)
        spacing: root.fluent ? Theme.u * 2 : root.spacing
    }
}
