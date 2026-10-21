pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.views

// Settings' own look (the view "win11" by its old name; Config.settingsUi.view): a sunken strip
// on the left — the search, your account card, the categories with their tiles, the open one
// unfolding its pages like a tree; on the right a title plate (the page's tile in its
// category's colour, «Category ›» and the page's name big) and the page as raised cards in
// columns (PxGroup, PxCards: SettingsView.fluent). A category with several pages has a page of
// its own: its pages as cards (CategoryPage). Narrow, the strip keeps only the tiles and a
// magnifier; searching, it opens over the page with the field and what it finds. ↑↓ walk the
// categories (the page follows), → or Enter opens the first page of a category, ← goes back
// up to it.
Item {
    id: root

    required property var view              // SettingsView
    readonly property alias searchSlot: searchSlot
    readonly property alias resultsSlot: resultsSlot
    readonly property alias pageSlot: pageSlot
    readonly property bool sidebarVisible: true
    readonly property bool narrow: width < Theme.u * 330
    // narrow and not searching: the tiles only
    property bool searchOpen: false
    readonly property bool rail: narrow && !searchOpen
    readonly property real railWidth: Theme.u * 22
    readonly property real navWidth: rail ? railWidth : narrow ? Math.min(Theme.u * 120, width * 0.6) : Math.min(Theme.u * 120, width * 0.3)
    readonly property string here: root.view.settingsNav.settingsPage
    readonly property string hereSection: root.view.sectionOf(here)

    Connections {
        target: root.view
        function onSearchingChanged() {
            if (root.view.searching)
                root.searchOpen = true;
        }
        function onSearchFocusedChanged() {
            if (!root.view.searchFocused && root.view.query.trim() === "")
                root.searchOpen = false;
        }
    }
    // a page picked (a result, a tile): the page is what you want to see now
    Connections {
        target: Shell
        function onSettingsPageChanged() {
            root.searchOpen = false;
        }
    }

    function navKey(e) {
        if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
            view.navSection(e.key === Qt.Key_Down ? 1 : -1);
            return true;
        }
        if (e.key === Qt.Key_Home || e.key === Qt.Key_End) {
            const list = view.navSections;
            view.openSection(e.key === Qt.Key_Home ? list[0] : list[list.length - 1]);
            return true;
        }
        if (e.key === Qt.Key_Right || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            // a category's own page → its first page; on a page → the next one of the category
            if (root.here.startsWith("cat:")) {
                const s = view.navSectionOf(root.here);
                if (s && s.pages.length) {
                    root.view.settingsNav.settingsPage = s.pages[0];
                    root.view.settingsNav.settingsSub = "";
                }
            } else
                view.navPage(1);
            return true;
        }
        if (e.key === Qt.Key_Left) {
            view.goUp();
            return true;
        }
        return false;
    }
    function go(mouse, id) {
        if (root.view.clickedNew(mouse, id))
            return;
        root.view.settingsNav.settingsPage = id;
        root.view.settingsNav.settingsSub = "";
        root.view.focusNav();
    }

    // ---- the strip on the left: the search, you, the categories ----
    Item {
        id: nav
        z: 2
        width: root.navWidth
        height: parent.height

        // sunken, a hard edge on its right
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.u * 2
            anchors.rightMargin: 0
            color: Theme.mix(Theme.face, Theme.sunken, Theme.dark ? 0.6 : 0.4)
            Rectangle {
                anchors.right: parent.right
                width: Math.max(1, Theme.u / 2) * 2
                height: parent.height
                color: Qt.alpha(Theme.lo, Theme.dark ? 0.95 : 0.6)
            }
        }

        // the search field (SettingsView puts it here); narrow, a magnifier that widens it
        Item {
            id: searchSlot
            visible: !root.rail
            x: Theme.u * 2
            y: Theme.u * 2
            width: parent.width - Theme.u * 6
            height: root.view.searchFieldHeight
        }
        PxButton {
            id: lens
            visible: root.rail
            y: Theme.u * 2
            anchors.horizontalCenter: parent.horizontalCenter
            compact: true
            icon: "search"
            onClicked: {
                root.searchOpen = true;
                Qt.callLater(() => root.view.focusSearch(true));
            }
        }

        // you: the avatar, the name — your account
        PxBox {
            id: you
            readonly property bool sel: root.hereSection === "account"
            visible: !root.view.searching
            x: root.rail ? Theme.u : Theme.u * 2
            y: (root.rail ? lens.y + lens.height : searchSlot.y + searchSlot.height) + Theme.u * 4
            width: parent.width - x - Theme.u * (root.rail ? 3 : 4)
            height: root.rail ? Theme.fit(20) : Theme.fit(24)
            color: sel ? Theme.mix(Theme.faceAlt, Theme.accent, 0.22) : youMouse.containsMouse ? Theme.mix(Theme.faceAlt, Theme.accent, 0.1) : Theme.faceAlt
            PxBox {
                id: face
                x: root.rail ? (you.width - you.inset * 2 - width) / 2 : Theme.u * 2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u * (root.rail ? 13 : 15)
                height: width
                color: Theme.accent2
                Image {
                    id: avatarPic
                    anchors.fill: parent
                    anchors.margins: face.inset
                    source: StartPrefs.avatarUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Config.bar.avatarPixel ? Qt.size(20, 20) : Qt.size(width * 2, height * 2)
                    smooth: !Config.bar.avatarPixel
                    visible: status === Image.Ready
                }
                PxIcon {
                    visible: avatarPic.status !== Image.Ready
                    anchors.centerIn: parent
                    name: "heart"
                    fill: "#ffffff"
                }
            }
            Column {
                visible: !root.rail
                anchors.left: face.right
                anchors.leftMargin: Theme.u * 4
                anchors.right: parent.right
                anchors.rightMargin: Theme.u * 2
                anchors.verticalCenter: parent.verticalCenter
                PxText {
                    width: parent.width
                    text: StartPrefs.userName
                    font.bold: true
                    elide: Text.ElideRight
                }
                PxText {
                    width: parent.width
                    text: root.view.labelOf(SettingsTree.accountPage)
                    kind: "tiny"
                    dim: true
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: youMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => root.go(mouse, SettingsTree.accountPage)
            }
        }

        // the categories — the open one shows its pages — or what the search finds
        PxScroll {
            id: cats
            visible: !root.view.searching
            anchors.fill: parent
            anchors.topMargin: you.y + you.height + Theme.u * 4
            anchors.rightMargin: Theme.u * 2
            contentHeight: catCol.implicitHeight + Theme.u * 4

            Column {
                id: catCol
                width: parent.width
                Repeater {
                    model: root.view.visibleSections
                    Column {
                        id: cat
                        required property var modelData
                        readonly property bool open: root.hereSection === modelData.id
                        // its pages under it, like a tree (a category of one page is that page)
                        readonly property bool tree: open && !root.rail && modelData.pages.length > 1
                        width: catCol.width

                        Rectangle {
                            width: parent.width
                            height: Theme.fit(16)
                            color: cat.open && !cat.tree ? Theme.mix(Theme.face, Theme.accent, 0.2) : catMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : "transparent"
                            border.width: cat.open && root.view.navActive ? Math.max(1, Theme.u / 2) : 0
                            border.color: Theme.accent
                            Row {
                                x: root.rail ? (parent.width - Theme.u * 9) / 2 : Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.u * 4
                                SettingsTile {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: Theme.u * 9
                                    icon: cat.modelData.icon
                                    tint: cat.modelData.tint
                                }
                                PxText {
                                    visible: !root.rail
                                    width: cat.width - Theme.u * 20 - (catStar.visible ? catStar.width + Theme.u * 4 : 0)
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    text: cat.modelData.label
                                    font.bold: cat.open
                                    color: cat.open ? Theme.accent : Theme.text
                                }
                            }
                            // something new in it (services/SettingsNews); on the rail, on the tile's corner
                            NewStar {
                                id: catStar
                                visible: SettingsNews.sectionNew(cat.modelData)
                                x: root.rail ? (parent.width + Theme.u * 9) / 2 - width / 2 : parent.width - width - Theme.u * 3
                                y: root.rail ? Theme.u : (parent.height - height) / 2
                            }
                            MouseArea {
                                id: catMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (root.view.clickedNew(mouse, root.view.sectionTarget(cat.modelData)))
                                        return;
                                    root.view.openSection(cat.modelData);
                                    root.view.focusNav();
                                }
                            }
                        }
                        // the open category's pages; the one open filled in the accent, ▶ before it
                        Repeater {
                            model: cat.tree ? cat.modelData.pages : []
                            Item {
                                id: sub
                                required property string modelData
                                readonly property bool sel: root.here === modelData
                                width: cat.width
                                height: Theme.fit(13)
                                PxText {
                                    visible: sub.sel
                                    x: Theme.u * 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "▶"
                                    kind: "tiny"
                                    color: Theme.accent
                                }
                                Rectangle {
                                    x: Theme.u * 14
                                    width: parent.width - x
                                    height: parent.height
                                    color: sub.sel ? Theme.accent : subMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.12) : "transparent"
                                    PxText {
                                        x: Theme.u * 3
                                        width: parent.width - Theme.u * 6 - (subStar.visible ? subStar.width + Theme.u * 2 : 0)
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: root.view.labelOf(sub.modelData)
                                        color: sub.sel ? Theme.selectText : subMouse.containsMouse ? Theme.text : Theme.textDim
                                    }
                                    NewStar {
                                        id: subStar
                                        visible: SettingsNews.pageNew(sub.modelData)
                                        x: parent.width - width - Theme.u * 2
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    id: subMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => root.go(mouse, sub.modelData)
                                }
                            }
                        }
                        Item {
                            visible: cat.tree
                            width: 1
                            height: Theme.u * 2
                        }
                    }
                }
            }
        }
        Item {
            id: resultsSlot
            anchors.fill: parent
            anchors.topMargin: searchSlot.y + searchSlot.height + Theme.u * 4
            anchors.rightMargin: Theme.u * 2
        }
    }

    // ---- the right side: the title plate, then the page ----
    Item {
        id: main
        // the page keeps its place when the search opens over it
        anchors.left: parent.left
        anchors.leftMargin: (root.narrow ? root.railWidth : root.navWidth) + Theme.u * 6
        anchors.right: parent.right
        height: parent.height

        // where you are: the page's tile, «Category › Page ›» small, the last one big
        readonly property var crumbs: root.view.crumbs
        readonly property var entry: root.view.currentPage
        Item {
            id: header
            width: parent.width
            height: Math.max(badge.height, titles.implicitHeight, undo.height) + Theme.u * 4
            SettingsTile {
                id: badge
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.u * 20
                iconFill: 0.62
                icon: main.entry ? main.entry.icon || "gear" : "gear"
                tint: root.hereSection === "account" ? Theme.accent : String(root.here).startsWith("cat:") ? (root.view.navSectionOf(root.here) || {}).tint || Theme.accent : root.view.tintOf(root.view.currentId)
            }
            Column {
                id: titles
                anchors.left: badge.right
                anchors.leftMargin: Theme.u * 5
                anchors.right: undo.visible ? undo.left : newWin.left
                anchors.rightMargin: Theme.u * 3
                anchors.verticalCenter: parent.verticalCenter
                // the earlier crumbs, each a click back up
                Row {
                    visible: main.crumbs.length > 1
                    spacing: Theme.u * 2
                    Repeater {
                        model: main.crumbs.slice(0, -1)
                        PxText {
                            id: crumb
                            required property string modelData
                            required property int index
                            text: modelData + " ›"
                            color: crumbMouse.containsMouse ? Theme.accent : Theme.textDim
                            MouseArea {
                                id: crumbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.view.crumbClicked(crumb.index)
                            }
                        }
                    }
                }
                PxText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: main.crumbs.length ? main.crumbs[main.crumbs.length - 1] : ""
                    kind: "big"
                    font.bold: true
                }
            }
            // "Undo": the last change of a setting (Config.undo)
            PxButton {
                id: undo
                visible: Config.canUndo
                anchors.right: newWin.left
                anchors.rightMargin: Theme.u * 2
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                icon: "refresh"
                text: I18n.t("Отменить", "Undo") + (main.width > Theme.u * 320 && SettingsKeys.loaded ? " " + SettingsKeys.stepLabel(Config.lastStep) : "")
                onClicked: Config.undo()
            }
            // this page in one more window (Ctrl+N; a middle click on a category does the same)
            PxButton {
                id: newWin
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                flat: true
                icon: "window"
                enabled: Shell.settingsMore.count < Shell.settingsMoreMax
                opacity: enabled ? 1 : 0.35
                onClicked: root.view.openNew()
            }
        }

        Item {
            id: pageSlot
            anchors.fill: parent
            anchors.topMargin: header.height + Theme.u * 2
        }
    }
}
