pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.views

// Settings view "tiles" (Config.settingsUi.view): a big search field in the middle, your
// most opened pages under it, then every section as a big tile (its pages written small
// underneath). A tile opens its page over the window, "‹ All settings" comes back; the
// search field then moves up into the page's toolbar. The keyboard: arrows walk the
// tiles, Enter opens, Backspace / Alt+↑ come back, typing searches.
Item {
    id: root

    required property var view              // SettingsView
    readonly property alias searchSlot: searchSlot
    readonly property alias resultsSlot: resultsSlot
    readonly property alias pageSlot: pageSlot
    readonly property bool searchBig: view.atHome
    readonly property string skin: view.skin
    readonly property bool searching: view.query.trim() !== ""

    readonly property var tiles: view.navSections
    readonly property int columns: Math.max(1, Math.floor((home.width + Theme.u * 5) / (Theme.u * 96 + Theme.u * 5)))
    property int cur: 0
    Connections {
        target: root.view
        function onAtHomeChanged() {
            if (root.view.atHome) {
                const sid = root.view.sectionOf(root.view.lastLoc.split("|")[0]);
                root.cur = Math.max(0, root.tiles.findIndex(s => s.id === sid));
            }
        }
    }
    function navKey(e) {
        if (!view.atHome)
            return false;
        const n = tiles.length;
        if (e.key === Qt.Key_Right)
            cur = Math.min(n - 1, cur + 1);
        else if (e.key === Qt.Key_Left)
            cur = Math.max(0, cur - 1);
        else if (e.key === Qt.Key_Down)
            cur = Math.min(n - 1, cur + columns);
        else if (e.key === Qt.Key_Up) {
            if (cur - columns < 0)
                view.focusSearch();
            else
                cur -= columns;
        } else if (e.key === Qt.Key_Home)
            cur = 0;
        else if (e.key === Qt.Key_End)
            cur = n - 1;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            view.openSection(tiles[cur]);
        else
            return false;
        homeScroll.reveal(cur);
        return true;
    }
    // the pages opened most, else a few everyday ones
    readonly property var everyday: {
        const out = view.frequent(4);
        for (const id of ["wallpaper", "appearance", "sound", "bar", "monitor"])
            if (out.length < 4 && !out.some(p => p.id === id) && view.pageEntry(id))
                out.push(view.pageEntry(id));
        return out;
    }

    // ---- the page's toolbar (a page is open) ----
    Item {
        id: top
        visible: !root.view.atHome
        width: parent.width
        height: toolbar.height
        PxButton {
            id: allBtn
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            icon: "grid"
            text: I18n.t("Все настройки", "All settings")
            onClicked: root.view.goHome()
        }
        SettingsToolbar {
            id: toolbar
            anchors.left: allBtn.right
            anchors.leftMargin: Theme.u * 3
            anchors.right: parent.right
            view: root.view
            searchWidth: Math.min(Theme.u * 90, root.width * 0.28)
        }
    }

    // the search field: big in the middle of the home, small in the toolbar on a page
    Item {
        id: searchSlot
        x: root.view.atHome ? Math.round((root.width - width) / 2) : toolbar.x + toolbar.searchSlot.x
        y: root.view.atHome ? Theme.u * 10 : top.y + toolbar.y + toolbar.searchSlot.y
        width: root.view.atHome ? Math.min(root.width - Theme.u * 16, Theme.u * 260) : toolbar.searchWidth
        height: root.view.searchFieldHeight
        z: 3
    }
    Item {
        id: resultsSlot
        x: root.view.atHome ? searchSlot.x : Math.max(Theme.u * 4, root.width - width - Theme.u * 4)
        y: searchSlot.y + searchSlot.height + Theme.u * (root.view.atHome ? 10 : 4)
        width: root.view.atHome ? searchSlot.width : Math.min(root.width - Theme.u * 8, Theme.u * 170)
        height: parent.height - y - Theme.u * 4
        z: 3
        // on a page the results lie over it, on a card
        PxBox {
            visible: !root.view.atHome && root.searching
            anchors.fill: parent
            anchors.margins: -Theme.u * 3
            shadow: true
            color: Theme.menuSurface
            z: -1
        }
    }

    // ---- the home ----
    PxScroll {
        id: homeScroll
        visible: root.view.atHome && !root.searching
        anchors.fill: parent
        anchors.topMargin: searchSlot.y + searchSlot.height + Theme.u * 8
        contentHeight: home.implicitHeight + Theme.u * 6
        function reveal(i) {
            const y = grid.y + Math.floor(i / root.columns) * (Theme.u * 44 + Theme.u * 5);
            if (y < flick.contentY)
                scrollBy(y - flick.contentY);
            else if (y + Theme.u * 44 > flick.contentY + height)
                scrollBy(y + Theme.u * 44 - flick.contentY - height);
        }
        Column {
            id: home
            x: Theme.u * 4
            width: parent.width - Theme.u * 8
            spacing: Theme.u * 6
            // the everyday row
            Flow {
                width: parent.width
                spacing: Theme.u * 3
                PxText {
                    height: Theme.u * 11
                    verticalAlignment: Text.AlignVCenter
                    text: "✧ " + I18n.t("Частое:", "Everyday:")
                    dim: true
                }
                Repeater {
                    model: root.everyday
                    PxButton {
                        required property var modelData
                        compact: true
                        icon: modelData.icon
                        text: modelData.label
                        onClicked: root.view.settingsNav.settingsPage = modelData.id
                    }
                }
            }
            Grid {
                id: grid
                width: parent.width
                columns: root.columns
                spacing: Theme.u * 5
                readonly property real tileW: Math.floor((width - (columns - 1) * spacing) / columns)
                Repeater {
                    model: root.tiles
                    PxBox {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool cur: root.view.navActive && root.cur === index
                        width: grid.tileW
                        height: Theme.u * 44
                        color: tileMouse.containsMouse || cur ? Theme.mix(Theme.face, modelData.tint, 0.16) : root.skin === "windose" ? Theme.windoseSticker : root.skin === "stream" ? Theme.streamPanel : Theme.mix(Theme.face, Theme.faceAlt, 0.35)
                        edgeColor: cur ? Theme.accent : root.skin === "windose" ? Theme.windoseLine : Theme.edge
                        sunken: tileMouse.pressed
                        SettingsTile {
                            x: Theme.u * 5
                            y: Theme.u * 5
                            size: Theme.u * 18
                            icon: tile.modelData.icon
                            tint: tile.modelData.tint
                        }
                        Column {
                            x: Theme.u * 28
                            y: Theme.u * 5
                            width: tile.width - x - Theme.u * 4
                            spacing: Theme.u
                            PxText {
                                width: parent.width
                                text: tile.modelData.label
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            // a section of several pages lists them; a single page says what it is for
                            PxText {
                                width: parent.width
                                kind: "tiny"
                                dim: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                text: tile.modelData.id === "account" ? I18n.t("язык, мастер, подсказки", "language, wizard, tips") : tile.modelData.id === "y2k" ? (Angel.demon ? I18n.t("она в углу, ад повсюду", "her in the corner, hell all around") : I18n.t("ангел в углу, блёстки, звуки, загрузка", "the angel in the corner, glitter, sounds, the boot")) : tile.modelData.pages.length > 1 ? tile.modelData.pages.map(id => root.view.labelOf(id)).join(" · ") : root.view.pageHint(tile.modelData.pages[0])
                            }
                        }
                        // the keyboard's tile: a frame in the accent
                        Rectangle {
                            visible: tile.cur
                            anchors.fill: parent
                            anchors.margins: -Theme.u
                            color: "transparent"
                            border.width: Math.max(1, Theme.u / 2)
                            border.color: Theme.accent
                        }
                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (root.view.clickedNew(mouse, root.view.sectionTarget(tile.modelData)))
                                    return;
                                root.cur = tile.index;
                                root.view.openSection(tile.modelData);
                                root.view.focusNav();
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- a page, over the whole window ----
    PxBox {
        id: pageBox
        visible: !root.view.atHome
        anchors.top: top.bottom
        anchors.topMargin: Theme.u * 4
        anchors.bottom: parent.bottom
        width: parent.width
        sunken: true
        color: root.skin === "windose" ? Theme.windosePaper : root.skin === "stream" ? Theme.streamBg : Qt.alpha(Theme.face, Config.appearance.blur ? 0.55 : 1)
        edgeColor: root.skin === "windose" ? Theme.windoseLine : Theme.edge
        Item {
            id: pageSlot
            anchors.fill: parent
            anchors.margins: Theme.u * 3
        }
    }
}
