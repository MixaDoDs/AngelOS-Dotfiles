pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets
import "ClipboardSymbols.js" as Catalog

Item {
    id: root

    required property bool emoji
    required property string query
    signal picked(string glyph, bool copyOnly)
    signal focusSearch

    property string category: "all"
    property var emojiData: ({})
    readonly property var groups: emoji ? Catalog.emojiGroups : Catalog.symbolGroups
    readonly property var categories: [{label: I18n.t("Все категории", "All categories"), value: "all"}].concat(
        groups.map(g => ({label: I18n.t(g[1], g[2]), value: g[0]})))
    readonly property var matches: Catalog.matching(emoji ? emojiData : Catalog.symbols, groups, category, query)

    function reset() {
        combo.currentValue = category;
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
    }
    onEmojiChanged: {
        category = "all";
        reset();
    }
    onMatchesChanged: reset()

    function setCategory(value) {
        category = value;
        reset();
    }
    function cycleCategory(back) {
        const index = categories.findIndex(c => c.value === category);
        setCategory(categories[(index + (back ? categories.length - 1 : 1)) % categories.length].value);
    }
    function moveSelection(dx, dy) {
        if (!grid.count)
            return;
        grid.currentIndex = Math.min(grid.count - 1, Math.max(0, grid.currentIndex + dx + dy * grid.columns));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }
    function pickCurrent(copyOnly) {
        const choice = matches[grid.currentIndex];
        if (choice)
            picked(choice[0], copyOnly);
    }

    FileView {
        path: root.emoji ? Quickshell.shellDir + "/data/clipboard/emoji.json" : ""
        onLoaded: root.emojiData = JSON.parse(text())
    }

    PxCombo {
        id: combo
        width: Math.min(root.width, Math.max(Theme.u * 100, Theme.fit(86)))
        model: root.categories
        currentValue: root.category
        Accessible.name: I18n.t("Категория", "Category")
        onActivated: value => {
            root.setCategory(value);
            root.focusSearch();
        }
    }

    PxBox {
        anchors.top: combo.bottom
        anchors.topMargin: Theme.gap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        sunken: true
        color: Qt.alpha(Theme.sunken, 0.75)

        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: Theme.gap
            anchors.bottomMargin: Theme.gap * 2 + caption.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            readonly property int columns: Math.max(1, Math.floor(width / Theme.fit(24)))
            cellWidth: Math.floor(width / columns)
            cellHeight: Theme.fit(24)
            model: root.matches

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool chosen: GridView.isCurrentItem
                readonly property string label: I18n.t(modelData[1], modelData[2])
                width: grid.cellWidth
                height: grid.cellHeight

                Accessible.role: Accessible.Button
                Accessible.name: label
                Accessible.focusable: true
                Accessible.onPressAction: root.picked(modelData[0], false)

                PxBox {
                    anchors.fill: parent
                    anchors.rightMargin: Theme.gap
                    anchors.bottomMargin: Theme.gap
                    color: cell.chosen ? Theme.select : pointer.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.18) : Theme.face
                    sunken: pointer.pressed
                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData[0]
                        textFormat: Text.PlainText
                        font.family: root.emoji ? "Noto Color Emoji" : Theme.fontBody
                        font.pixelSize: Theme.fit(12)
                        color: cell.chosen ? Theme.selectText : Theme.text
                    }
                    MouseArea {
                        id: pointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: grid.currentIndex = cell.index
                        onClicked: mouse => root.picked(cell.modelData[0], !!(mouse.modifiers & Qt.ShiftModifier))
                    }
                }
            }
        }

        PxText {
            visible: grid.count === 0
            anchors.centerIn: parent
            text: I18n.t("Ничего не найдено", "No matches")
            dim: true
        }
        PxText {
            id: caption
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.gap
            text: grid.currentItem ? grid.currentItem.label : ""
            elide: Text.ElideRight
            dim: true
        }
    }
}
