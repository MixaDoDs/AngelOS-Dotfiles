pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// A category's own page (root.nav.settingsPage "cat:<id>"): each of its pages as a card — its
// tile, its name, what is on it — that opens it, two in a row on a wide page. ↓ from the search and
// the arrows reach them through the left column (Win11View.navKey: → opens the first).
PxPage {
    id: root

    property string categoryId: ""
    readonly property var category: SettingsTree.categories.find(c => c.id === categoryId) || null
    pageId: "cat:" + categoryId
    heading: category ? category.label : ""

    // the pages as cards, two in a row once there is room
    Flow {
        id: cards
        width: parent.width
        spacing: Theme.gap * 2
        readonly property int cols: root.cardColumns
        Repeater {
            model: root.category ? root.category.pages : []
            Rectangle {
                id: card
                required property string modelData
                readonly property var entry: SettingsTree.page(modelData)
                width: Math.floor((cards.width - cards.spacing * (cards.cols - 1)) / cards.cols)
                height: Math.max(Theme.fit(24), texts.implicitHeight + Theme.u * 8)
                color: Serp.on ? Qt.alpha(cardMouse.containsMouse ? Serp.surface1 : Serp.surface0, 0.4) : cardMouse.containsMouse ? Theme.mix(Theme.faceAlt, Theme.accent, 0.12) : Theme.mix(Theme.face, Theme.faceAlt, 0.55)  // serp-skin
                radius: Serp.on ? Serp.radius : 0  // serp-skin
                border.width: Serp.on ? 0 : Math.max(1, Theme.u / 2)  // serp-skin
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
                        id: cardLabel
                        width: Math.min(implicitWidth, parent.width - (cardStar.visible ? cardStar.width + Theme.u * 3 : 0))
                        text: card.entry ? card.entry.label : card.modelData
                        elide: Text.ElideRight
                        // something new on the page (services/SettingsNews)
                        NewStar {
                            id: cardStar
                            visible: SettingsNews.pageNew(card.modelData)
                            x: cardLabel.width + Theme.u * 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
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
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (root.view.clickedNew(mouse, card.modelData))
                            return;
                        root.nav.settingsPage = card.modelData;
                        root.nav.settingsSub = "";
                    }
                }
            }
        }
    }
}
