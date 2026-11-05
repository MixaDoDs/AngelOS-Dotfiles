import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

// A tray icon pinned to the bar (BarLayout "tray:<id>", #136): the same clicks as in the
// tray's popup; its menu ends with «Убрать с панели».
PxButton {
    id: root

    required property var tray
    property bool above: true
    readonly property bool square: true     // one cell of the bar's grid (BarItem.iconOnly)

    Accessible.name: tray ? (tray.tooltipTitle || tray.title || tray.id) : ""
    compact: true
    flat: true
    implicitWidth: implicitHeight
    checked: menu.visible
    TintedImage {
        anchors.centerIn: parent
        size: Theme.u * 11
        source: StdIcon.safe(root.tray ? root.tray.icon : "", "application-x-executable")
        fallback: StdIcon.safe("", "application-x-executable")
        mode: root.hovered ? "off" : Config.bar.trayTint
    }
    onClicked: {
        if (tray.onlyMenu)
            return rightClicked();
        tray.activate();
    }
    onMiddleClicked: tray.secondaryActivate()
    onRightClicked: {
        menu.handle = tray.hasMenu ? tray.menu : null;
        menu.toggle();
    }
    WheelHandler {
        acceptedDevices: PointerDevice.AllDevices
        onWheel: w => root.tray.scroll(w.angleDelta.y, false)
    }
    TrayMenu {
        id: menu
        anchorItem: root
        above: root.above
        tray: root.tray
    }
}
