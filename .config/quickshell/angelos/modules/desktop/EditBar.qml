import QtQuick
import qs.config
import qs.services
import qs.widgets

// Edit mode's bar at the top of the screen it was asked on (Background: a small window on the
// top layer, over the windows): how fine the grid is (or no snapping at all), every widget onto
// the grid, Done.
// The grid itself is DesktopGrid, on the wallpaper under the widgets.
PxBox {
    id: root

    property string screenName

    visible: DesktopWidgets.editMode
    width: row.implicitWidth + Theme.u * 10
    height: row.implicitHeight + Theme.u * 6
    hell: Theme.hell
    color: root.hell ? Theme.hellPanel : Qt.alpha(Theme.menuSurface, Theme.panelAlpha)
    shadow: Config.appearance.shadows

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.u * 4
        PxIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "grid"
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("Сетка", "Grid")
            font.bold: !root.hell
            font.family: root.hell ? Theme.fontHellText : Theme.fontBody
            color: root.hell ? Theme.hellText : Theme.text
        }
        PxSegmented {
            anchors.verticalCenter: parent.verticalCenter
            model: DesktopWidgets.gridLevels
            currentValue: DesktopWidgets.gridLevel
            onActivated: v => DesktopWidgets.setGrid(v)
        }
        PxButton {
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            hell: root.hell
            icon: "layers"
            text: I18n.t("Выровнять всё", "Align all")
            onClicked: DesktopWidgets.alignAll(root.screenName)
        }
        PxButton {
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            hell: root.hell
            accent: true
            icon: "check"
            text: I18n.t("Готово", "Done")
            onClicked: DesktopWidgets.editMode = false
        }
    }
}
