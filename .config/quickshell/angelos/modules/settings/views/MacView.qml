pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "../../../widgets/MacIcons.js" as MacIcons

// Settings view "mac": the Golden Gate skin's System Settings, laid out like macOS 27's. On the
// left, edge to edge and a shade darker, the traffic lights, the search capsule, your account card
// and every page of the tree in groups by category, each with its colored icon (Golden Gate
// brought them back); the open one an accent pill. On the right a toolbar — ‹ › through the
// history and the page's name — and the page, its settings in grouped rows (SettingRow and
// PxGroup in the Windows 11 look's cards, drawn the Mac's way). ↑↓ walk the pages, Home/End.
Item {
    id: root

    required property var view              // SettingsView
    readonly property alias searchSlot: searchSlot
    readonly property alias resultsSlot: resultsSlot
    readonly property alias pageSlot: pageSlot
    readonly property bool sidebarVisible: true
    readonly property real sideW: Math.min(GoldenGate.px(250), width * 0.34)
    readonly property real toolbarH: GoldenGate.px(52)

    // the pages in sidebar order (your account first)
    readonly property var pages: [view.accountSection.pages[0]].concat(view.visibleSections.reduce((a, s) => a.concat(s.pages), []))
    function navKey(e) {
        const i = pages.indexOf(view.currentId);
        if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
            const n = Math.max(0, Math.min(pages.length - 1, i + (e.key === Qt.Key_Down ? 1 : -1)));
            Shell.settingsPage = pages[n];
            Shell.settingsSub = "";
            return true;
        }
        if (e.key === Qt.Key_Home || e.key === Qt.Key_End) {
            Shell.settingsPage = pages[e.key === Qt.Key_Home ? 0 : pages.length - 1];
            Shell.settingsSub = "";
            return true;
        }
        if (e.key === Qt.Key_Left) {
            view.goUp();
            return true;
        }
        return false;
    }
    // a page's line icon on its category's colour
    function iconOf(id) {
        const p = view.pageEntry(id);
        return MacIcons.fromPixel(p ? p.icon : "") || "settings";
    }

    // ---- the sidebar ----
    Rectangle {
        id: side
        width: root.sideW
        height: parent.height
        color: GoldenGate.sidebarBg
        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: GoldenGate.separator
        }
        // the window's lights over it, as in System Settings; drag the empty part to move it
        MouseArea {
            width: parent.width
            height: root.toolbarH
            onPressed: if (root.view.hostWindow)
                root.view.hostWindow.startSystemMove()
            onDoubleClicked: if (root.view.hostWindow)
                root.view.hostWindow.maximized = !root.view.hostWindow.maximized
        }
        Row {
            id: lights
            x: GoldenGate.px(20)
            y: (root.toolbarH - height) / 2
            spacing: GoldenGate.px(8)
            HoverHandler {
                id: lightsHover
            }
            Repeater {
                // close, minimize (grey: niri has none), zoom
                model: [["close", 0], ["minimize", 1], ["zoom", 2]]
                Rectangle {
                    id: light
                    required property var modelData
                    readonly property bool usable: modelData[0] !== "minimize"
                    width: GoldenGate.px(12)
                    height: width
                    radius: width / 2
                    color: usable ? GoldenGate.lights[modelData[1]] : GoldenGate.dark ? "#4a4a4d" : "#d1d1d6"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.14)
                    Rectangle {
                        visible: light.usable
                        x: parent.width * 0.2
                        y: parent.height * 0.08
                        width: parent.width * 0.6
                        height: parent.height * 0.42
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.35)
                    }
                    MacIcon {
                        visible: lightsHover.hovered && light.usable
                        anchors.centerIn: parent
                        name: light.modelData[0] === "close" ? "x" : "maximize-2"
                        size: parent.width * 0.7
                        stroke: 3
                        color: Qt.rgba(0, 0, 0, 0.55)
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: light.usable
                        onClicked: {
                            if (light.modelData[0] === "close")
                                Shell.settingsOpen = false;
                            else if (root.view.hostWindow)
                                root.view.hostWindow.maximized = !root.view.hostWindow.maximized;
                        }
                    }
                }
            }
        }
        // the search capsule (SettingsView puts its field here)
        Item {
            id: searchSlot
            x: GoldenGate.px(10)
            y: root.toolbarH
            width: parent.width - GoldenGate.px(20)
            height: root.view.searchFieldHeight
        }

        Flickable {
            id: list
            visible: root.view.query.trim() === ""
            anchors.fill: parent
            anchors.topMargin: searchSlot.y + searchSlot.height + GoldenGate.px(10)
            contentHeight: col.implicitHeight + GoldenGate.px(12)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                x: GoldenGate.px(10)
                width: parent.width - GoldenGate.px(20)
                spacing: 0

                // you: the avatar, the name, "angelOS account"
                Rectangle {
                    id: you
                    readonly property bool sel: root.view.sectionOf(Shell.settingsPage) === "account"
                    width: col.width
                    height: GoldenGate.px(52)
                    radius: GoldenGate.px(8)
                    color: sel ? GoldenGate.accent : youMouse.containsMouse ? GoldenGate.hoverBg : "transparent"
                    Rectangle {
                        id: face
                        x: GoldenGate.px(6)
                        anchors.verticalCenter: parent.verticalCenter
                        width: GoldenGate.px(38)
                        height: width
                        radius: width / 2
                        color: GoldenGate.accent
                        clip: true
                        Image {
                            id: avatar
                            anchors.fill: parent
                            source: StartPrefs.avatarUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize: Qt.size(width * 2, height * 2)
                            visible: status === Image.Ready
                        }
                        MacIcon {
                            visible: avatar.status !== Image.Ready
                            anchors.centerIn: parent
                            name: "user"
                            size: parent.width * 0.6
                            color: "#ffffff"
                        }
                    }
                    Column {
                        anchors.left: face.right
                        anchors.leftMargin: GoldenGate.px(10)
                        anchors.right: parent.right
                        anchors.rightMargin: GoldenGate.px(6)
                        anchors.verticalCenter: parent.verticalCenter
                        MacText {
                            width: parent.width
                            text: StartPrefs.userName
                            semibold: true
                            color: you.sel ? "#ffffff" : GoldenGate.label
                        }
                        MacText {
                            width: parent.width
                            text: I18n.t("Учётная запись angelOS", "angelOS Account")
                            size: GoldenGate.smallSize
                            color: you.sel ? Qt.rgba(1, 1, 1, 0.8) : GoldenGate.secondaryLabel
                        }
                    }
                    MouseArea {
                        id: youMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Shell.settingsPage = SettingsTree.accountPage;
                            Shell.settingsSub = "";
                            root.view.focusNav();
                        }
                    }
                }

                // every page, a gap between the categories
                Repeater {
                    model: root.view.visibleSections
                    Column {
                        id: group
                        required property var modelData
                        width: col.width
                        topPadding: GoldenGate.px(10)
                        Repeater {
                            model: group.modelData.pages
                            Rectangle {
                                id: row
                                required property string modelData
                                readonly property bool sel: root.view.currentId === modelData || (root.view.currentId === "cat:" + group.modelData.id && index === 0)
                                required property int index
                                width: col.width
                                height: GoldenGate.px(30)
                                radius: GoldenGate.px(7)
                                color: sel ? GoldenGate.accent : rowMouse.containsMouse ? GoldenGate.hoverBg : "transparent"
                                Rectangle {
                                    id: tile
                                    x: GoldenGate.px(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: GoldenGate.px(22)
                                    height: width
                                    radius: GoldenGate.px(6)
                                    color: group.modelData.tint || GoldenGate.accent
                                    border.width: row.sel ? 1 : 0
                                    border.color: Qt.rgba(1, 1, 1, 0.5)
                                    MacIcon {
                                        anchors.centerIn: parent
                                        name: root.iconOf(row.modelData)
                                        size: parent.width * 0.66
                                        stroke: 2
                                        color: "#ffffff"
                                    }
                                }
                                MacText {
                                    anchors.left: tile.right
                                    anchors.leftMargin: GoldenGate.px(9)
                                    anchors.right: parent.right
                                    anchors.rightMargin: GoldenGate.px(6)
                                    height: parent.height
                                    text: root.view.labelOf(row.modelData)
                                    color: row.sel ? "#ffffff" : GoldenGate.label
                                }
                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Shell.settingsPage = row.modelData;
                                        Shell.settingsSub = "";
                                        root.view.focusNav();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Item {
            id: resultsSlot
            anchors.fill: parent
            anchors.topMargin: searchSlot.y + searchSlot.height + GoldenGate.px(10)
        }
    }

    // ---- the right side: the toolbar, the page ----
    Item {
        id: main
        anchors.left: side.right
        anchors.right: parent.right
        height: parent.height

        Item {
            id: toolbar
            width: parent.width
            height: root.toolbarH
            MouseArea {
                anchors.fill: parent
                onPressed: if (root.view.hostWindow)
                    root.view.hostWindow.startSystemMove()
                onDoubleClicked: if (root.view.hostWindow)
                    root.view.hostWindow.maximized = !root.view.hostWindow.maximized
            }
            // ‹ › like System Settings: a capsule with two halves
            Rectangle {
                id: nav
                x: GoldenGate.px(14)
                anchors.verticalCenter: parent.verticalCenter
                width: GoldenGate.px(64)
                height: GoldenGate.px(30)
                radius: height / 2
                color: GoldenGate.controlBg
                Row {
                    anchors.fill: parent
                    Repeater {
                        model: [["chevron-left", -1], ["chevron-right", 1]]
                        Item {
                            id: navBtn
                            required property var modelData
                            width: nav.width / 2
                            height: nav.height
                            MacIcon {
                                anchors.centerIn: parent
                                name: navBtn.modelData[0]
                                size: GoldenGate.px(16)
                                stroke: 2.2
                                color: navMouse.containsMouse ? GoldenGate.label : GoldenGate.secondaryLabel
                            }
                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: navBtn.modelData[1] < 0 ? root.view.back() : root.view.forward()
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: parent.height * 0.5
                    color: GoldenGate.separator
                }
            }
            MacText {
                anchors.left: nav.right
                anchors.leftMargin: GoldenGate.px(14)
                anchors.right: undo.visible ? undo.left : parent.right
                anchors.rightMargin: GoldenGate.px(12)
                height: parent.height
                text: root.view.currentPage ? root.view.currentPage.label : I18n.t("Системные настройки", "System Settings")
                size: GoldenGate.px(15)
                bold: true
            }
            // the last change of a setting, as an "Undo" capsule (Config.undo)
            Rectangle {
                id: undo
                visible: Config.canUndo
                anchors.right: parent.right
                anchors.rightMargin: GoldenGate.px(14)
                anchors.verticalCenter: parent.verticalCenter
                width: undoText.implicitWidth + GoldenGate.px(24)
                height: GoldenGate.px(26)
                radius: height / 2
                color: GoldenGate.controlBg
                MacText {
                    id: undoText
                    anchors.centerIn: parent
                    text: I18n.t("Отменить", "Undo")
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Config.undo()
                }
            }
        }
        Rectangle {
            y: root.toolbarH - 1
            width: parent.width
            height: 1
            color: GoldenGate.separator
        }
        Item {
            id: pageSlot
            anchors.fill: parent
            anchors.topMargin: root.toolbarH + GoldenGate.px(8)
            anchors.leftMargin: GoldenGate.px(20)
            anchors.rightMargin: GoldenGate.px(20)
        }
    }
}
