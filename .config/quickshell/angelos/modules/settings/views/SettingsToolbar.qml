pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The row over a settings page: ◀ ▶ (history), where you are (Home › Sound › System sounds),
// "Undo" on the right. `address`: the Win98 address bar look (Control Panel) — the crumbs
// in a sunken field after an "Up" button; `searchSlot` (optional) leaves room for the
// search field before "Undo".
Item {
    id: root

    required property var view              // SettingsView
    property bool address: false
    property bool upButton: false
    property real searchWidth: 0            // > 0: a slot for the search field
    readonly property alias searchSlot: searchSlot
    readonly property bool hasRule: !address

    height: Theme.u * 15

    Row {
        id: arrows
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.u
        PxButton {
            compact: true
            flat: !root.address
            icon: "arrowLeft"
            enabled: root.view.canBack
            opacity: enabled ? 1 : 0.35
            onClicked: root.view.back()
        }
        PxButton {
            compact: true
            flat: !root.address
            icon: "arrowRight"
            enabled: root.view.canForward
            opacity: enabled ? 1 : 0.35
            onClicked: root.view.forward()
        }
        // Win98's "Up one level"
        PxButton {
            visible: root.upButton
            compact: true
            icon: "arrowUp"
            enabled: root.view.settingsNav.settingsSub !== "" || root.view.parentOf(root.view.currentId) !== "" || (root.view.hasHome && !root.view.atHome)
            opacity: enabled ? 1 : 0.35
            onClicked: root.view.goUp()
        }
    }

    // the address field (Control Panel): the crumbs sit in it
    PxBox {
        visible: root.address
        anchors.left: arrows.right
        anchors.leftMargin: Theme.u * 3
        anchors.right: root.searchWidth > 0 ? searchSlot.left : undoBtn.visible ? undoBtn.left : newBtn.left
        anchors.rightMargin: Theme.u * 3
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.u * 13
        sunken: true
        color: Theme.sunken
    }
    // the crumbs; short of room (big fonts) the start of the path gives way, the page stays
    Item {
        id: crumbRow
        anchors.left: arrows.right
        anchors.leftMargin: Theme.u * (root.address ? 7 : 4)
        anchors.right: root.searchWidth > 0 ? searchSlot.left : undoBtn.visible ? undoBtn.left : newBtn.left
        anchors.rightMargin: Theme.u * (root.address ? 7 : 3)
        anchors.verticalCenter: parent.verticalCenter
        height: crumbInner.implicitHeight
        clip: true
    Row {
        id: crumbInner
        x: Math.min(0, crumbRow.width - implicitWidth)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.u * 2
        PxIcon {
            visible: root.address
            anchors.verticalCenter: parent.verticalCenter
            name: root.view.atHome ? "gear" : root.view.currentPage ? root.view.currentPage.icon : "gear"
            ink: Theme.dark ? Theme.text : Theme.edge
        }
        Repeater {
            model: root.view.crumbs
            Row {
                id: crumb
                required property var modelData
                required property int index
                readonly property bool last: index === root.view.crumbs.length - 1
                spacing: Theme.u * 2
                PxText {
                    visible: crumb.index > 0
                    text: "›"
                    dim: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    text: crumb.modelData
                    kind: root.address ? "body" : "title"
                    font.bold: crumb.last
                    color: crumb.last ? Theme.text : cm.containsMouse ? Theme.accent : Theme.textDim
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        id: cm
                        anchors.fill: parent
                        enabled: !crumb.last
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // up to that level: the home, the section's first page, the page itself
                        onClicked: root.view.crumbClicked(crumb.index)
                    }
                }
            }
        }
    }
    }

    Item {
        id: searchSlot
        visible: root.searchWidth > 0
        anchors.right: undoBtn.visible ? undoBtn.left : newBtn.left
        anchors.rightMargin: Theme.u * 3
        anchors.verticalCenter: parent.verticalCenter
        width: root.searchWidth
        height: root.view.searchFieldHeight
    }

    // "Undo": the last change of a setting (Config.undo)
    PxButton {
        id: undoBtn
        visible: Config.canUndo
        anchors.right: newBtn.left
        anchors.rightMargin: Theme.u * 2
        anchors.verticalCenter: parent.verticalCenter
        compact: true
        icon: "refresh"
        text: I18n.t("Отменить", "Undo") + (root.width > Theme.u * 420 && SettingsKeys.loaded ? " " + SettingsKeys.stepLabel(Config.lastStep) : "")
        onClicked: Config.undo()
    }
    // this page in one more window (Ctrl+N; a middle click on a section does the same)
    PxButton {
        id: newBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        compact: true
        flat: !root.address
        icon: "window"
        enabled: Shell.settingsMore.count < Shell.settingsMoreMax
        opacity: enabled ? 1 : 0.35
        onClicked: root.view.openNew()
    }
    Rectangle {
        visible: root.hasRule
        anchors.top: parent.bottom
        anchors.topMargin: Theme.u
        width: parent.width
        height: Math.max(1, Theme.u / 2)
        color: Qt.alpha(Theme.lo, 0.6)
    }
}
