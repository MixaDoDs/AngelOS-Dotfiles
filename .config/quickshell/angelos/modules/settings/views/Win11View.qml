pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.views

// Settings view "win11" (Config.settingsUi.view, the default), laid out like Windows 11's
// Settings: on the left your account card, the search and the categories, each with its
// tile; on the right where you are in big crumbs (Personalization › Taskbar) and the page as
// cards — a row per setting, its control on the right; sub-pages open in place as cards that
// unfold (PxGroup, SettingRow: SettingsView.fluent). A category with several pages has a page
// of its own: its pages as cards with what is on them (CategoryPage). Narrow, the left column
// keeps only the tiles and a magnifier; searching, it opens over the page with the field and
// what it finds. ↑↓ walk the categories (the page follows), → or Enter opens the first page
// of a category, ← goes back up to it.
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
    readonly property real navWidth: rail ? railWidth : narrow ? Math.min(Theme.u * 128, width * 0.6) : Math.min(Theme.u * 128, width * 0.34)

    Connections {
        target: root.view
        function onQueryChanged() {
            if (root.view.query.trim() !== "")
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
            if (root.view.settingsNav.settingsPage.startsWith("cat:")) {
                const s = view.navSectionOf(root.view.settingsNav.settingsPage);
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

    // ---- the left column: you, the search, the categories ----
    Item {
        id: nav
        z: 2
        width: root.navWidth
        height: parent.height

        // opened over the page while searching in a narrow window
        Rectangle {
            visible: root.narrow && !root.rail
            anchors.fill: parent
            anchors.margins: -Theme.u * 2
            color: Theme.face
            border.width: Math.max(1, Theme.u / 2)
            border.color: Qt.alpha(Theme.lo, Theme.dark ? 0.9 : 0.5)
        }

        // you: the avatar, the name — your account
        Rectangle {
            id: you
            readonly property bool sel: root.view.sectionOf(root.view.settingsNav.settingsPage) === "account"
            width: parent.width
            height: root.rail ? Theme.fit(20) : Theme.fit(26)
            color: sel ? Theme.mix(Theme.face, Theme.accent, 0.2) : youMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : "transparent"
            PxBox {
                id: face
                x: root.rail ? (parent.width - width) / 2 : Theme.u * 2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.u * (root.rail ? 16 : 20)
                height: width
                color: Theme.accent
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
                onClicked: mouse => {
                    if (root.view.clickedNew(mouse, SettingsTree.accountPage))
                        return;
                    root.view.settingsNav.settingsPage = SettingsTree.accountPage;
                    root.view.settingsNav.settingsSub = "";
                    root.view.focusNav();
                }
            }
        }

        // the search field (SettingsView puts it here); narrow, a magnifier that widens it
        Item {
            id: searchSlot
            visible: !root.rail
            y: you.height + Theme.u * 4
            width: parent.width
            height: root.view.searchFieldHeight
        }
        PxButton {
            visible: root.rail
            y: you.height + Theme.u * 4
            anchors.horizontalCenter: parent.horizontalCenter
            compact: true
            icon: "search"
            onClicked: {
                root.searchOpen = true;
                Qt.callLater(root.view.focusSearch);
            }
        }

        // the categories, or what the search finds
        PxScroll {
            id: cats
            visible: root.view.query.trim() === ""
            anchors.fill: parent
            anchors.topMargin: searchSlot.y + searchSlot.height + Theme.u * 4
            contentHeight: catCol.implicitHeight

            Column {
                id: catCol
                width: parent.width
                spacing: Theme.u
                Repeater {
                    model: root.view.visibleSections
                    Rectangle {
                        id: cat
                        required property var modelData
                        readonly property bool sel: root.view.sectionOf(root.view.settingsNav.settingsPage) === modelData.id
                        width: catCol.width
                        height: Theme.fit(16)
                        color: sel ? Theme.mix(Theme.face, Theme.accent, 0.2) : catMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.1) : "transparent"
                        border.width: sel && root.view.navActive ? Math.max(1, Theme.u / 2) : 0
                        border.color: Theme.accent
                        // the picked one: a short accent bar on the left, like Windows 11
                        Rectangle {
                            visible: cat.sel
                            x: 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.u * 2
                            height: parent.height * 0.55
                            color: Theme.accent
                        }
                        Row {
                            x: root.rail ? (parent.width - Theme.u * 11) / 2 : Theme.u * 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u * 4
                            SettingsTile {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: cat.modelData.icon
                                tint: cat.modelData.tint
                            }
                            PxText {
                                visible: !root.rail
                                width: cat.width - Theme.u * 24
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: cat.modelData.label
                                font.bold: cat.sel
                            }
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
                }
            }
        }
        Item {
            id: resultsSlot
            anchors.fill: parent
            anchors.topMargin: searchSlot.y + searchSlot.height + Theme.u * 4
        }
    }

    // ---- the right side: where you are, then the page ----
    Item {
        id: main
        // the page keeps its place when the search opens over it
        anchors.left: parent.left
        anchors.leftMargin: (root.narrow ? root.railWidth : root.navWidth) + Theme.u * 6
        anchors.right: parent.right
        height: parent.height

        // the crumbs, big: Personalization › Taskbar (the earlier ones a click back up)
        Item {
            id: header
            width: parent.width
            height: Math.max(crumbFlow.implicitHeight, undo.height) + Theme.u * 4
            Flow {
                id: crumbFlow
                anchors.left: parent.left
                anchors.right: undo.visible ? undo.left : newWin.left
                anchors.rightMargin: Theme.u * 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.u * 3
                Repeater {
                    model: root.view.crumbs
                    Row {
                        id: crumb
                        required property var modelData
                        required property int index
                        readonly property bool last: index === root.view.crumbs.length - 1
                        spacing: Theme.u * 3
                        PxText {
                            visible: crumb.index > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            kind: "big"
                            dim: true
                        }
                        PxText {
                            anchors.verticalCenter: parent.verticalCenter
                            // a long name on its own line stays inside, clear of "Undo"
                            width: Math.min(implicitWidth, crumbFlow.width - Theme.u * 12)
                            elide: Text.ElideRight
                            text: crumb.modelData
                            kind: "big"
                            font.bold: crumb.last
                            color: crumb.last ? Theme.text : crumbMouse.containsMouse ? Theme.accent : Theme.textDim
                            MouseArea {
                                id: crumbMouse
                                anchors.fill: parent
                                enabled: !crumb.last
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.view.crumbClicked(crumb.index)
                            }
                        }
                    }
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
