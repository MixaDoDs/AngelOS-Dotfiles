pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.widgets
import "../../widgets/Place.js" as Place

// Stack of notification cards in the top-right corner of the chosen screen.
PanelWindow {
    id: win

    screen: Config.notifications.screen === "primary" ? Shell.primaryScreen : Shell.screenByName(Config.notifications.screen) || Shell.focusedScreen
    // over the first-run wizard nothing pops up (they wait in the history)
    visible: Notifs.popups.length > 0 && !Shell.setupLocked
    readonly property string pos: Config.notifications.position || "top-right"
    anchors.top: Place.top(pos)
    anchors.bottom: Place.bottom(pos)
    anchors.left: Place.left(pos)
    anchors.right: Place.right(pos)
    margins.top: Theme.u * 4
    margins.bottom: Theme.u * 4
    margins.left: Theme.u * 4
    margins.right: Theme.u * 4
    implicitWidth: Theme.u * 175
    implicitHeight: Math.max(1, col.implicitHeight + Theme.u * 3)
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "angelos-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    BackgroundEffect.blurRegion: Config.appearance.blur ? blurRegion : null
    Region {
        id: blurRegion
        item: col
    }

    Column {
        id: col
        width: parent.width - Theme.u * 3
        spacing: Theme.u * 5

        Repeater {
            model: Notifs.popups
            NotificationCard {
                required property var modelData
                notification: modelData
                width: col.width
            }
        }
    }

    RightClickGuard {}
}
