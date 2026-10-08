pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.widgets
import qs.modules.bar

PxButton {
    id: root

    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Значки в трее", "Tray icons")

    property bool above: true
    // Settings → Bar → Icons → Tray density: columns, cell, icon and gap in art pixels
    readonly property var densities: ({
            "compact": [6, 13, 9, 2],
            "normal": [5, 17, 11, 3],
            "airy": [4, 20, 12, 5],
            "spacious": [3, 24, 14, 7]
        })
    readonly property var density: densities[Config.bar.trayDensity] || densities.normal
    readonly property int cellSize: Theme.u * density[1]
    readonly property int iconSize: Theme.u * density[2]
    readonly property int cellGap: Theme.u * density[3]
    readonly property int columns: density[0]
    readonly property int rows: Math.ceil(SystemTray.items.values.length / columns)
    readonly property real gridHeight: Math.max(0, rows * (cellSize + cellGap) - cellGap)
    compact: true
    flat: true
    icon: popup.visible ? "arrowDown" : "arrowUp"
    checked: popup.visible
    onClicked: popup.toggle()

    BarPopup {
        id: popup
        panelId: "tray"
        anchorItem: root
        above: root.above
        title: I18n.t("Системный трей", "System tray")
        icon: "layers"
        contentWidth: Math.max(Theme.u * 80, root.columns * (root.cellSize + root.cellGap) - root.cellGap + Theme.u * 19)
        contentHeight: Math.min(Theme.u * 130, Math.max(Theme.u * 26, root.gridHeight + Theme.u * 4))
        Flickable {
            id: viewport
            anchors.fill: parent
            contentWidth: width
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: root.gridHeight + Theme.u * 2
            Grid {
                id: grid
                width: parent.width
                columns: root.columns
                spacing: root.cellGap
                Repeater {
                    model: SystemTray.items
                    PxButton {
                        id: cell
                        required property var modelData
                        width: root.cellSize
                        height: width
                        flat: true
                        TintedImage {
                            anchors.centerIn: parent
                            size: root.iconSize
                            source: cell.modelData.icon
                            mode: cell.hovered ? "off" : Config.bar.trayTint
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: m => {
                                if (m.button === Qt.MiddleButton)
                                    cell.modelData.secondaryActivate();
                                else if (m.button === Qt.RightButton || cell.modelData.onlyMenu) {
                                    menu.handle = cell.modelData.hasMenu ? cell.modelData.menu : null;
                                    menu.toggle();
                                } else {
                                    cell.modelData.activate();
                                    popup.visible = false;
                                }
                            }
                            onWheel: w => cell.modelData.scroll(w.angleDelta.y, false)
                        }
                    }
                }
            }
        }
        PxText {
            anchors.centerIn: parent
            visible: SystemTray.items.values.length === 0
            text: I18n.t("Трей пуст", "No tray apps")
            dim: true
        }
    }
    // Anchor menus to the bar button, which stays alive when overflow closes.
    TrayMenu {
        id: menu
        anchorItem: root
        above: root.above
    }
}
