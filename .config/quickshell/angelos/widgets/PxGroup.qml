import QtQuick
import qs.config
import qs.services
import "MacIcons.js" as MacIcons

// A group of settings. In Settings (the angelOS look, `fluent`): a raised pixel card with its
// caption inside, the rows under it with hairlines between them (SettingRow); the page lays
// the cards out in columns (PxPage, PxCards) — `wide` keeps one across the whole page. Classic:
// like macOS's System Settings — a caption above a raised pixel card; Windose and Stream:
// their own boxes.
// `advanced` groups are sub-pages (the macOS "Title ›"): on their page they are not shown,
// the page lists them as links at its top (PxPage) and opens one on its own
// (the window's settingsSub = its title); then the other groups of the page step aside. An
// advanced group that is only there sometimes says so with `shown`, not `visible`.
Item {
    id: root
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: settingsSkin === "p5"

    property string title: ""
    // the group's key in the settings tree (modules/settings/tree.json: "page/name"): pages are
    // put together from groups by it, the search and old links find it by it
    property string name: ""
    property string icon: ""
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    // Settings (SettingsView.fluent): a card of rows (SettingRow); in the Golden Gate skin a
    // sub-page (`advanced`) is a card that unfolds in place
    readonly property bool fluent: Theme.fluentFor(root.parent)
    // the Golden Gate skin's System Settings: the rows in one rounded box, a shade off the page
    readonly property bool mac: settingsSkin === "goldengate"
    // the angelOS look: the caption inside the card
    readonly property bool angel: fluent && !mac
    property bool unfolded: false
    // only the Golden Gate skin folds a sub-page into a "Title ›" row; in the angelOS look the
    // settings tree alone says what waits under «Ещё…» (tree.json "more"), a card never folds
    readonly property bool foldable: fluent && mac && advanced
    readonly property bool folded: foldable && !unfolded && openSub !== title
    property int spacing: Theme.u * 5
    property bool advanced: false
    property bool shown: true
    property bool wide: false
    // only its rows, no card or caption: what a catalog page had outside its groups
    // (CatalogPage); the page shows it where it showed those (PxPage.wants)
    property bool bare: false
    default property alias content: col.data
    // new since you last looked (services/SettingsNews), looked up when the news change
    readonly property bool isNew: {
        if (!SettingsNews.news.count || !name)
            return false;
        for (let p = root.parent; p; p = p.parent)
            if (p.srcName !== undefined)
                return SettingsNews.groupNew(p.srcName, name);
        return false;
    }

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

    readonly property bool classic: (settingsSkin === "classic" || settingsSkin === "p5") && !fluent
    readonly property int b: Math.max(1, Theme.u / 2)
    implicitWidth: col.implicitWidth + Theme.pad * 2
    implicitHeight: bare ? col.implicitHeight : fluent ? (foldable ? fold.y + fold.height + (folded ? 0 : col.implicitHeight + Theme.u * 4) : col.y + col.implicitHeight + Theme.u * (angel ? 4 : 3)) : classic ? card.y + col.implicitHeight + Theme.pad * 2 : col.y + col.implicitHeight + Theme.pad

    // ---- the angelOS look: one raised card, the caption inside ----
    PxBox {
        visible: root.angel && !root.bare
        width: root.width
        height: root.height
        color: Theme.mix(Theme.toneOf(root.settingsSkin, "face"), Theme.toneOf(root.settingsSkin, "faceAlt"), 0.6)
    }
    // ---- the Golden Gate skin: the box under the caption; the card that unfolds (both) ----
    Rectangle {
        id: container
        visible: root.fluent && root.mac && !root.bare
        y: root.foldable ? fold.y : head.height + Theme.u * 2
        width: root.width
        height: root.height - y
        radius: root.mac ? Theme.u * 5 : 0
        color: root.mac ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.035)) : Theme.mix(Theme.toneOf(root.settingsSkin, "face"), Theme.toneOf(root.settingsSkin, "sunken"), Theme.dark ? 0.45 : 0.3)
        border.width: root.mac ? 0 : Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(Theme.toneOf(root.settingsSkin, "lo"), Theme.dark ? 0.85 : 0.45)
    }
    Rectangle {
        id: fold
        visible: root.foldable
        width: root.width
        height: Math.max(Theme.fit(22), foldText.implicitHeight + Theme.u * 8)
        radius: root.mac ? Theme.u * 5 : 0
        color: root.mac ? (foldMouse.containsMouse ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)) : (Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.035))) : foldMouse.containsMouse ? Theme.mix(Theme.toneOf(root.settingsSkin, "faceAlt"), Theme.accent, 0.12) : Theme.mix(Theme.toneOf(root.settingsSkin, "face"), Theme.toneOf(root.settingsSkin, "faceAlt"), 0.55)
        border.width: root.mac ? 0 : Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(Theme.toneOf(root.settingsSkin, "lo"), Theme.dark ? 0.9 : 0.5)
        SettingsTile {
            id: foldTile
            x: Theme.u * 5
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon || "gear"
            tint: Theme.mix(Theme.accent, Theme.toneOf(root.settingsSkin, "face"), 0.25)
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
                    Shell.settingsNavFor(root).settingsSub = "";
            }
        }
    }
    // the names of the rows inside a folded card
    readonly property string summary: {
        if (!foldable)
            return "";
        const names = [];
        for (const c of col.children)
            if (c.label !== undefined && c.hint !== undefined && c.label && names.length < 4)
                names.push(c.label);
        return names.join(", ");
    }

    // ---- Windose / Stream ----
    Rectangle {
        visible: !root.classic && !root.fluent && !root.bare
        anchors.fill: parent
        radius: root.settingsSkin === "stream" ? Theme.u * 3 : 0
        color: root.settingsSkin === "stream" ? Theme.streamPanel : Theme.windosePaper
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.settingsSkin === "stream" ? Theme.mix(Theme.streamLive, Theme.streamPanel, 0.38) : Theme.windoseLine
    }
    Rectangle {
        visible: !root.classic && !root.fluent && !root.bare
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
        visible: root.classic && !root.bare
        y: head.height + Theme.u * 2
        width: root.width
        height: root.height - y
        color: Theme.mix(Theme.toneOf(root.settingsSkin, "face"), Theme.toneOf(root.settingsSkin, "faceAlt"), 0.35)
    }

    Row {
        id: head
        // open as a sub-page, its title is the page's heading already (the folding card says it)
        visible: root.openSub !== root.title && !root.foldable && root.title !== "" && !root.bare
        height: visible ? implicitHeight : 0
        x: root.classic ? Theme.u * 2 : root.angel ? Theme.u * 3 : Theme.u * 6
        y: root.classic ? 0 : root.angel ? Theme.u * 4 : Theme.u * 3
        spacing: Theme.u * 3
        leftPadding: root.classic ? 0 : Theme.u * 2
        rightPadding: Theme.u * 2
        // the Golden Gate skin: no icon by a group's caption, as in System Settings
        PxIcon {
            visible: root.icon !== "" && !root.mac
            name: root.icon || "heart"
            anchors.verticalCenter: parent.verticalCenter
            pixel: root.classic || root.angel ? Math.max(1, Theme.u - 1) : Theme.u
            ink: root.p5 ? Theme.p5AccentInk : root.angel ? Theme.accent2 : root.settingsSkin === "stream" ? Theme.streamLive : root.settingsSkin === "windose" ? Theme.windoseRose : Theme.toneOf(root.settingsSkin, "textDim")
        }
        PxText {
            text: root.title
            kind: root.classic || root.fluent ? "body" : "title"
            font.capitalization: root.angel ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: root.angel ? Theme.u / 2 : 0
            color: root.p5 ? Theme.p5AccentInk : root.angel ? Theme.accent2 : root.settingsSkin === "stream" ? Theme.streamText : root.settingsSkin === "windose" ? Theme.windoseInk : Theme.toneOf(root.settingsSkin, "textDim")
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        // a group new since you last looked (services/SettingsNews)
        NewStar {
            visible: root.isNew
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: col
        readonly property bool fixedWidth: true // PxToggle wraps its label to fit
        visible: !root.folded
        x: root.bare ? 0 : root.angel ? Theme.u * 5 : root.fluent ? Theme.u * 3 : Theme.pad
        y: root.bare ? 0 : root.fluent ? (root.foldable ? fold.y + fold.height + Theme.u * 3 : root.angel ? head.y + head.height + Theme.u * 2 : container.y + Theme.u * 3) : root.classic ? card.y + Theme.pad : head.y + head.height + Theme.u * 4
        width: root.bare ? root.width : root.width - (root.angel ? Theme.u * 10 : root.fluent ? Theme.u * 6 : Theme.pad * 2)
        spacing: root.angel ? 0 : root.fluent ? Theme.u * 2 : root.spacing
    }
}
