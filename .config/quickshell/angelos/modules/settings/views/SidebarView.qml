pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.views

// Settings view "sidebar" (Config.settingsUi.view), like macOS's System Settings: the
// sidebar always there — search on top, your account card, then the sections in runs a
// line apart, each with its coloured tile; the page on the right under a toolbar with ◀ ▶
// (history) and where you are (Sound › System sounds › Clicks). Stream puts the sidebar on
// the right, like its channel rail. ↑↓ in the sidebar go from section to section.
Item {
    id: root

    required property var view              // SettingsView
    readonly property alias searchSlot: searchSlot
    readonly property alias resultsSlot: resultsSlot
    readonly property alias pageSlot: pageSlot
    readonly property bool sidebarVisible: sidebar.visible
    readonly property string skin: view.skin

    // the keyboard (SettingsView.navFocus): ↑↓ walk the sections, the page follows
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
            view.navPage(1);
            return true;
        }
        if (e.key === Qt.Key_Left) {
            view.navPage(-1);
            return true;
        }
        return false;
    }

    // the sidebar: on the left (Stream: its channel rail on the right)
    PxBox {
        id: sidebar
        x: root.skin === "stream" ? parent.width - width : 0
        width: Theme.u * (root.skin === "stream" ? 100 : 108)
        height: parent.height
        sunken: true
        color: root.skin === "classic" ? Qt.alpha(Theme.sunken, 0.55) : root.skin === "stream" ? Theme.streamPanel : Theme.mix(Theme.windosePaper, Theme.windoseLavender, 0.1)

        // the search field and, while there is a query, what it finds (SettingsView puts them here)
        Item {
            id: searchSlot
            x: Theme.u * 2
            y: Theme.u * 2
            width: parent.width - Theme.u * 4
            height: root.view.searchFieldHeight
        }
        Item {
            id: resultsSlot
            anchors.fill: parent
            anchors.margins: Theme.u * 2
            anchors.topMargin: searchSlot.y + searchSlot.height + Theme.u * 8
        }

        // the account card and the sections
        PxScroll {
            visible: root.view.query.trim() === ""
            anchors.fill: parent
            anchors.margins: Theme.u * 2
            anchors.topMargin: searchSlot.y + searchSlot.height + Theme.u * 2
            contentHeight: side.implicitHeight

            Column {
                id: side
                width: parent.width
                spacing: Theme.u

                // you: the avatar, the name; your account, language, the wizard
                Rectangle {
                    id: account
                    readonly property bool sel: root.view.sectionOf(root.view.settingsNav.settingsPage) === "account"
                    width: side.width
                    height: Theme.u * 24
                    color: sel ? Theme.select : am.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.15) : "transparent"
                    border.width: sel && root.view.navActive ? Math.max(1, Theme.u / 2) : 0
                    border.color: Theme.selectText
                    // the avatar from Bar → Start (StartPrefs), else a heart, in a pixel frame
                    PxBox {
                        id: face
                        x: Theme.u * 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.u * 18
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
                        x: Theme.u * 25
                        width: parent.width - x - Theme.u * 2
                        anchors.verticalCenter: parent.verticalCenter
                        PxText {
                            width: parent.width
                            text: StartPrefs.userName
                            font.bold: true
                            elide: Text.ElideRight
                            color: account.sel ? Theme.selectText : Theme.text
                        }
                        PxText {
                            width: parent.width
                            text: I18n.t("Аккаунт, язык, мастер", "Account, language, wizard")
                            kind: "tiny"
                            elide: Text.ElideRight
                            color: account.sel ? Theme.selectText : Theme.textDim
                        }
                    }
                    MouseArea {
                        id: am
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (root.view.clickedNew(mouse, "account"))
                                return;
                            root.view.settingsNav.settingsPage = "account";
                            root.view.settingsNav.settingsSub = "";
                            root.view.focusNav();
                        }
                    }
                }

                Repeater {
                    model: root.view.visibleRuns
                    Column {
                        id: run
                        required property var modelData
                        required property int index
                        width: side.width
                        spacing: Theme.u
                        // a line between the runs (Windose and Stream: their titles)
                        Item {
                            width: run.width
                            height: root.skin === "classic" ? Theme.u * 5 : runTitle.implicitHeight + Theme.u * 3
                            Rectangle {
                                visible: root.skin === "classic"
                                x: Theme.u * 3
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.u * 6
                                height: Math.max(1, Theme.u / 2)
                                color: Qt.alpha(Theme.lo, Theme.dark ? 0.9 : 0.6)
                            }
                            PxText {
                                id: runTitle
                                visible: root.skin !== "classic"
                                anchors.bottom: parent.bottom
                                text: (root.skin === "windose" ? "▸ " : "# ") + run.modelData.title
                                kind: "tiny"
                                dim: true
                                leftPadding: Theme.u * 3
                            }
                        }
                        Repeater {
                            model: run.modelData.sections
                            Rectangle {
                                id: entry
                                required property var modelData
                                readonly property bool sel: root.view.sectionOf(root.view.settingsNav.settingsPage) === modelData.id
                                width: run.width
                                height: Theme.u * (root.skin === "stream" ? 18 : 16)
                                radius: root.skin === "stream" ? Theme.u * 2 : 0
                                color: root.skin === "classic" ? sel ? Theme.select : em.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.15) : "transparent" : sel ? Theme.mix(Theme.face, Theme.accent, root.skin === "stream" ? 0.26 : 0.18) : em.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.12) : "transparent"
                                // the keyboard is in the sidebar: the picked section wears a frame
                                border.width: (root.skin !== "classic" && sel) || (sel && root.view.navActive) ? Math.max(1, Theme.u / 2) : 0
                                border.color: root.skin === "classic" ? Theme.selectText : Theme.accent
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.u * 3
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    spacing: Theme.u * 4
                                    SettingsTile {
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: entry.modelData.icon
                                        tint: entry.modelData.tint
                                    }
                                    PxText {
                                        width: entry.width - Theme.u * 22
                                        elide: Text.ElideRight
                                        text: entry.modelData.label
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.skin === "classic" && entry.sel ? Theme.selectText : Theme.text
                                        font.bold: entry.sel
                                    }
                                }
                                MouseArea {
                                    id: em
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (root.view.clickedNew(mouse, root.view.sectionTarget(entry.modelData)))
                                            return;
                                        root.view.openSection(entry.modelData);
                                        root.view.focusNav();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // the page, under its toolbar
    PxBox {
        id: pageBox
        anchors.left: root.skin === "stream" ? parent.left : sidebar.right
        anchors.leftMargin: root.skin === "stream" ? 0 : Theme.u * (root.skin === "classic" ? 4 : 3)
        anchors.right: root.skin === "stream" ? sidebar.left : parent.right
        anchors.rightMargin: root.skin === "stream" ? Theme.u * 3 : 0
        height: parent.height
        sunken: true
        color: root.skin === "windose" ? Theme.windosePaper : root.skin === "stream" ? Theme.streamBg : Qt.alpha(Theme.face, Config.appearance.blur ? 0.55 : 1)
        edgeColor: root.skin === "windose" ? Theme.windoseLine : Theme.edge

        // Windose: the home lies on lilac checks, like Ame's desktop
        Image {
            visible: root.skin === "windose" && (root.view.settingsNav.settingsPage === "home" || root.view.settingsNav.settingsPage === "more")
            anchors.fill: parent
            fillMode: Image.Tile
            smooth: false
            sourceSize: Qt.size(Theme.u * 16, Theme.u * 16)
            source: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" shape-rendering="crispEdges"><rect width="16" height="16" fill="' + Theme.hex(Theme.mix(Theme.windosePaper, Theme.windoseLavender, 0.045)) + '"/><rect width="8" height="8" fill="' + Theme.hex(Theme.mix(Theme.windosePaper, Theme.windoseLavender, 0.018)) + '"/><rect x="8" y="8" width="8" height="8" fill="' + Theme.hex(Theme.mix(Theme.windosePaper, Theme.windoseLavender, 0.018)) + '"/></svg>')
        }

        SettingsToolbar {
            id: toolbar
            x: Theme.u * 2
            y: Theme.u * 2
            width: parent.width - Theme.u * 4
            view: root.view
        }

        Item {
            id: pageSlot
            anchors.fill: parent
            anchors.margins: Theme.u * 3
            anchors.topMargin: toolbar.y + toolbar.height + Theme.u * 4
        }
    }
}
