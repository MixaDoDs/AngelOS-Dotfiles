pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.settings.views

// Settings view "controlpanel" (Config.settingsUi.view): a Win98 Control Panel. The home is
// a folder of large icons, the sections in their runs (your account first); an icon opens
// its page over the whole window. On top: ◀ ▶ and Up, the address bar with where you are,
// the search field; at the foot a status bar. The keyboard: arrows walk the icons, Enter
// opens, Backspace / Alt+↑ go up, typing searches.
Item {
    id: root

    required property var view              // SettingsView
    readonly property alias searchSlot: toolbar.searchSlot
    readonly property alias resultsSlot: resultsSlot
    readonly property alias pageSlot: pageSlot
    readonly property string skin: view.skin
    readonly property bool searching: view.query.trim() !== ""

    // the icon the keyboard is on: [run, index]
    property int curRun: 0
    property int curIdx: 0
    readonly property var runs: view.homeRuns
    readonly property int cellW: Theme.u * 52
    readonly property int cellH: Theme.u * 40
    readonly property int columns: Math.max(1, Math.floor((folder.width - Theme.u * 8 + Theme.u * 4) / (cellW + Theme.u * 4)))
    function curSection() {
        const r = runs[curRun];
        return r ? r.sections[curIdx] || null : null;
    }
    // the cursor starts on the section you came from
    function placeCursor() {
        const sid = view.sectionOf(view.lastLoc.split("|")[0]);
        for (let r = 0; r < runs.length; r++) {
            const i = runs[r].sections.findIndex(s => s.id === sid);
            if (i >= 0) {
                curRun = r;
                curIdx = i;
                return;
            }
        }
        curRun = 0;
        curIdx = 0;
    }
    Connections {
        target: root.view
        function onAtHomeChanged() {
            if (root.view.atHome)
                root.placeCursor();
        }
    }
    function navKey(e) {
        if (!view.atHome)
            return false;
        const n = runs[curRun] ? runs[curRun].sections.length : 0;
        if (e.key === Qt.Key_Right) {
            if (curIdx + 1 < n)
                curIdx++;
            else if (curRun + 1 < runs.length) {
                curRun++;
                curIdx = 0;
            }
        } else if (e.key === Qt.Key_Left) {
            if (curIdx > 0)
                curIdx--;
            else if (curRun > 0) {
                curRun--;
                curIdx = runs[curRun].sections.length - 1;
            }
        } else if (e.key === Qt.Key_Down) {
            if (curIdx + columns < n)
                curIdx += columns;
            else if (curRun + 1 < runs.length) {
                curRun++;
                curIdx = Math.min(curIdx % columns, runs[curRun].sections.length - 1);
            }
        } else if (e.key === Qt.Key_Up) {
            if (curIdx - columns >= 0)
                curIdx -= columns;
            else if (curRun > 0) {
                curRun--;
                const m = runs[curRun].sections.length;
                const col = curIdx % columns;
                const lastRow = Math.floor((m - 1) / columns);
                curIdx = Math.min(m - 1, lastRow * columns + col);
            } else
                view.focusSearch();
        } else if (e.key === Qt.Key_Home) {
            curRun = 0;
            curIdx = 0;
        } else if (e.key === Qt.Key_End) {
            curRun = runs.length - 1;
            curIdx = runs[curRun].sections.length - 1;
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
            const s = curSection();
            if (s)
                view.openSection(s);
        } else
            return false;
        folderScroll.ensureVisible(curRun, curIdx);
        return true;
    }

    SettingsToolbar {
        id: toolbar
        width: parent.width
        view: root.view
        address: true
        upButton: true
        searchWidth: Math.min(Theme.u * 100, root.width * 0.3)
    }

    // the window's body: the folder, a page or what the search found
    PxBox {
        id: folder
        anchors.top: toolbar.bottom
        anchors.topMargin: Theme.u * 3
        anchors.bottom: status.top
        anchors.bottomMargin: Theme.u * 2
        width: parent.width
        sunken: true
        color: root.skin === "windose" ? Theme.windosePaper : root.skin === "stream" ? Theme.streamBg : root.view.atHome ? Theme.sunken : Qt.alpha(Theme.face, Config.appearance.blur ? 0.55 : 1)
        edgeColor: root.skin === "windose" ? Theme.windoseLine : Theme.edge

        Item {
            id: resultsSlot
            anchors.fill: parent
            anchors.margins: Theme.u * 4
        }

        // ---- the folder of icons ----
        PxScroll {
            id: folderScroll
            visible: root.view.atHome && !root.searching
            anchors.fill: parent
            anchors.margins: Theme.u * 4
            contentHeight: icons.implicitHeight
            function ensureVisible(r, i) {
                const item = icons.children[r] ? icons.children[r] : null;
                if (!item)
                    return;
                const y = item.y + Theme.u * 9 + Math.floor(i / root.columns) * (root.cellH + Theme.u * 4);
                if (y < flick.contentY)
                    scrollBy(y - flick.contentY);
                else if (y + root.cellH > flick.contentY + height)
                    scrollBy(y + root.cellH - flick.contentY - height);
            }
            Column {
                id: icons
                width: parent.width
                spacing: Theme.u * 6
                Repeater {
                    model: root.runs
                    Column {
                        id: run
                        required property var modelData
                        required property int index
                        width: icons.width
                        spacing: Theme.u * 3
                        // the group's name over a thin line, like Explorer's "Show in groups"
                        Row {
                            spacing: Theme.u * 3
                            PxText {
                                id: runTitle
                                text: run.modelData.title
                                font.bold: true
                                color: root.skin === "windose" ? Theme.windoseTitle : Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                width: Math.max(0, icons.width - runTitle.width - Theme.u * 7)
                                height: Math.max(1, Theme.u / 2)
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.alpha(Theme.textDim, 0.35)
                            }
                        }
                        Grid {
                            columns: root.columns
                            spacing: Theme.u * 4
                            Repeater {
                                model: run.modelData.sections
                                Item {
                                    id: cell
                                    required property var modelData
                                    required property int index
                                    readonly property bool cur: root.view.navActive && root.curRun === run.index && root.curIdx === index
                                    width: root.cellW
                                    height: root.cellH
                                    SettingsTile {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Theme.u * 2
                                        size: Theme.u * 20
                                        icon: cell.modelData.icon
                                        tint: cell.modelData.tint
                                    }
                                    // the label under the icon: selected, it gets the Win98 highlight
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Theme.u * 24
                                        width: Math.min(parent.width, label.implicitWidth + Theme.u * 4)
                                        height: label.height + Theme.u
                                        color: cell.cur ? Theme.select : cellMouse.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.18) : "transparent"
                                        border.width: cell.cur ? Math.max(1, Theme.u / 2) : 0
                                        border.color: Theme.selectText
                                    }
                                    PxText {
                                        id: label
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Theme.u * 24
                                        width: Math.min(implicitWidth, parent.width - Theme.u * 2)
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        text: cell.modelData.label
                                        color: cell.cur ? Theme.selectText : Theme.text
                                    }
                                    MouseArea {
                                        id: cellMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (root.view.clickedNew(mouse, root.view.sectionTarget(cell.modelData)))
                                                return;
                                            root.curRun = run.index;
                                            root.curIdx = cell.index;
                                            root.view.openSection(cell.modelData);
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

        // ---- a page fills the window ----
        Item {
            id: pageSlot
            visible: !root.view.atHome && !root.searching
            anchors.fill: parent
            anchors.margins: Theme.u * 3
        }
    }

    // the status bar: how many objects, or where this page lives
    PxBox {
        id: status
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.u * 12
        sunken: true
        outline: false
        color: Qt.alpha(Theme.face, 0.6)
        PxText {
            x: Theme.u * 4
            anchors.verticalCenter: parent.verticalCenter
            kind: "tiny"
            dim: true
            text: root.searching ? I18n.t("Найдено: ", "Found: ") + root.view.results.length : root.view.atHome ? root.view.navSections.length + I18n.t(" объектов", " objects") : (root.view.navSectionOf(root.view.currentId) || root.view.accountSection).label
        }
        PxText {
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 4
            anchors.verticalCenter: parent.verticalCenter
            kind: "tiny"
            dim: true
            text: root.view.atHome ? I18n.t("стрелки · Enter · печатай для поиска", "arrows · Enter · type to search") : "Backspace / Alt+↑ — " + I18n.t("вверх", "up")
        }
    }
}
