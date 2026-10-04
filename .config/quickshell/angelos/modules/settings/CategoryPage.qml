pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// A category's own page in the Windows 11 look (Shell.settingsPage "cat:<id>"): each of its
// pages as a card — its tile, its name, what is on it — that opens it. ↓ from the search and
// the arrows reach them through the left column (Win11View.navKey: → opens the first).
PxPage {
    id: root

    property string categoryId: ""
    readonly property var category: SettingsTree.categories.find(c => c.id === categoryId) || null
    pageId: "cat:" + categoryId
    heading: category ? category.label : ""

    Column {
        width: parent.width
        spacing: Theme.u
        Repeater {
            model: root.category ? root.category.pages : []
            Rectangle {
                id: card
                required property string modelData
                readonly property var entry: SettingsTree.page(modelData)
                width: parent.width
                height: Math.max(Theme.fit(24), texts.implicitHeight + Theme.u * 8)
                color: cardMouse.containsMouse ? Theme.mix(Theme.faceAlt, Theme.accent, 0.12) : Theme.mix(Theme.face, Theme.faceAlt, 0.55)
                border.width: Math.max(1, Theme.u / 2)
                border.color: Qt.alpha(Theme.lo, Theme.dark ? 0.9 : 0.5)
                SettingsTile {
                    id: tile
                    x: Theme.u * 5
                    anchors.verticalCenter: parent.verticalCenter
                    icon: card.entry ? card.entry.icon : "gear"
                    tint: root.category ? root.category.tint : Theme.accent
                }
                Column {
                    id: texts
                    anchors.left: tile.right
                    anchors.leftMargin: Theme.u * 5
                    anchors.right: chevron.left
                    anchors.rightMargin: Theme.u * 4
                    anchors.verticalCenter: parent.verticalCenter
                    PxText {
                        width: parent.width
                        text: card.entry ? card.entry.label : card.modelData
                        elide: Text.ElideRight
                    }
                    PxText {
                        visible: text !== ""
                        width: parent.width
                        text: card.entry ? card.entry.hint : ""
                        kind: "tiny"
                        dim: true
                        wrapMode: Text.Wrap
                    }
                }
                PxText {
                    id: chevron
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.u * 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    kind: "title"
                    dim: true
                }
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Shell.settingsPage = card.modelData;
                        Shell.settingsSub = "";
                    }
                }
            }
        }
    }
}
