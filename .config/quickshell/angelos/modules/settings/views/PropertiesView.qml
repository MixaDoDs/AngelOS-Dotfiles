pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// Settings view "properties" (Config.settingsUi.view): a Win98 properties sheet. On top
// the section ("Section: [Sound ▾]") and the search field; under them the section's pages
// as tabs, the open page's sub-pages ("advanced" groups) as smaller tabs right after it;
// the page sits on the tab's raised card. At the foot: OK (closes) and "Revert changes" —
// everything changed since the window opened goes back (Config.undo, step by step).
// The keyboard: ←→ the tabs, ↑↓ the sections (also Ctrl+Tab, Ctrl+PgUp/PgDn everywhere).
Item {
    id: root

    required property var view              // SettingsView
    readonly property alias searchSlot: searchSlot
    readonly property alias resultsSlot: resultsSlot
    readonly property alias pageSlot: pageSlot
    readonly property string skin: view.skin
    readonly property var section: view.navSectionOf(view.currentId) || view.accountSection

    function navKey(e) {
        if (e.key === Qt.Key_Right || e.key === Qt.Key_Left) {
            view.navPage(e.key === Qt.Key_Right ? 1 : -1);
            return true;
        }
        if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
            view.navSection(e.key === Qt.Key_Down ? 1 : -1);
            return true;
        }
        return false;
    }

    // ---- "Section: [… ▾]" and the search field ----
    Item {
        id: head
        width: parent.width
        height: Math.max(sectionBox.height, root.view.searchFieldHeight)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.u * 3
            SettingsTile {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.section.icon
                tint: root.section.tint
            }
            PxText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("Раздел:", "Section:")
            }
            PxCombo {
                id: sectionBox
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(Theme.u * 120, root.width - searchSlot.width - Theme.u * 40)
                model: root.view.navSections.map(s => ({
                            "label": s.label,
                            "value": s.id
                        }))
                currentValue: root.section.id
                onActivated: v => {
                    const s = root.view.navSections.find(x => x.id === v);
                    if (s)
                        root.view.openSection(s);
                }
            }
        }
        Item {
            id: searchSlot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Theme.u * 100, root.width * 0.34)
            height: root.view.searchFieldHeight
        }
    }

    // ---- the tabs ----
    Flickable {
        id: tabs
        anchors.top: head.bottom
        anchors.topMargin: Theme.u * 5
        x: Theme.u * 2
        width: parent.width - Theme.u * 4
        height: Theme.u * 16
        contentWidth: tabRow.implicitWidth
        clip: true
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        z: 2
        // the open tab comes into sight
        function reveal(item) {
            if (!item)
                return;
            if (item.x < contentX)
                contentX = item.x;
            else if (item.x + item.width > contentX + width)
                contentX = item.x + item.width - width;
        }
        Row {
            id: tabRow
            height: parent.height
            spacing: -Theme.u
            Repeater {
                model: root.view.sectionLocs
                Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool cur: modelData.page === root.view.currentId && modelData.sub === root.view.settingsNav.settingsSub
                    onCurChanged: if (cur)
                        Qt.callLater(tabs.reveal, tab)
                    width: Math.min(Theme.u * 110, tabText.implicitWidth + Theme.u * (modelData.child ? 10 : 14))
                    height: tabs.height
                    z: cur ? 2 : 1
                    // the raised tab: the open one is taller and joins the card below
                    PxBox {
                        y: tab.cur ? 0 : Theme.u * 2
                        width: parent.width
                        height: parent.height - y + (tab.cur ? Theme.u * 2 : 0)
                        color: tab.cur ? Theme.face : tabMouse.containsMouse ? Theme.mix(Theme.faceAlt, Theme.accent, 0.12) : Theme.faceAlt
                        outline: true
                    }
                    PxText {
                        id: tabText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: tab.cur ? -Theme.u / 2 : Theme.u
                        width: Math.min(implicitWidth, tab.width - Theme.u * 6)
                        elide: Text.ElideRight
                        kind: tab.modelData.child ? "tiny" : "body"
                        text: (tab.modelData.child ? "› " : "") + tab.modelData.label
                        font.bold: tab.cur
                        color: tab.cur ? Theme.text : Theme.textDim
                    }
                    // the keyboard is on the tabs: the open one gets a dotted focus line
                    Rectangle {
                        visible: tab.cur && root.view.navActive
                        anchors.left: tabText.left
                        anchors.right: tabText.right
                        anchors.top: tabText.bottom
                        height: Math.max(1, Theme.u / 2)
                        color: Theme.accent
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.view.goLocOf(tab.modelData);
                            root.view.focusNav();
                        }
                    }
                }
            }
        }
    }

    // ---- the tab's card with the page ----
    PxBox {
        id: card
        anchors.top: tabs.bottom
        anchors.bottom: foot.top
        anchors.bottomMargin: Theme.u * 4
        width: parent.width
        color: root.skin === "windose" ? Theme.windosePaper : root.skin === "stream" ? Theme.streamBg : Theme.face
        edgeColor: root.skin === "windose" ? Theme.windoseLine : Theme.edge
        Item {
            id: pageSlot
            anchors.fill: parent
            anchors.margins: Theme.u * 3
        }
    }

    // ---- OK · Revert changes ----
    Item {
        id: foot
        anchors.bottom: parent.bottom
        width: parent.width
        height: okBtn.height
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - buttons.width - Theme.u * 6
            elide: Text.ElideRight
            kind: "tiny"
            dim: true
            text: root.view.sessionChanged ? I18n.t("изменения уже действуют; «Отменить правки» вернёт всё, как было при открытии", "changes apply at once; “Revert changes” puts back how it was when you opened this") : I18n.t("изменения применяются сразу", "changes apply at once")
        }
        Row {
            id: buttons
            anchors.right: parent.right
            spacing: Theme.u * 4
            PxButton {
                id: okBtn
                width: Math.max(implicitWidth, Theme.u * 40)
                text: I18n.t("ОК", "OK")
                accent: true
                onClicked: root.view.settingsNav.settingsOpen = false
            }
            PxButton {
                text: I18n.t("Отменить правки", "Revert changes")
                enabled: root.view.sessionChanged
                onClicked: root.view.revertSession()
            }
        }
    }

    // ---- what the search found: a list dropping from the field over the card ----
    PxBox {
        id: drop
        visible: root.view.query.trim() !== ""
        z: 10
        anchors.right: parent.right
        y: head.y + head.height + Theme.u
        width: Math.max(searchSlot.width, Math.min(Theme.u * 170, root.width - Theme.u * 8))
        height: Math.min(card.y + card.height - y, Theme.u * 12 + root.view.results.length * Theme.u * 20 + Theme.u * 16)
        shadow: true
        color: Theme.menuSurface
        Item {
            id: resultsSlot
            anchors.fill: parent
            anchors.margins: Theme.u * 3
        }
    }
}
